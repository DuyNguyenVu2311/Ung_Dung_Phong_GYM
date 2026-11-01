import 'package:fit_gym/screens/checkout_screen.dart';
import 'package:fit_gym/screens/membership_screen.dart';
import 'package:fit_gym/models/data_models.dart';
import 'package:fit_gym/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'font_test_support.dart';

void main() {
  setUpAll(loadAppTestFonts);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.instance.init();
  });
  testWidgets(
    'cached contract is visible offline without an unsupported visit count',
    (tester) async {
      await StorageService.instance.saveMembership(
        MembershipPlan(
          id: 'contract',
          name: 'Gói tháng thử nghiệm',
          branchName: 'Thủ Đức',
          startDate: DateTime(2020),
          endDate: DateTime(2099),
          usedSessions: 0,
          totalSessions: 0,
          price: 299000,
        ),
      );
      await tester.pumpWidget(const MaterialApp(home: MembershipScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Gói tháng thử nghiệm'), findsOneWidget);
      expect(find.textContaining('Đã tập:'), findsNothing);
    },
  );
  testWidgets(
    'restored Business order stays Business when settings cannot be loaded',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CheckoutScreen(
            package: const {
              'name': 'Gói tháng',
              'price': 299000,
              'duration_months': 1,
            },
            existingRequest: const {
              'id': 'order',
              'package_name': 'Gói tháng',
              'amount': 299000,
              'duration_months': 1,
              'payment_method': 'online',
              'payment_provider': 'momo_business',
              'status': 'pending',
              'gateway_started_at': '2026-01-01',
              'payment_expires_at': '2099-01-01T00:00:00Z',
              'payment_url': 'https://test-payment.momo.vn/pay',
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Mở cổng thanh toán'), findsOneWidget);
      expect(find.text('Số MoMo'), findsNothing);
      expect(find.text('Hủy yêu cầu'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'legacy ambiguous MoMo asks for review without new payment instructions',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CheckoutScreen(
            package: const {
              'name': 'Gói tháng',
              'price': 299000,
              'duration_months': 1,
            },
            existingRequest: const {
              'id': 'legacy',
              'package_name': 'Gói tháng',
              'amount': 299000,
              'duration_months': 1,
              'payment_method': 'online',
              'payment_provider': 'legacy_review',
              'status': 'pending',
              'gateway_started_at': '2026-01-01',
              'payment_expires_at': '2099-01-01T00:00:00Z',
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Đơn MoMo cũ cần phòng tập'), findsOneWidget);
      expect(find.text('Số MoMo'), findsNothing);
      expect(find.text('Hủy yêu cầu'), findsNothing);
      expect(find.text('Tạo phiên thanh toán online'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
