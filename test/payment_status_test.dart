import 'package:fit_gym/services/payment_status_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const pending = <String, dynamic>{
    'id': 'order',
    'status': 'pending',
    'payment_provider': 'momo_business',
    'gateway_started_at': '2026-01-01',
  };
  test('realtime refresh reads current order without creating another gateway write', () async {
    var gatewayCalls = 0;
    final result = await refreshPaymentOrder(
      read: () async => {...pending, 'gateway_checked_at': '2026-01-02'},
      reconcile: () async {
        gatewayCalls++;
        return {...pending, 'status': 'approved'};
      },
      reconcileGateway: false,
    );
    expect(result['gateway_checked_at'], '2026-01-02');
    expect(result['status'], 'pending');
    expect(gatewayCalls, 0);
  });
  test('explicit check reconciles attempted Business order', () async {
    final result = await refreshPaymentOrder(
      read: () async => pending,
      reconcile: () async => {...pending, 'status': 'approved'},
    );
    expect(result['status'], 'approved');
  });
  test(
    'verified approval is shown without depending on available gateway',
    () async {
      final result = await refreshPaymentOrder(
        read: () async => {...pending, 'status': 'approved'},
        reconcile: () async => throw StateError('gateway unavailable'),
      );
      expect(result['status'], 'approved');
    },
  );
  test('manual payment never uses Business reconciliation', () async {
    final result = await refreshPaymentOrder(
      read: () async => {...pending, 'payment_provider': 'manual'},
      reconcile: () async => throw StateError('must not query gateway'),
    );
    expect(result['status'], 'pending');
  });
}
