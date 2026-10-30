export type Fields = Record<string, string | number>;
export function rawSignature(fields: Fields): string {
  return Object.keys(fields).sort().map((key) => `${key}=${fields[key]}`).join(
    "&",
  );
}
export async function hmac(raw: string, secret: string): Promise<string> {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signed = await crypto.subtle.sign("HMAC", key, encoder.encode(raw));
  return Array.from(new Uint8Array(signed)).map((byte) =>
    byte.toString(16).padStart(2, "0")
  ).join("");
}
export async function verifyNotification(
  payload: Record<string, unknown>,
  accessKey: string,
  secret: string,
): Promise<boolean> {
  const keys = [
    "amount",
    "extraData",
    "message",
    "orderId",
    "orderInfo",
    "orderType",
    "partnerCode",
    "payType",
    "requestId",
    "responseTime",
    "resultCode",
    "transId",
  ];
  const fields: Fields = { accessKey };
  for (const key of keys) {
    if (typeof payload[key] !== "string" && typeof payload[key] !== "number") {
      return false;
    }
    fields[key] = payload[key] as string | number;
  }
  const supplied = typeof payload.signature === "string"
    ? payload.signature.toLowerCase()
    : "";
  if (!/^[0-9a-f]{64}$/.test(supplied)) return false;
  const expected = await hmac(rawSignature(fields), secret);
  let difference = 0;
  for (let i = 0; i < 64; i++) {
    difference |= expected.charCodeAt(i) ^ supplied.charCodeAt(i);
  }
  return difference === 0;
}
export function matchesOrder(
  payload: Record<string, unknown>,
  order: { id: string; amount: number; payment_method: string },
  partnerCode: string,
): boolean {
  return payload.partnerCode === partnerCode && payload.orderId === order.id &&
    payload.requestId === order.id &&
    order.payment_method === "online" && Number.isSafeInteger(payload.amount) &&
    payload.amount === order.amount;
}
