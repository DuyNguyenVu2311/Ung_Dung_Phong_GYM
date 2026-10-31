/// Passive realtime refreshes must not cause a gateway query that writes to the
/// watched row again. Always read first so verified approval survives outages.
Future<Map<String, dynamic>> refreshPaymentOrder({
  required Future<Map<String, dynamic>> Function() read,
  required Future<Map<String, dynamic>> Function() reconcile,
  bool reconcileGateway = true,
}) async {
  final order = await read();
  if (reconcileGateway &&
      ['momo_business', 'legacy_review'].contains(order['payment_provider']) &&
      order['status'] != 'approved' &&
      (order['status'] == 'pending' || order['gateway_started_at'] != null)) {
    return await reconcile();
  }
  return order;
}
