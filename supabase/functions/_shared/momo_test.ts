import {
  hmac,
  matchesOrder,
  rawSignature,
  verifyNotification,
} from "./momo.ts";
const equal = (actual: unknown, expected: unknown) => {
  if (actual !== expected) {
    throw new Error(`Expected ${expected}, got ${actual}`);
  }
};
Deno.test("HMAC-SHA256 matches RFC 4231 known vector", async () => {
  equal(
    await hmac("Hi There", "\x0b".repeat(20)),
    "b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7",
  );
});
Deno.test("MoMo create signature preserves the official raw field order without URL encoding", () => {
  equal(
    rawSignature({
      requestType: "captureWallet",
      requestId: "order1",
      redirectUrl: "https://example.com/return",
      partnerCode: "PARTNER",
      orderInfo: "FitPlan order",
      orderId: "order1",
      ipnUrl: "https://example.com/ipn",
      extraData: "",
      amount: 320000,
      accessKey: "ACCESS",
    }),
    "accessKey=ACCESS&amount=320000&extraData=&ipnUrl=https://example.com/ipn&orderId=order1&orderInfo=FitPlan order&partnerCode=PARTNER&redirectUrl=https://example.com/return&requestId=order1&requestType=captureWallet",
  );
});
const payload = {
  amount: 320000,
  extraData: "",
  message: "Successful.",
  orderId: "order1",
  orderInfo: "FitPlan membership",
  orderType: "momo_wallet",
  partnerCode: "PARTNER",
  payType: "qr",
  requestId: "order1",
  responseTime: 1721720663942,
  resultCode: 0,
  transId: 4088878653,
};
Deno.test("IPN accepts an intact signed notification and rejects tampering", async () => {
  const signature = await hmac(
    rawSignature({ accessKey: "ACCESS", ...payload }),
    "SECRET",
  );
  equal(
    await verifyNotification({ ...payload, signature }, "ACCESS", "SECRET"),
    true,
  );
  equal(
    await verifyNotification(
      { ...payload, signature, amount: 1 },
      "ACCESS",
      "SECRET",
    ),
    false,
  );
  equal(
    await verifyNotification({ ...payload, signature }, "ACCESS", "WRONG"),
    false,
  );
  equal(
    await verifyNotification({ ...payload, signature: "" }, "ACCESS", "SECRET"),
    false,
  );
});
Deno.test("Notification must match merchant, owner order reference, method and exact amount", () => {
  const order = { id: "order1", amount: 320000, payment_method: "online" };
  equal(matchesOrder(payload, order, "PARTNER"), true);
  equal(
    matchesOrder({ ...payload, amount: "320000" }, order, "PARTNER"),
    false,
  );
  equal(matchesOrder(payload, { ...order, amount: 1 }, "PARTNER"), false);
  equal(matchesOrder(payload, order, "OTHER"), false);
  equal(
    matchesOrder({ ...payload, requestId: "other" }, order, "PARTNER"),
    false,
  );
  equal(
    matchesOrder(payload, { ...order, payment_method: "cash" }, "PARTNER"),
    false,
  );
});
