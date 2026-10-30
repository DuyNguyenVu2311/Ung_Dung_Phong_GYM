import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fit_gym/models/data_models.dart';
import 'package:fit_gym/screens/home_screen.dart';
import 'package:fit_gym/screens/schedule_screen.dart';
import 'package:fit_gym/screens/exercise_library_screen.dart';
import 'package:fit_gym/screens/membership_screen.dart';
import 'package:fit_gym/screens/main_app_shell.dart';
import 'package:fit_gym/services/storage_service.dart';
import 'package:fit_gym/theme/app_theme.dart';

import 'font_test_support.dart';

DailyCheckIn checkIn(int energy, int soreness, int sleep) => DailyCheckIn(
  date: DateTime(2026, 10, 30),
  energy: energy,
  soreness: soreness,
  sleepQuality: sleep,
  availableMinutes: 90,
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppTestFonts);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.instance.init();
  });
  test(
    'Critical check-in states always agree on resting and zero workout minutes',
    () {
      for (final entry in [
        checkIn(1, 1, 5),
        checkIn(5, 1, 1),
        checkIn(5, 5, 5),
        checkIn(1, 1, 1),
      ]) {
        expect(entry.shouldRest, isTrue);
        expect(entry.suggestedMinutes, 0);
        expect(entry.recommendation, contains('nghỉ'));
        expect(entry.trainingDecision, contains('nghỉ'));
      }
      expect(checkIn(5, 1, 5).readinessScore, 100);
      expect(checkIn(1, 5, 1).readinessScore, 0);
      expect(checkIn(3, 3, 3).recoveryOnly, isTrue);
      expect(checkIn(3, 3, 3).suggestedMinutes, lessThan(90));
    },
  );
  testWidgets(
    'Soreness uses reverse colors and shows explicit scale endpoints',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.darkTheme, home: const HomeScreen()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.monitor_heart_outlined));
      await tester.pumpAndSettle();
      tester.widget<Slider>(find.byType(Slider).at(0)).onChanged!(1);
      tester.widget<Slider>(find.byType(Slider).at(1)).onChanged!(1);
      tester.widget<Slider>(find.byType(Slider).at(2)).onChanged!(1);
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.text('Không đau')).style!.color,
        AppColors.primary,
      );
      expect(
        tester.widget<Text>(find.text('Kiệt sức')).style!.color,
        AppColors.error,
      );
      expect(
        tester.widget<Text>(find.text('Rất kém')).style!.color,
        AppColors.error,
      );
      expect(find.text('1 · Không đau'), findsOneWidget);
      expect(find.text('5 · Đau bất thường'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('Only the visited navigation pages are initialized', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.darkTheme, home: const MainAppShell()),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ScheduleScreen, skipOffstage: false), findsNothing);
    expect(find.byType(MembershipScreen, skipOffstage: false), findsNothing);
    await tester.tap(find.text('Bài tập').last);
    await tester.pumpAndSettle();
    expect(find.byType(ExerciseLibraryScreen), findsOneWidget);
    expect(find.byType(HomeScreen, skipOffstage: false), findsOneWidget);
    expect(find.byType(MembershipScreen, skipOffstage: false), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
