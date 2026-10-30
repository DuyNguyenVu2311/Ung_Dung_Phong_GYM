import 'package:fit_gym/screens/workout_session_screen.dart';
import 'package:fit_gym/services/app_clock.dart';
import 'package:fit_gym/services/storage_service.dart';
import 'package:fit_gym/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'font_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppTestFonts);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.instance.init();
  });

  for (final offset in [-1, 0, 1]) {
    testWidgets('Scheduled day offset $offset only permits today to train', (
      tester,
    ) async {
      final date = AppClock.today.add(Duration(days: offset));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            settings: RouteSettings(
              arguments: {
                'id': 'test_day',
                'dayName': 'Buổi tập kiểm tra',
                'date': date.toIso8601String(),
                'exercises': [
                  {
                    'exerciseName': 'Squat',
                    'sets': 2,
                    'reps': 10,
                    'warmupSets': 1,
                  },
                ],
              },
            ),
            builder: (_) => const WorkoutSessionScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (offset == 0) {
        expect(find.text('Hoàn thành buổi tập'), findsOneWidget);
        expect(find.byType(Slider), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        await tester.tap(find.byType(CheckboxListTile));
        await tester.pumpAndSettle();
        expect(find.text('0/2 hiệp hoàn thành'), findsOneWidget);
      } else {
        expect(find.text('Hoàn thành buổi tập'), findsNothing);
        expect(find.byType(Slider), findsNothing);
        expect(find.byType(TextField), findsNothing);
        expect(find.text('Squat'), findsOneWidget);
        expect(StorageService.instance.loadWorkoutSessions(), isEmpty);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
