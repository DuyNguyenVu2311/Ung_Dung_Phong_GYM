import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fit_gym/main.dart';
import 'package:fit_gym/models/data_models.dart';
import 'package:fit_gym/screens/onboarding_screen.dart';
import 'package:fit_gym/services/app_settings_service.dart';
import 'package:fit_gym/services/app_localization.dart';
import 'package:fit_gym/services/storage_service.dart';
import 'package:fit_gym/theme/app_theme.dart';
import 'package:fit_gym/repositories/workout_plan_repository.dart';

import 'font_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadAppTestFonts();
    for (final font in {
      'Inter': 'roboto-regular.ttf',
      'Roboto': 'roboto-regular.ttf',
      'MaterialIcons': 'materialicons-regular.otf',
    }.entries) {
      final file = File(
        'C:/flutter/bin/cache/artifacts/material_fonts/${font.value}',
      );
      if (file.existsSync()) {
        final loader = FontLoader(font.key)
          ..addFont(
            Future.value(ByteData.sublistView(await file.readAsBytes())),
          );
        await loader.load();
      }
    }
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.instance.init();
    AppSettingsService.themeMode.value = ThemeMode.dark;
    AppSettingsService.language.value = 'vi';
  });
  test(
    'Accounts keep separate profiles and start with no membership',
    () async {
      final storage = StorageService.instance;
      await storage.bindUser('one');
      await storage.saveProfile(
        UserProfile(
          name: 'Alice',
          age: 30,
          height: 160,
          weight: 55,
          gender: 'Nữ',
          goal: 'muscle',
          experienceLevel: 'beginner',
          sessionsPerWeek: 2,
        ),
      );
      await storage.bindUser('two');
      expect(storage.loadProfile(), isNull);
      expect(storage.loadWorkoutSessions(), isEmpty);
      expect(storage.loadMembership().id, isEmpty);
      expect(storage.loadMembership().active, isFalse);
      await storage.saveProfile(
        UserProfile(
          name: 'Bob',
          age: 35,
          height: 175,
          weight: 75,
          gender: 'Nam',
          goal: 'maintenance',
          experienceLevel: 'beginner',
          sessionsPerWeek: 3,
        ),
      );
      await storage.bindUser('one');
      expect(storage.loadProfile()!.name, 'Alice');
      await storage.clearAll();
      expect(storage.loadProfile(), isNull);
      await storage.bindUser('two');
      expect(storage.loadProfile()!.name, 'Bob');
    },
  );
  test('Plan respects selected days and reduces beginner loading', () {
    final plan = WorkoutPlanRepository.generatePlan(
      'muscle',
      'beginner',
      4,
      availableWeekdays: [2, 6],
    );
    expect(plan.where((day) => !day.isRest).map((day) => day.dayName), [
      'Thứ Ba',
      'Thứ Bảy',
    ]);
    expect(
      plan
          .where((day) => !day.isRest)
          .expand((day) => day.exercises)
          .every((exercise) => exercise.weight == 0 && exercise.sets == 2),
      isTrue,
    );
  });
  testWidgets(
    'First profile starts empty, validates, and calculates real BMI',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: OnboardingScreen(onCompleted: () {})),
      );
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        isEmpty,
      );
      await tester.enterText(find.byType(TextFormField).at(2), '180');
      await tester.enterText(find.byType(TextFormField).at(3), '81');
      await tester.pump();
      expect(find.text('BMI: 25.0'), findsOneWidget);
      expect(StorageService.instance.loadProfile(), isNull);
    },
  );
  testWidgets('Bell, home history, promotions and live settings are separate', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(key: boundaryKey, child: const FitPlanApp()),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
    await tester.tap(find.byTooltip('Thông báo'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có thông báo'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cài đặt').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sáng'));
    await tester.pumpAndSettle();
    expect(AppSettingsService.themeMode.value, ThemeMode.light);
    expect(AppColors.background, const Color(0xFFF5F7FB));
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold).last).backgroundColor,
      AppColors.background,
    );
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Account settings'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(tr('Trang chủ'), 'Home');
    await tester.runAsync(() async {
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('.tmp/review/settings-light-english.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    AppSettingsService.language.value = 'vi';
    AppSettingsService.themeMode.value = ThemeMode.dark;
  });
}
