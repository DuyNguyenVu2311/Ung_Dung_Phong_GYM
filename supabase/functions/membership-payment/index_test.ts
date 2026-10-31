import { handlePaymentRequest } from "./handler.ts";
import { hmac, rawSignature } from "../_shared/momo.ts";

const equal = (actual: unknown, expected: unknown) => {
  if (actual !== expected) {
    throw new Error(`Expected ${expected}, got ${actual}`);
  }
};
const testEnv = {
  SUPABASE_URL: "https://project.supabase.co",
  SUPABASE_SERVICE_ROLE_KEY: "backend-secret",
  MOMO_PARTNER_CODE: "PARTNER",
  MOMO_ACCESS_KEY: "ACCESS",
  MOMO_SECRET_KEY: "SECRET",
  MOMO_ENV: "test",
};
const order = {
  id: "11111111-1111-4111-8111-111111111111",
  user_id: "alice",
  amount: 320000,
  status: "pending",
  payment_method: "online",
  payment_provider: "momo_business",
  gateway_started_at: "2026-01-01",
  payment_expires_at: "2099-01-01T00:00:00Z",
  payment_url: null,
};
async function withTransport(
  run: (
    calls: { path: string; body: Record<string, unknown> }[],
  ) => Promise<void>,
  overrides: { manual?: boolean; legacy?: boolean } = {},
) {
  const original = globalThis.fetch;
  const previous = Object.fromEntries(
    Object.keys(testEnv).map((key) => [key, Deno.env.get(key)]),
  );
  for (const [key, value] of Object.entries(testEnv)) Deno.env.set(key, value);
  const calls: { path: string; body: Record<string, unknown> }[] = [];
  globalThis.fetch = async (input, init) => {
    const request = new Request(input, init);
    const url = new URL(request.url);
    const body = request.method === "POST" ? await request.json() : {};
    calls.push({ path: url.pathname, body });
    let data: unknown;
    if (url.pathname === "/auth/v1/user") {
      if (request.headers.get("authorization") === "Bearer owner-token") {
        data = { id: "alice" };
      } else data = { id: "bob" };
    } else if (url.pathname === "/rest/v1/membership_renewal_requests") {
      data = url.searchParams.get("user_id") === "eq.bob" ? null : {
        ...order,
        ...(overrides.manual ? { payment_provider: "manual" } : {}),
        ...(overrides.legacy ? { payment_provider: "legacy_review" } : {}),
      };
    } else if (url.pathname === "/v2/gateway/api/query") {
      data = {
        partnerCode: "PARTNER",
        orderId: order.id,
        requestId: body.requestId,
        amount: 320000,
        transId: 12345,
        resultCode: 0,
      };
    } else if (url.pathname === "/rest/v1/rpc/apply_momo_result") data = null;
    else throw new Error(`Unexpected external request ${request.url}`);
    return new Response(JSON.stringify(data), {
      headers: { "Content-Type": "application/json" },
    });
  };
  try {
    await run(calls);
  } finally {
    globalThis.fetch = original;
    for (const [key, value] of Object.entries(previous)) {
      if (value === undefined) Deno.env.delete(key);
      else Deno.env.set(key, value);
    }
  }
}
const request = (token: string, action = "status") =>
  new Request("https://project.supabase.co/functions/v1/membership-payment", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ request_id: order.id, action }),
  });

Deno.test("status endpoint rejects a different owner without contacting MoMo or mutating order", async () => {
  await withTransport(async (calls) => {
    equal((await handlePaymentRequest(request("other-token"))).status, 400);
    equal(
      calls.some((call) =>
        call.path.includes("/rpc/") || call.path.includes("/gateway/")
      ),
      false,
    );
  });
});

Deno.test("manual MoMo cannot enter the automatic gateway endpoint", async () => {
  await withTransport(async (calls) => {
    equal((await handlePaymentRequest(request("owner-token"))).status, 400);
    equal(calls.some((call) => call.path.includes("/gateway/")), false);
  }, { manual: true });
});

Deno.test("authenticated owner status performs server query and atomic result RPC", async () => {
  await withTransport(async (calls) => {
    equal((await handlePaymentRequest(request("owner-token"))).status, 200);
    const rpc = calls.find((call) =>
      call.path === "/rest/v1/rpc/apply_momo_result"
    );
    equal(rpc?.body.gateway_transaction, "12345");
    equal(rpc?.body.expected_amount, 320000);
    equal(rpc?.body.result_code, 0);
  });
});

Deno.test("forged IPN never reaches database mutation", async () => {
  await withTransport(async (calls) => {
    const response = await handlePaymentRequest(
      new Request(
        "https://project.supabase.co/functions/v1/membership-payment/ipn",
        {
          method: "POST",
          body: JSON.stringify({ signature: "forged", orderId: order.id }),
        },
      ),
    );
    equal(response.status, 400);
    equal(calls.length, 0);
  });
});

Deno.test("signed IPN exact order success enters the same result RPC; wrong amount is rejected", async () => {
  for (const amount of [320000, 1]) {
    await withTransport(async (calls) => {
      const payload = {
        amount,
        extraData: "",
        message: "Successful.",
        orderId: order.id,
        orderInfo: "FitPlan membership",
        orderType: "momo_wallet",
        partnerCode: "PARTNER",
        payType: "qr",
        requestId: order.id,
        responseTime: 1721720663942,
        resultCode: 0,
        transId: 12345,
      };
      const signature = await hmac(
        rawSignature({ accessKey: "ACCESS", ...payload }),
        "SECRET",
      );
      const result = await handlePaymentRequest(
        new Request(
          "https://project.supabase.co/functions/v1/membership-payment/ipn",
          {
            method: "POST",
            body: JSON.stringify({ ...payload, signature }),
          },
        ),
      );
      equal(result.status, amount === 320000 ? 204 : 400);
      equal(
        calls.filter((call) => call.path.includes("/rpc/")).length,
        amount === 320000 ? 1 : 0,
      );
    });
  }
});

Deno.test("browser return and member cron request cannot activate contracts", async () => {
  await withTransport(async (calls) => {
    equal(
      (await handlePaymentRequest(
        new Request(
          "https://project.supabase.co/functions/v1/membership-payment/return?resultCode=0",
        ),
      )).status,
      200,
    );
    equal(
      (await handlePaymentRequest(
        new Request(
          "https://project.supabase.co/functions/v1/membership-payment/reconcile",
          {
            method: "POST",
            headers: { Authorization: "Bearer owner-token" },
          },
        ),
      )).status,
      401,
    );
    equal(calls.length, 0);
  });
});

Deno.test("genuine signed IPN is still accepted for an ambiguous legacy attempt", async () => {
  await withTransport(async (calls) => {
    const payload = {
      amount: 320000,
      extraData: "",
      message: "Successful.",
      orderId: order.id,
      orderInfo: "FitPlan membership",
      orderType: "momo_wallet",
      partnerCode: "PARTNER",
      payType: "qr",
      requestId: order.id,
      responseTime: 1721720663942,
      resultCode: 0,
      transId: 12345,
    };
    const signature = await hmac(
      rawSignature({ accessKey: "ACCESS", ...payload }),
      "SECRET",
    );
    const result = await handlePaymentRequest(
      new Request(
        "https://project.supabase.co/functions/v1/membership-payment/ipn",
        {
          method: "POST",
          body: JSON.stringify({ ...payload, signature }),
        },
      ),
    );
    equal(result.status, 204);
    equal(
      calls.filter((call) => call.path === "/rest/v1/rpc/apply_momo_result")
        .length,
      1,
    );
  }, { legacy: true });
});
