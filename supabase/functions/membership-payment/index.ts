import { createClient } from "npm:@supabase/supabase-js@2.118.0";
import {
  hmac,
  matchesOrder,
  rawSignature,
  verifyNotification,
} from "../_shared/momo.ts";

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

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const action = new URL(req.url).pathname.split("/").pop();
  if (action === "return" && req.method === "GET") {
    return new Response(
      "Bạn có thể quay lại FitPlan và chọn Kiểm tra trạng thái trong Gói tập. Hệ thống cập nhật gói sau khi nhận xác nhận thanh toán từ MoMo.",
      { headers: { "Content-Type": "text/plain; charset=utf-8" } },
    );
  }
  try {
    const db = createClient(
      env("SUPABASE_URL"),
      env("SUPABASE_SERVICE_ROLE_KEY"),
      { auth: { persistSession: false } },
    );
    const partnerCode = env("MOMO_PARTNER_CODE"),
      accessKey = env("MOMO_ACCESS_KEY"),
      secretKey = env("MOMO_SECRET_KEY");
    if (action === "ipn") {
      if (req.method !== "POST") {
        return json({ error: "Method not allowed" }, 405);
      }
      const payload = await req.json();
      if (!await verifyNotification(payload, accessKey, secretKey)) {
        return json({ error: "Invalid signature" }, 400);
      }
      const { data: order, error } = await db.from(
        "membership_renewal_requests",
      ).select("id,amount,payment_method,status,transaction_no").eq(
        "id",
        payload.orderId,
      ).maybeSingle();
      if (error) throw error;
      if (!order || !matchesOrder(payload, order, partnerCode)) {
        return json({ error: "Payment mismatch" }, 400);
      }
      if (payload.resultCode === 0) {
        const transaction = String(payload.transId);
        if (!/^\d+$/.test(transaction)) {
          return json({ error: "Invalid transaction" }, 400);
        }
        const { error: confirmed } = await db.rpc("confirm_online_membership", {
          request_id: order.id,
          expected_amount: order.amount,
          gateway_transaction: transaction,
        });
        if (confirmed) throw confirmed;
      } else if (payload.resultCode !== 9000 && order.status === "pending") {
        const { error: failed } = await db.from("membership_renewal_requests")
          .update({
            status: "rejected",
            processed_at: new Date().toISOString(),
          }).eq("id", order.id).eq("status", "pending");
        if (failed) throw failed;
      }
      return new Response(null, { status: 204 });
    }
    if (req.method !== "POST") {
      return json({ error: "Method not allowed" }, 405);
    }
    const token = (req.headers.get("Authorization") ?? "").replace(
      /^Bearer /i,
      "",
    );
    const { data: { user }, error: authError } = await db.auth.getUser(token);
    if (authError || !user) {
      return json({ error: "Authentication required" }, 401);
    }
    const { request_id } = await req.json();
    const { data: settings } = await db.from("payment_settings").select(
      "online_enabled",
    ).eq("id", true).maybeSingle();
    if (!settings?.online_enabled) {
      return json(
        { error: "MoMo payments have not been activated by the gym" },
        409,
      );
    }
    const { data: order, error } = await db.from("membership_renewal_requests")
      .select("id,amount,status,payment_method,payment_url").eq(
        "id",
        request_id,
      ).eq("user_id", user.id).single();
    if (
      error || !order || order.status !== "pending" ||
      order.payment_method !== "online" || order.amount < 1000 ||
      order.amount > 50000000
    ) return json({ error: "Invalid order" }, 400);
    if (order.payment_url) return json({ payment_url: order.payment_url });
    const base = `${env("SUPABASE_URL")}/functions/v1/membership-payment`;
    const fields = {
      accessKey,
      amount: order.amount,
      extraData: "",
      ipnUrl: `${base}/ipn`,
      orderId: order.id,
      orderInfo: `FitPlan membership ${order.id}`,
      partnerCode,
      redirectUrl: `${base}/return`,
      requestId: order.id,
      requestType: "captureWallet",
    };
    const signature = await hmac(rawSignature(fields), secretKey);
    const endpoint = Deno.env.get("MOMO_ENV") === "test"
      ? "https://test-payment.momo.vn/v2/gateway/api/create"
      : "https://payment.momo.vn/v2/gateway/api/create";
    const { accessKey: _privateAccessKey, ...publicFields } = fields;
    const response = await fetch(endpoint, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        ...publicFields,
        signature,
        lang: "vi",
        autoCapture: true,
      }),
      signal: AbortSignal.timeout(35000),
    });
    const result = await response.json();
    if (
      !response.ok || result.resultCode !== 0 || result.orderId !== order.id ||
      result.partnerCode !== partnerCode ||
      Number(result.amount) !== order.amount
    ) {
      return json({
        error:
          "MoMo did not create a checkout. Check the order status or contact the gym.",
      }, 502);
    }
    const paymentUrl = new URL(result.payUrl);
    if (
      paymentUrl.protocol !== "https:" ||
      !["payment.momo.vn", "test-payment.momo.vn"].includes(paymentUrl.hostname)
    ) throw new Error("Invalid MoMo URL");
    const { error: saved } = await db.from("membership_renewal_requests")
      .update({ payment_url: paymentUrl.toString() }).eq("id", order.id).eq(
        "user_id",
        user.id,
      );
    if (saved) throw saved;
    return json({ payment_url: paymentUrl.toString() });
  } catch (e) {
    console.error(
      "membership-payment",
      e instanceof Error ? e.message : "Unknown error",
    );
    return json(
      { error: "Payment service unavailable. Contact the gym." },
      503,
    );
  }
});
