import { createClient } from "npm:@supabase/supabase-js@2.118.0";
import { matchesOrder, verifyNotification } from "../_shared/momo.ts";
import {
  gatewayTransaction,
  type PaymentOrder,
  type PaymentStore,
  processBusinessPayment,
} from "../_shared/membership_payment.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization,x-client-info,apikey,content-type",
  "Access-Control-Allow-Methods": "POST,GET,OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
const env = (name: string) => {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing ${name}`);
  return value;
};

export async function handlePaymentRequest(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const action = new URL(req.url).pathname.split("/").pop();
  if (action === "return" && req.method === "GET") {
    return new Response(
      "Bạn có thể quay lại FitPlan và chọn Kiểm tra trạng thái trong Gói tập. Hệ thống chỉ kích hoạt gói sau khi backend xác nhận thanh toán với MoMo.",
      {
        headers: { "Content-Type": "text/plain; charset=utf-8" },
      },
    );
  }
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  try {
    const db = createClient(
      env("SUPABASE_URL"),
      env("SUPABASE_SERVICE_ROLE_KEY"),
      { auth: { persistSession: false } },
    );
    const token = (req.headers.get("Authorization") ?? "").replace(
      /^Bearer /i,
      "",
    );
    const run = async (order: PaymentOrder, mode: "create" | "status") => {
      const rpc = async (name: string, args: Record<string, unknown>) => {
        const { data, error } = await db.rpc(name, {
          request_id: order.id,
          ...args,
        });
        if (error) throw error;
        return data;
      };
      const store: PaymentStore = {
        claim: async () => await rpc("claim_membership_payment", {}) === true,
        read: async () => {
          const { data, error } = await db.from("membership_renewal_requests")
            .select("*").eq("id", order.id).single();
          if (error) throw error;
          return data;
        },
        apply: async (amount, code, transaction, missing) => {
          await rpc("apply_momo_result", {
            expected_amount: amount,
            result_code: code,
            gateway_transaction: transaction,
            queried_missing: missing,
          });
        },
        saveUrl: async (url) => {
          const { error } = await db.from("membership_renewal_requests").update(
            { payment_url: url },
          )
            .eq("id", order.id).eq("status", "pending");
          if (error) throw error;
        },
      };
      const environment = env("MOMO_ENV");
      if (environment !== "test" && environment !== "production") {
        throw new Error("Invalid MOMO_ENV");
      }
      return await processBusinessPayment(order, mode, {
        store,
        fetch,
        config: {
          partnerCode: env("MOMO_PARTNER_CODE"),
          accessKey: env("MOMO_ACCESS_KEY"),
          secretKey: env("MOMO_SECRET_KEY"),
          environment,
          callbackBase: `${
            env("SUPABASE_URL")
          }/functions/v1/membership-payment`,
        },
      });
    };

    if (action === "ipn") {
      const payload = await req.json();
      if (
        !payload ||
        !await verifyNotification(
          payload,
          env("MOMO_ACCESS_KEY"),
          env("MOMO_SECRET_KEY"),
        )
      ) {
        return json({ error: "Invalid signature" }, 400);
      }
      const { data: order, error } = await db.from(
        "membership_renewal_requests",
      ).select("*").eq("id", payload.orderId).maybeSingle();
      if (error) throw error;
      if (
        !order ||
        !["momo_business", "legacy_review"].includes(order.payment_provider) ||
        !matchesOrder(payload, order, env("MOMO_PARTNER_CODE")) ||
        !Number.isInteger(payload.resultCode)
      ) return json({ error: "Payment mismatch" }, 400);
      const transaction = payload.resultCode === 0
        ? gatewayTransaction(payload.transId)
        : null;
      const { error: applied } = await db.rpc("apply_momo_result", {
        request_id: order.id,
        expected_amount: order.amount,
        result_code: payload.resultCode,
        gateway_transaction: transaction,
        queried_missing: false,
      });
      if (applied) throw applied;
      return new Response(null, { status: 204 });
    }

    // Scheduled reconciliation accepts only the backend service-role bearer.
    if (action === "reconcile") {
      if (token !== env("SUPABASE_SERVICE_ROLE_KEY")) {
        return json({ error: "Not authorized" }, 401);
      }
      const { data: orders, error } = await db.from(
        "membership_renewal_requests",
      ).select("*")
        .neq("status", "approved").in("payment_provider", [
          "momo_business",
          "legacy_review",
        ])
        .or(
          `status.eq.pending,and(gateway_started_at.not.is.null,processed_at.gte.${
            new Date(Date.now() - 7 * 86400000).toISOString()
          })`,
        )
        .lte("payment_expires_at", new Date().toISOString())
        .order("gateway_checked_at", { ascending: true, nullsFirst: true })
        .limit(10);
      if (error) throw error;
      const results = await Promise.allSettled(orders.map(async (order) => {
        try {
          return await run(order, "status");
        } catch (error) {
          // Advance the attempt time so one failing merchant response cannot
          // starve every later order in the bounded cron batch.
          await db.from("membership_renewal_requests").update({
            gateway_checked_at: new Date().toISOString(),
          })
            .eq("id", order.id).neq("status", "approved");
          throw error;
        }
      }));
      const checked = results.filter((result) =>
        result.status === "fulfilled"
      ).length;
      const failed = results.length - checked;
      return json({ checked, failed });
    }

    const { data: { user }, error: authError } = await db.auth.getUser(token);
    if (authError || !user) {
      return json({ error: "Authentication required" }, 401);
    }
    const { request_id, action: mode = "create" } = await req.json();
    if (
      typeof request_id !== "string" || !["create", "status"].includes(mode)
    ) return json({ error: "Invalid request" }, 400);
    const { data: order, error } = await db.from("membership_renewal_requests")
      .select("*")
      .eq("id", request_id).eq("user_id", user.id).maybeSingle();
    if (error) throw error;
    if (
      !order ||
      !["momo_business", "legacy_review"].includes(order.payment_provider) ||
      order.amount < 1000 || order.amount > 50000000
    ) {
      return json({ error: "Invalid order" }, 400);
    }
    if (
      mode === "create" && !order.gateway_started_at &&
      order.status === "pending"
    ) {
      const { data: settings, error: settingsError } = await db.from(
        "payment_settings",
      ).select("online_enabled").eq("id", true).single();
      if (settingsError) throw settingsError;
      if (!settings.online_enabled) {
        return json({
          error:
            "New Business sessions are disabled; cancel this unsubmitted order or check status.",
        }, 409);
      }
    }
    const updated = await run(order, mode);
    return json({ order: updated, payment_url: updated.payment_url });
  } catch (error) {
    console.error(
      "membership-payment",
      error instanceof Error ? error.name : "Payment operation failed",
    );
    return json({
      error:
        "Chưa xác định được kết quả thanh toán. Yêu cầu được giữ lại; hãy kiểm tra trạng thái hoặc liên hệ phòng tập.",
    }, 503);
  }
}
