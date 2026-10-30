import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fit_gym/main.dart';
import 'package:fit_gym/models/data_models.dart';
import 'package:fit_gym/screens/home_screen.dart';
import 'package:fit_gym/screens/schedule_screen.dart';
import 'package:fit_gym/screens/profile_screen.dart';
import 'package:fit_gym/screens/settings_screen.dart';
import 'package:fit_gym/services/app_clock.dart';
import 'package:fit_gym/services/app_localization.dart';
import 'package:fit_gym/services/app_settings_service.dart';
import 'package:fit_gym/services/payment_qr_service.dart';
import 'package:fit_gym/services/storage_service.dart';
import 'package:fit_gym/repositories/workout_plan_repository.dart';
import 'package:fit_gym/repositories/workout_schedule_repository.dart';
import 'package:fit_gym/theme/app_theme.dart';
import 'package:fit_gym/widgets/payment_qr_card.dart';

import 'font_test_support.dart';

const reference = 'FP123456781234123412341234567890AB';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppTestFonts);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.instance.init();
    AppSettingsService.themeMode.value = ThemeMode.dark;
    AppSettingsService.language.value = 'vi';
  });
  test('Vietnam calendar crosses UTC date boundary correctly', () {
    final time = AppClock.inVietnam(DateTime.utc(2026, 10, 29, 17, 5));
    expect(AppClock.date(time), '30/10/2026');
    expect(AppClock.time(time), '00:05:00');
    expect(time.weekday, DateTime.friday);
  });
  test(
    'Both QR images retain the exact original recipient and MoMo routing',
    () {
      expect(PaymentQrService.isValid(PaymentQrService.bankOriginal), isTrue);
      expect(PaymentQrService.isValid(PaymentQrService.momoOriginal), isTrue);
      for (final momo in [false, true]) {
        final original = PaymentQrService.parse(
          momo ? PaymentQrService.momoOriginal : PaymentQrService.bankOriginal,
        );
        final payload = PaymentQrService.forOrder(
          momo: momo,
          amount: 807300,
          reference: reference,
        );
        final parsed = PaymentQrService.parse(payload);
        expect(parsed['38'], original['38']);
        expect(parsed['54'], '807300');
        expect(PaymentQrService.parse(parsed['62']!)['08'], reference);
        if (momo) {
          expect(
            PaymentQrService.parse(parsed['62']!)['05'],
            'MOMOW2W82826001',
          );
        }
        expect(PaymentQrService.isValid(payload), isTrue);
        expect(
          PaymentQrService.isValid(
            '${payload.substring(0, payload.length - 1)}X',
          ),
          isFalse,
        );
      }
    },
  );
  test(
    'Old week is archived and next week gets real midnight calendar dates',
    () async {
      final profile = UserProfile(
        name: 'Nguyễn Vũ Duy',
        age: 27,
        height: 175,
        weight: 72,
        gender: 'Nam',
        goal: 'muscle',
        experienceLevel: 'beginner',
        sessionsPerWeek: 3,
      );
      await StorageService.instance.saveProfile(profile);
      final plan = WorkoutPlanRepository.generatePlan('muscle', 'beginner', 3);
      await WorkoutScheduleRepository.generateSchedule(
        plan,
        start: DateTime(2026, 10, 19, 16),
      );
      final current = await WorkoutScheduleRepository.ensureCurrentWeek(
        now: DateTime(2026, 10, 30, 23),
      );
      final date = DateTime.parse(current.first['date'] as String);
      expect(date, DateTime(2026, 10, 26));
      expect(
        StorageService.getString('fit_schedule_archive'),
        contains('2026-10-19'),
      );
      final unchanged = await WorkoutScheduleRepository.ensureCurrentWeek(
        now: DateTime(2026, 10, 31),
      );
      expect(unchanged.first['id'], current.first['id']);
    },
  );
  testWidgets('Actual Vietnamese font fits narrow screens with enlarged text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final language in ['vi', 'en']) {
      AppSettingsService.language.value = language;
      for (final screen in [
        const HomeScreen(),
        const ScheduleScreen(),
        const ProfileScreen(),
        const SettingsScreen(),
      ]) {
        tester.view.physicalSize = const Size(320, 800);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            builder: (context, child) => AppSettingsScope(
              child: MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.35)),
                child: child!,
              ),
            ),
            home: screen,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '${screen.runtimeType} $language at 320px',
        );
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('Payment QR stays large and opens a zoomable full-screen view', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          key: const ValueKey('bank-preview'),
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: PaymentQrCard(
                data: PaymentQrService.forOrder(
                  momo: true,
                  amount: 299000,
                  reference: reference,
                ),
                method: 'MoMo · Tài khoản đuôi 026',
                amount: 299000,
                reference: reference,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.runAsync(() => _capture(key, 'momo-payment-qr.png'));
    await tester.tap(find.text('Phóng to mã QR'));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.text('Quét mã thanh toán'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.runAsync(
      () => _capture(key, 'momo-payment-qr-fullscreen.png'),
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: PaymentQrCard(
                data: PaymentQrService.forOrder(
                  momo: false,
                  amount: 299000,
                  reference: reference,
                ),
                method: 'Vietcombank · 1042362758',
                amount: 299000,
                reference: reference,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.runAsync(() => _capture(key, 'bank-payment-qr.png'));
  });
  testWidgets('Home screenshot uses bundled font and current date', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(983, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await StorageService.instance.saveProfile(
      UserProfile(
        name: 'Nguyễn Văn Teo',
        age: 25,
        height: 175,
        weight: 72,
        gender: 'Nam',
        goal: 'muscle',
        experienceLevel: 'beginner',
        sessionsPerWeek: 3,
      ),
    );
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(key: key, child: const FitPlanApp()),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining(AppClock.date(AppClock.now())), findsWidgets);
    await tester.runAsync(
      () => _capture(key, 'home-typography-vietnam-time.png'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<void> _capture(GlobalKey key, String name) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage();
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File('.tmp/review/$name');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  image.dispose();
}
