import 'package:fit_gym/screens/workout_session_screen.dart';
import 'package:fit_gym/services/app_clock.dart';
import 'package:fit_gym/services/storage_service.dart';
import 'package:fit_gym/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fit_gym/models/data_models.dart';

import 'font_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppTestFonts);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.instance.init();
  });

  testWidgets('Recorded workout opens in read-only mode', (tester) async {
    final storage = StorageService.instance;
    final today = AppClock.today;

    await storage.addWorkoutSession(
      WorkoutSession(
        id: 'recorded_day',
        dayName: 'Buổi đã tập',
        date: DateTime.now(),
        logs: [],
        branchName: 'Thủ Đức',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          settings: RouteSettings(
            arguments: {
              'id': 'recorded_day',
              'dayName': 'Buổi đã tập',
              'date': today.toIso8601String(),
              'exercises': [
                {'exerciseName': 'Squat', 'sets': 2, 'reps': 10},
              ],
            },
          ),
          builder: (_) => const WorkoutSessionScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Hoàn thành buổi tập'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(Slider), findsNothing);
    expect(find.text('Squat'), findsOneWidget);
    expect(
      find.text(
        'Buổi tập này đã được ghi nhận. Bạn có thể xem kết quả trong lịch sử tập luyện.',
      ),
      findsOneWidget,
    );
    expect(storage.loadWorkoutSessions(), hasLength(1));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final entry in <String, double?>{
    '-5': null,
    'NaN': null,
    'Infinity': null,
    'abc': null,
    '': null,
    '100000': null,
    '0': 0,
    '12.5': 12.5,
    '12,5': 12.5,
  }.entries) {
    testWidgets('Workout weight input "${entry.key}"', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            settings: RouteSettings(
              arguments: {
                'id': 'negative_weight',
                'dayName': 'Kiểm tra số kg',
                'date': AppClock.today.toIso8601String(),
                'exercises': [
                  {'exerciseName': 'Squat', 'sets': 1, 'reps': 10, 'weight': 0},
                ],
              },
            ),
            builder: (_) => const WorkoutSessionScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Chọn nơi tập để không bị chặn bởi kiểm tra thiếu chi nhánh.
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tập tại nhà').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), entry.key);
      await tester.tap(find.text('Hiệp 1'));
      await tester.pump();

      await tester.tap(find.text('Hoàn thành buổi tập'));
      await tester.pumpAndSettle();

      final saved = StorageService.instance.loadWorkoutSessions();

      // Dọn màn hình để hủy timer nghỉ trước khi kiểm tra kết quả.
      await tester.pumpWidget(const SizedBox.shrink());

      if (entry.value == null) {
        expect(saved, isEmpty);
      } else {
        expect(saved, hasLength(1));
        expect(saved.single.logs, hasLength(1));
        expect(saved.single.logs.single.weight, entry.value);
      }
    });
  }
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
