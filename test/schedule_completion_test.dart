import 'dart:convert';

import 'package:fit_gym/models/data_models.dart';
import 'package:fit_gym/repositories/workout_schedule_repository.dart';
import 'package:fit_gym/services/app_clock.dart';
import 'package:fit_gym/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.instance.init();
  });

  Future<void> saveDay(String status) async {
    await StorageService.setString(
      'fit_schedule',
      jsonEncode([
        {
          'id': 'today_workout',
          'dayName': 'Buổi hôm nay',
          'date': AppClock.today.toIso8601String(),
          'isRest': false,
          'status': status,
          'exercises': [],
        },
      ]),
    );
  }

  test('Completed label without a saved workout is not counted', () async {
    // Mô phỏng trạng thái hoàn thành thủ công từ phiên bản cũ.
    await saveDay('completed');

    final schedule = WorkoutScheduleRepository.loadSchedule();

    expect(schedule.single['status'], 'planned');
    expect(WorkoutScheduleRepository.completedCount(), 0);
    expect(StorageService.instance.loadWorkoutSessions(), isEmpty);
  });

  test('Cannot mark completed without a saved workout', () async {
    await saveDay('planned');

    await expectLater(
      WorkoutScheduleRepository.setStatus('today_workout', 'completed'),
      throwsA(isA<StateError>()),
    );

    expect(
      WorkoutScheduleRepository.loadSchedule().single['status'],
      'planned',
    );
  });
  test('Saved workout determines completion and cannot be reset', () async {
    await saveDay('planned');

    await StorageService.instance.addWorkoutSession(
      WorkoutSession(
        id: 'today_workout',
        dayName: 'Buổi hôm nay',
        date: DateTime.now(),
        branchName: 'Tập tại nhà',
        logs: [
          ExerciseLog(
            id: 'today_log',
            sessionId: 'today_workout',
            exerciseName: 'Squat',
            sets: 2,
            reps: 10,
            weight: 20,
            rpe: 7,
            isPersonalRecord: false,
          ),
        ],
      ),
    );

    // Tự nhận trạng thái hoàn thành từ bản ghi, dù lịch lưu là planned.
    expect(
      WorkoutScheduleRepository.loadSchedule().single['status'],
      'completed',
    );
    expect(WorkoutScheduleRepository.completedCount(), 1);

    // Luồng hoàn thành hợp lệ vẫn hoạt động.
    await WorkoutScheduleRepository.setStatus('today_workout', 'completed');

    // Không cho chuyển ngược về planned.
    await expectLater(
      WorkoutScheduleRepository.setStatus('today_workout', 'planned'),
      throwsA(isA<StateError>()),
    );

    expect(
      WorkoutScheduleRepository.loadSchedule().single['status'],
      'completed',
    );
  });
}
