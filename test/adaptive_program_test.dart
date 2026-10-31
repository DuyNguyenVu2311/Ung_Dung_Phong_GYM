import 'package:fit_gym/models/data_models.dart';
import 'package:fit_gym/repositories/exercise_repository.dart';
import 'package:fit_gym/repositories/muscle_program_catalog.dart';
import 'package:fit_gym/repositories/workout_plan_repository.dart';
import 'package:fit_gym/repositories/workout_schedule_repository.dart';
import 'package:fit_gym/services/app_clock.dart';
import 'package:fit_gym/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

UserProfile profile() => UserProfile(
  name: 'Customer',
  age: 25,
  height: 175,
  weight: 70,
  gender: 'Nam',
  goal: 'muscle',
  experienceLevel: 'intermediate',
  sessionsPerWeek: 3,
  availableWeekdays: [1, 3, 5],
);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.instance.init();
  });

  test(
    'Five available 60-minute sessions cover every requested group and angle',
    () {
      final plan = WorkoutPlanRepository.generatePlan(
        'muscle',
        'intermediate',
        5,
        availableWeekdays: [1, 2, 3, 5, 6],
        weekOf: DateTime(2026, 10, 26),
      );
      final exercises = plan.expand((day) => day.exercises).toList();
      expect(exercises.length, 26);
      expect(exercises.map((e) => e.exercise.id).toSet().length, 26);
      for (final entry in MuscleProgramCatalog.groups.entries) {
        expect(
          exercises.where((e) => e.exercise.focusGroup == entry.key).length,
          entry.value.length,
        );
      }
      for (final day in plan.where((day) => !day.isRest)) {
        final groups = <String>{};
        for (final exercise in day.exercises) {
          expect(
            exercise.warmupSets,
            groups.add(exercise.exercise.focusGroup) ? 1 : 0,
          );
          expect(exercise.exercise.targetArea, isNotEmpty);
          expect(exercise.weight, 0);
        }
      }
      expect(ExerciseRepository.filter(muscleGroup: 'Đùi sau').length, 3);
      expect(
        ExerciseRepository.filter(query: 'vai sau').map((e) => e.id),
        contains('ex022'),
      );
    },
  );

  test('1–7 available days and 30–90 minutes stay bounded and rotate all exercises', () {
    final requiredIds = MuscleProgramCatalog.groups.values
        .expand((ids) => ids)
        .toSet();
    for (var sessions = 1; sessions <= 7; sessions++) {
      final weekdays = List.generate(sessions, (i) => i + 1);
      for (final minutes in [30, 45, 60, 75, 90]) {
        final seen = <String>{};
        for (var week = 0; week < 12; week++) {
          final plan = WorkoutPlanRepository.generatePlan(
            'muscle',
            'beginner',
            sessions,
            availableWeekdays: weekdays,
            availableMinutes: minutes,
            weekOf: DateTime(2026, 10, 26).add(Duration(days: week * 7)),
          );
          expect(plan.where((d) => !d.isRest).length, sessions);
          for (var i = 0; i < plan.length; i++) {
            final day = plan[i];
            expect(day.isRest, !weekdays.contains(i + 1));
            expect(
              WorkoutPlanRepository.estimatedMinutes(day.exercises),
              lessThanOrEqualTo(minutes),
            );
            final ids = day.exercises.map((e) => e.exercise.id).toList();
            expect(ids.toSet().length, ids.length);
            seen.addAll(ids);
          }
        }
        expect(
          seen,
          containsAll(requiredIds),
          reason: '$sessions days / $minutes minutes',
        );
      }
    }
  });

  test('Availability never silently adds days the customer did not select', () {
    final plan = WorkoutPlanRepository.generatePlan(
      'muscle',
      'beginner',
      5,
      availableWeekdays: [2, 6, 6, 9],
    );
    expect(plan.where((day) => !day.isRest).map((day) => day.dayName), [
      'Thứ Ba',
      'Thứ Bảy',
    ]);
  });

  test('Changing duration preserves completed sessions and check-in changes only today', () async {
    await StorageService.instance.saveProfile(profile());
    final now = AppClock.today;
    final plan = WorkoutPlanRepository.generatePlan(
      'muscle',
      'intermediate',
      7,
      availableWeekdays: [1, 2, 3, 4, 5, 6, 7],
    );
    final original = await WorkoutScheduleRepository.generateSchedule(plan);
    final today = original[now.weekday - 1];
    expect((today['exercises'] as List), isNotEmpty);
    await StorageService.instance.saveDailyCheckIn(
      DailyCheckIn(
        date: AppClock.now(),
        energy: 5,
        soreness: 1,
        sleepQuality: 5,
        availableMinutes: 30,
      ),
    );
    final reduced = await WorkoutScheduleRepository.ensureCurrentWeek();
    expect(
      reduced[now.weekday - 1]['estimatedMinutes'] as int,
      lessThanOrEqualTo(30),
    );
    expect(
      (reduced[now.weekday - 1]['exercises'] as List).length,
      lessThanOrEqualTo(3),
    );
    final sessionId = today['id'] as String;

    await StorageService.instance.addWorkoutSession(
      WorkoutSession(
        id: sessionId,
        dayName: today['dayName'] as String,
        date: DateTime.now(),
        branchName: 'Tập tại nhà',
        logs: [
          ExerciseLog(
            id: '${sessionId}_log',
            sessionId: sessionId,
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
    await WorkoutScheduleRepository.setStatus(
      today['id'] as String,
      'completed',
    );
    final completed = WorkoutScheduleRepository.loadSchedule()[now.weekday - 1];
    await WorkoutScheduleRepository.setWorkoutMinutes(90);
    expect(
      WorkoutScheduleRepository.loadSchedule()[now.weekday - 1],
      completed,
    );
    expect(WorkoutScheduleRepository.workoutMinutes, 90);
  });
}
