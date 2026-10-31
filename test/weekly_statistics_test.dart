import 'package:fit_gym/models/data_models.dart';
import 'package:fit_gym/screens/progress_statistics_screen.dart';
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

  testWidgets('Weekly chart excludes workouts from previous weeks', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final today = AppClock.today;
    final monday = today.subtract(Duration(days: today.weekday - 1));

    // 05:00 UTC là 12:00 tại Việt Nam.
    final currentMonday = DateTime.utc(
      monday.year,
      monday.month,
      monday.day,
      5,
    );
    // Thứ Hai 00:00 tại Việt Nam, biểu diễn bằng UTC.
    final weekStartUtc = DateTime.utc(
      monday.year,
      monday.month,
      monday.day,
    ).subtract(const Duration(hours: 7));

    final nextWeekStartUtc = weekStartUtc.add(const Duration(days: 7));

    WorkoutSession session(String id, DateTime date, double weight) =>
        WorkoutSession(
          id: id,
          dayName: 'Buổi kiểm tra',
          date: date,
          branchName: 'Tập tại nhà',
          logs: [
            ExerciseLog(
              id: '${id}_log',
              sessionId: id,
              exerciseName: 'Squat',
              sets: 1,
              reps: 10,
              weight: weight,
              rpe: 7,
              isPersonalRecord: false,
            ),
          ],
        );

    await StorageService.instance.saveWorkoutSessions([
      // Tuần hiện tại: thứ Hai, 1000 kg.
      session('this_week', currentMonday, 100),

      // Tuần trước: cùng thứ Hai, 2000 kg, phải loại khỏi biểu đồ.
      session(
        'last_week',
        currentMonday.subtract(const Duration(days: 7)),
        200,
      ),

      // Đúng đầu tuần Việt Nam: thêm 2000 kg vào thứ Hai.
      session('week_start', weekStartUtc, 200),

      // Trước đầu tuần một giây: 8000 kg, phải loại.
      session(
        'before_week',
        weekStartUtc.subtract(const Duration(seconds: 1)),
        800,
      ),

      // Cuối Chủ nhật Việt Nam: 4000 kg, vẫn thuộc tuần này.
      session(
        'week_end',
        nextWeekStartUtc.subtract(const Duration(seconds: 1)),
        400,
      ),

      // Đúng đầu tuần tiếp theo: 16000 kg, phải loại.
      session('next_week', nextWeekStartUtc, 1600),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const ProgressStatisticsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Tổng lịch sử: 1000 + 2000 = 3000 kg.
    expect(find.text('33.0 tấn'), findsOneWidget);

    // Tuần hiện tại chỉ có thứ Hai 3000 kg và Chủ nhật 4000 kg.
    expect(find.text('3.0k'), findsOneWidget);
    expect(find.text('4.0k'), findsOneWidget);

    // Xác nhận cột 3000 kg là thứ Hai, cột 4000 kg là Chủ nhật.
    for (final entry in {'3.0k': 'T2', '4.0k': 'CN'}.entries) {
      final column = find
          .ancestor(of: find.text(entry.key), matching: find.byType(Column))
          .first;

      expect(
        find.descendant(of: column, matching: find.text(entry.value)),
        findsOneWidget,
      );
    }
  });
}
