import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fit_gym/main.dart';
import 'package:fit_gym/screens/exercise_library_screen.dart';
import 'package:fit_gym/screens/auth_screen.dart';
import 'package:fit_gym/screens/goal_screen.dart';
import 'package:fit_gym/screens/history_screen.dart';
import 'package:fit_gym/screens/home_screen.dart';
import 'package:fit_gym/screens/level_screen.dart';
import 'package:fit_gym/screens/profile_screen.dart';
import 'package:fit_gym/screens/progress_statistics_screen.dart';
import 'package:fit_gym/screens/schedule_screen.dart';
import 'package:fit_gym/screens/workout_plan_screen.dart';
import 'package:fit_gym/screens/workout_session_screen.dart';
import 'package:fit_gym/services/storage_service.dart';
import 'package:fit_gym/theme/app_theme.dart';
import 'package:fit_gym/widgets/modern_components.dart';

import 'font_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppTestFonts);
  testWidgets('FitPlan app launches', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const FitPlanApp());
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(IndexedStack), findsOneWidget);
    final nav = find.byType(ModernBottomNav);
    expect(
      find.descendant(of: nav, matching: find.text('Trang chủ')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: nav, matching: find.text('Lịch tập')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: nav, matching: find.text('Bài tập')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: nav, matching: find.text('Cá nhân')),
      findsOneWidget,
    );
  });

  testWidgets('Bottom navigation changes the active page', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const FitPlanApp());
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(ModernBottomNav),
        matching: find.text('Bài tập'),
      ),
    );
    await tester.pumpAndSettle();

    final stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
    expect(stack.index, 2);
  });

  testWidgets('Redesigned screens render on a phone viewport', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> pumpScreen(Widget screen) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.darkTheme, home: screen),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    await pumpScreen(const HomeScreen());
    await pumpScreen(const ScheduleScreen());
    await pumpScreen(const WorkoutPlanScreen());
    await pumpScreen(const ExerciseLibraryScreen());
    await pumpScreen(const ProfileScreen());
    await pumpScreen(const GoalScreen());
    await pumpScreen(const LevelScreen());
    await pumpScreen(const WorkoutPlanScreen());
    await pumpScreen(const HistoryScreen());
    await pumpScreen(const ProgressStatisticsScreen());
    await pumpScreen(const WorkoutSessionScreen());
  });

  testWidgets('Completing a set starts the rest timer', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const WorkoutSessionScreen(),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Hiệp 1').first);
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Đang nghỉ'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Core screens support larger accessibility text', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> pumpScreen(Widget screen) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: screen,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    await pumpScreen(const HomeScreen());
    await pumpScreen(const ScheduleScreen());
    await pumpScreen(const ExerciseLibraryScreen());
    await pumpScreen(const WorkoutSessionScreen());
  });

  testWidgets('Navigation adapts to a wider window', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const FitPlanApp());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(ModernBottomNav), findsNothing);
  });

  testWidgets('Home meets mobile tap-target and label guidelines', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const FitPlanApp());
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  });

  testWidgets('Daily check-in can be completed on mobile', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.instance.init();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.darkTheme, home: const HomeScreen()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.monitor_heart_outlined));
    await tester.pumpAndSettle();

    expect(find.byType(Slider), findsNWidgets(3));
    await tester.tap(find.text('Lưu check-in hôm nay'));
    await tester.pumpAndSettle();

    expect(StorageService.instance.loadTodayCheckIn(), isNotNull);
  });

  testWidgets('Exercise can be favorited and filtered', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.instance.init();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const ExerciseLibraryScreen(),
      ),
    );
    await tester.pumpAndSettle();
    final favoriteButton = find.byType(IconButton).first;
    await tester.ensureVisible(favoriteButton);
    await tester.tap(favoriteButton);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(StorageService.instance.loadFavoriteExerciseIds(), hasLength(1));
  });

  testWidgets('Weight measurement form validates and saves data', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.instance.init();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const ProgressStatisticsScreen(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ghi cân nặng'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '72.5');
    await tester.tap(find.text('Lưu số đo'));
    await tester.pumpAndSettle();

    expect(StorageService.instance.loadBodyMeasurements(), hasLength(1));
    expect(find.text('72.5 kg'), findsOneWidget);
  });

  testWidgets('Authentication screen is mobile responsive', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.darkTheme, home: const AuthScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Đăng nhập'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Workout RPE can be adjusted', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const WorkoutSessionScreen(),
      ),
    );
    await tester.pumpAndSettle();
    final firstSlider = find.byType(Slider).first;
    await tester.ensureVisible(firstSlider);
    await tester.drag(firstSlider, const Offset(140, 0));
    await tester.pump();

    expect(tester.widget<Slider>(firstSlider).value, greaterThan(7));
  });
}
