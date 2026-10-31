import {
  type PaymentOrder,
  type PaymentStore,
  processBusinessPayment,
} from "./membership_payment.ts";
import { hmac } from "./momo.ts";

function equal(a: unknown, b: unknown) {
  if (JSON.stringify(a) !== JSON.stringify(b)) {
    throw new Error(`Expected ${JSON.stringify(b)}, got ${JSON.stringify(a)}`);
  }
}
const initial: PaymentOrder = {
  id: "order1",
  amount: 320000,
  payment_method: "online",
  payment_provider: "momo_business",
  status: "pending",
  payment_url: null,
  gateway_started_at: null,
  payment_expires_at: "2099-01-01T00:00:00Z",
};
function fixture(order: Partial<PaymentOrder> = {}, transport?: typeof fetch) {
  let current = { ...initial, ...order };
  const results: unknown[] = [];
  const store: PaymentStore = {
    claim: () => {
      if (current.gateway_started_at || current.status !== "pending") {
        return Promise.resolve(false);
      }
      current = { ...current, gateway_started_at: new Date().toISOString() };
      return Promise.resolve(true);
    },
    read: () => Promise.resolve(current),
    apply: (amount, code, transaction, missing) => {
      results.push({ amount, code, transaction, missing });
      if (code === 0) current = { ...current, status: "approved" };
      return Promise.resolve();
    },
    saveUrl: (url) => {
      current = { ...current, payment_url: url };
      return Promise.resolve();
    },
  };
  const calls: { url: string; body: Record<string, unknown> }[] = [];
  const fakeFetch: typeof fetch = async (url, options) => {
    calls.push({ url: String(url), body: JSON.parse(String(options?.body)) });
    if (transport) return transport(url, options);
    throw new Error("network timeout");
  };
  return {
    results,
    calls,
    store,
    run: (action: "create" | "status" = "create") =>
      processBusinessPayment(current, action, {
        store,
        fetch: fakeFetch,
        config: {
          partnerCode: "PARTNER",
          accessKey: "ACCESS",
          secretKey: "SECRET",
          environment: "test",
          callbackBase:
            "https://project.supabase.co/functions/v1/membership-payment",
        },
      }),
  };
}
const response = (body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), { status: 200 });

Deno.test("timeout is followed by a signed query, never a second create", async () => {
  const f = fixture();
  try {
    await f.run();
  } catch { /* ambiguous create */ }
  try {
    await f.run();
  } catch { /* ambiguous query */ }
  equal(f.calls.map((c) => c.url.split("/").pop()), ["create", "query"]);
  const query = f.calls[1].body;
  equal(
    query.signature,
    await hmac("accessKey=ACCESS&orderId=order1&partnerCode=PARTNER", "SECRET"),
  );
  equal("accessKey" in query, false);
  equal(f.results, []);
});

Deno.test("query confirms exact amount and transaction when IPN is delayed", async () => {
  const f = fixture(
    { gateway_started_at: "2026-01-01" },
    async (_url, options) => {
      const request = JSON.parse(String(options?.body));
      return response({
        partnerCode: "PARTNER",
        orderId: "order1",
        requestId: request.requestId,
        amount: 320000,
        resultCode: 0,
        transId: 12345,
      });
    },
  );
  equal((await f.run("status")).status, "approved");
  equal(f.results, [{
    amount: 320000,
    code: 0,
    transaction: "12345",
    missing: false,
  }]);
});

Deno.test("query rejects wrong merchant, order, request, amount and invalid transaction", async () => {
  for (
    const changed of [
      { partnerCode: "OTHER" },
      { orderId: "other" },
      { requestId: "other" },
      { amount: 1 },
      { amount: "320000" },
      { transId: 0 },
      { transId: 1.5 },
    ]
  ) {
    const f = fixture(
      { gateway_started_at: "2026-01-01" },
      async (_url, options) => {
        const request = JSON.parse(String(options?.body));
        return response({
          partnerCode: "PARTNER",
          orderId: "order1",
          requestId: request.requestId,
          amount: 320000,
          resultCode: 0,
          transId: 12345,
          ...changed,
        });
      },
    );
    let failed = false;
    try {
      await f.run("status");
    } catch {
      failed = true;
    }
    equal(failed, true);
    equal(f.results, []);
  }
});

Deno.test("missing query order provides query-only evidence without inventing a transaction", async () => {
  const f = fixture(
    { gateway_started_at: "2026-01-01" },
    async (_url, options) => {
      const request = JSON.parse(String(options?.body));
      return response({
        partnerCode: "PARTNER",
        orderId: "order1",
        requestId: request.requestId,
        resultCode: 42,
      });
    },
  );
  await f.run("status");
  equal(f.results, [{
    amount: 320000,
    code: 42,
    transaction: null,
    missing: true,
  }]);
});

Deno.test("restored payment URL still queries before returning a recoverable session", async () => {
  const f = fixture({
    gateway_started_at: "2026-01-01",
    payment_url: "https://test-payment.momo.vn/pay",
  }, async (_url, options) => {
    const request = JSON.parse(String(options?.body));
    return response({
      partnerCode: "PARTNER",
      orderId: "order1",
      requestId: request.requestId,
      amount: 320000,
      resultCode: 7000,
    });
  });
  equal((await f.run()).payment_url, "https://test-payment.momo.vn/pay");
  equal(f.calls.length, 1);
  equal(f.calls[0].url.endsWith("/query"), true);
});

Deno.test("manual or closed orders never create a gateway session", async () => {
  for (const order of [{ payment_provider: "manual" }, { status: "expired" }]) {
    const f = fixture(order);
    try {
      await f.run();
    } catch { /* invalid routing */ }
    equal(f.calls, []);
  }
});

Deno.test("a closed attempted order can recover late success through status query", async () => {
  const f = fixture(
    { status: "expired", gateway_started_at: "2026-01-01" },
    async (_url, options) => {
      const request = JSON.parse(String(options?.body));
      return response({
        partnerCode: "PARTNER",
        orderId: "order1",
        requestId: request.requestId,
        amount: 320000,
        resultCode: 0,
        transId: 12345,
      });
    },
  );
  equal((await f.run("status")).status, "approved");
  equal(f.calls[0].url.endsWith("/query"), true);
});
