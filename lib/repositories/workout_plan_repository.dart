import '../models/data_models.dart';
import '../services/app_clock.dart';
import 'exercise_repository.dart';
import 'muscle_program_catalog.dart';

class WorkoutPlanRepository {
  static const version = 2;
  static const _dayNames = [
    'Thứ Hai',
    'Thứ Ba',
    'Thứ Tư',
    'Thứ Năm',
    'Thứ Sáu',
    'Thứ Bảy',
    'Chủ Nhật',
  ];

  /// Includes preparation, transitions and warm-up. Short weeks rotate exercises.
  static int exerciseCapacity(int minutes) =>
      ((minutes.clamp(15, 120) - 6) ~/ 8).clamp(1, 10);
  static int estimatedMinutes(Iterable<PlanExercise> exercises) =>
      exercises.isEmpty ? 0 : 6 + exercises.length * 8;

  static List<String> _roundRobin(List<String> groups) {
    final result = <String>[];
    for (var i = 0; i < 3; i++) {
      for (final group in groups) {
        final ids = MuscleProgramCatalog.groups[group]!;
        if (i < ids.length) result.add(ids[i]);
      }
    }
    return result;
  }

  static List<List<String>> _split(int sessions) {
    if (sessions <= 3) {
      return [_roundRobin(MuscleProgramCatalog.groups.keys.toList())];
    }
    if (sessions == 4) {
      return [
        _roundRobin(['Ngực', 'Vai', 'Tay sau']),
        _roundRobin(['Lưng', 'Tay trước']),
        _roundRobin(['Đùi trước', 'Bắp chân', 'Cơ bụng']),
        _roundRobin(['Đùi sau', 'Mông']),
      ];
    }
    return [
      _roundRobin(['Ngực', 'Tay sau']),
      _roundRobin(['Lưng', 'Tay trước']),
      _roundRobin(['Đùi trước', 'Bắp chân']),
      _roundRobin(['Vai', 'Cơ bụng']),
      _roundRobin(['Đùi sau', 'Mông']),
    ];
  }

  static List<PlanDay> generatePlan(
    String goal,
    String level,
    int sessionsPerWeek, {
    List<int>? availableWeekdays,
    UserProfile? profile,
    int availableMinutes = 60,
    DateTime? weekOf,
  }) {
    final n = sessionsPerWeek.clamp(1, 7);
    const defaults = [1, 3, 5, 7, 2, 4, 6];
    final requested =
        (availableWeekdays ?? profile?.availableWeekdays ?? <int>[])
            .where((day) => day >= 1 && day <= 7)
            .toSet()
            .toList()
          ..sort();
    // Availability is authoritative; never add an unavailable day.
    final trainingDays =
        (requested.isEmpty ? defaults : requested).take(n).toList()..sort();
    final conservative =
        level == 'beginner' ||
        (profile != null &&
            (profile.age >= 60 ||
                profile.bmi >= 30 ||
                profile.healthNotes.trim().isNotEmpty));
    final capacity = exerciseCapacity(availableMinutes);
    final split = _split(trainingDays.length);
    final now = AppClock.day(weekOf ?? AppClock.now());
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final week = (monday.difference(DateTime(2026, 10, 26)).inDays ~/ 7).abs();
    final catalogue = {for (final e in ExerciseRepository.getAll()) e.id: e};
    final days = <PlanDay>[];
    var session = 0;
    for (var weekday = 1; weekday <= 7; weekday++) {
      if (!trainingDays.contains(weekday)) {
        days.add(
          PlanDay(dayName: _dayNames[weekday - 1], isRest: true, exercises: []),
        );
        continue;
      }
      final pool = split[session % split.length];
      final pages = (pool.length / capacity).ceil();
      final page = split.length == 1
          ? (week * trainingDays.length + session) % pages
          : week % pages;
      final ids = pool.skip(page * capacity).take(capacity);
      final warmed = <String>{};
      final exercises = ids.map((id) {
        final exercise = catalogue[id]!;
        return PlanExercise(
          exercise: exercise,
          sets: conservative ? 2 : 3,
          reps: goal == 'fatloss' || goal == 'cardio' ? 12 : 10,
          weight: 0,
          warmupSets: warmed.add(exercise.focusGroup) ? 1 : 0,
        );
      }).toList();
      days.add(
        PlanDay(
          dayName: _dayNames[weekday - 1],
          isRest: false,
          exercises: exercises,
        ),
      );
      session++;
    }
    return days;
  }
}
