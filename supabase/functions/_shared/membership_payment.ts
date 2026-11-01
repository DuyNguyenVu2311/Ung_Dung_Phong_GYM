import { hmac, rawSignature } from "./momo.ts";

export interface PaymentOrder {
  id: string;
  amount: number;
  payment_method: string;
  payment_provider: string;
  status: string;
  payment_url: string | null;
  gateway_started_at: string | null;
  payment_expires_at: string | null;
}
export interface PaymentStore {
  claim(): Promise<boolean>;
  read(): Promise<PaymentOrder>;
  apply(
    amount: number,
    code: number,
    transaction: string | null,
    missing: boolean,
  ): Promise<void>;
  saveUrl(url: string): Promise<void>;
}
export interface GatewayConfig {
  partnerCode: string;
  accessKey: string;
  secretKey: string;
  environment: "test" | "production";
  callbackBase: string;
}

export function gatewayTransaction(value: unknown): string {
  if (typeof value === "number" && !Number.isSafeInteger(value)) {
    throw new Error("Invalid transaction");
  }
  if (
    (typeof value !== "string" && typeof value !== "number") ||
    !/^[1-9][0-9]*$/.test(String(value))
  ) {
    throw new Error("Invalid transaction");
  }
  return String(value);
}

export async function processBusinessPayment(
  order: PaymentOrder,
  action: "create" | "status",
  deps: { store: PaymentStore; fetch: typeof fetch; config: GatewayConfig },
): Promise<PaymentOrder> {
  const { store, config } = deps;
  if (
    !["momo_business", "legacy_review"].includes(order.payment_provider) ||
    order.payment_method !== "online"
  ) {
    throw new Error("Not a Business order");
  }
  if (
    order.status === "approved" || (order.status !== "pending" &&
      (action !== "status" || !order.gateway_started_at))
  ) return order;
  const endpoint = config.environment === "test"
    ? "https://test-payment.momo.vn/v2/gateway/api"
    : "https://payment.momo.vn/v2/gateway/api";
  const post = async (
    path: string,
    fields: Record<string, string | number>,
    signedFields = fields,
  ) => {
    const { accessKey: _privateKey, ...publicFields } = fields;
    const signature = await hmac(rawSignature(signedFields), config.secretKey);
    const response = await deps.fetch(`${endpoint}/${path}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        ...publicFields,
        signature,
        lang: "vi",
        ...(path === "create" ? { autoCapture: true } : {}),
      }),
      signal: AbortSignal.timeout(35000),
    });
    if (!response.ok) {
      throw new Error("Gateway unavailable; order retained for reconciliation");
    }
    const payload = await response.json();
    if (
      !payload || payload.partnerCode !== config.partnerCode ||
      payload.orderId !== order.id ||
      payload.requestId !== fields.requestId ||
      !Number.isInteger(payload.resultCode)
    ) {
      throw new Error("Gateway response mismatch");
    }
    return payload as Record<string, unknown>;
  };
  // No network operation may be sent before the database records the claim.
  // A stale caller that loses the claim reloads and reconciles instead.
  if (
    action === "create" && order.payment_provider === "momo_business" &&
    !order.gateway_started_at &&
    Date.parse(order.payment_expires_at ?? "") > Date.now() &&
    await store.claim()
  ) {
    const fields = {
      accessKey: config.accessKey,
      amount: order.amount,
      extraData: "",
      ipnUrl: `${config.callbackBase}/ipn`,
      orderId: order.id,
      orderInfo: `FitPlan membership ${order.id}`,
      partnerCode: config.partnerCode,
      redirectUrl: `${config.callbackBase}/return`,
      requestId: order.id,
      requestType: "captureWallet",
    };
    const result = await post("create", fields);
    if (
      result.resultCode !== 0 || result.amount !== order.amount ||
      typeof result.payUrl !== "string"
    ) {
      // A failed create response, including duplicate IDs, is not a payment
      // result. Keep the single claim and query on the next attempt.
      return await store.read();
    }
    const url = new URL(result.payUrl);
    if (
      url.protocol !== "https:" ||
      !["payment.momo.vn", "test-payment.momo.vn"].includes(url.hostname)
    ) {
      throw new Error("Invalid gateway URL");
    }
    await store.saveUrl(url.toString());
    return await store.read();
  }
  order = await store.read();
  if (
    order.status === "approved" ||
    (order.status !== "pending" && action !== "status")
  ) return order;
  if (!order.gateway_started_at) {
    // Only the RPC decides whether an unsubmitted order has expired.
    await store.apply(order.amount, -1, null, false);
    return await store.read();
  }
  const requestId = crypto.randomUUID();
  const result = await post("query", {
    partnerCode: config.partnerCode,
    orderId: order.id,
    requestId,
  }, {
    accessKey: config.accessKey,
    orderId: order.id,
    partnerCode: config.partnerCode,
  });
  // MoMo's query API does not document a response signature; trust only the
  // server-to-server HTTPS response and match its merchant/order/request/amount.
  const code = result.resultCode as number;
  const missing = code === 42;
  if (!missing && result.amount !== order.amount) {
    throw new Error("Gateway amount mismatch");
  }
  const transaction = code === 0 ? gatewayTransaction(result.transId) : null;
  await store.apply(order.amount, code, transaction, missing);
  return await store.read();
}
