import '../models/data_models.dart';
import '../repositories/exercise_repository.dart';

class WorkoutPlanRepository {
  static const List<String> _dayNames = [
    'Thứ Hai',
    'Thứ Ba',
    'Thứ Tư',
    'Thứ Năm',
    'Thứ Sáu',
    'Thứ Bảy',
    'Chủ Nhật',
  ];

  static final Map<String, List<String>> _muscleByGoal = {
    'muscle': ['Ngực', 'Lưng', 'Chân', 'Vai', 'Cơ bụng'],
    'fatloss': ['Chân', 'Lưng', 'Ngực', 'Vai', 'Cơ bụng'],
    'maintenance': ['Ngực', 'Lưng', 'Chân', 'Vai', 'Cơ bụng'],
    'mobility': ['Lưng', 'Chân', 'Vai', 'Cơ bụng'],
    'home': ['Ngực', 'Chân', 'Cơ bụng', 'Vai'],
    'cardio': ['Chân', 'Cơ bụng', 'Lưng', 'Vai'],
  };

  static int _setsFor(String level) => level == 'beginner' ? 3 : 4;
  static int _repsFor(String level) => level == 'beginner' ? 10 : 12;

  static double _defaultWeight(Exercise ex) {
    switch (ex.muscleGroup) {
      case 'Ngực':
        return 60;
      case 'Lưng':
        return 50;
      case 'Chân':
        return 70;
      case 'Vai':
        return 30;
      case 'Tay':
        return 20;
      case 'Cơ bụng':
        return 0;
      default:
        return 40;
    }
  }

  static List<Exercise> _pick(List<Exercise> all, String? group, int count) {
    final pool = group == null
        ? all
        : all.where((e) => e.muscleGroup == group).toList();
    if (pool.isEmpty) return all.take(count).toList();
    return pool.take(count).toList();
  }

  /// Tạo kế hoạch tập theo qui tắc: mục tiêu, trình độ, số buổi/tuần.
  static List<PlanDay> generatePlan(
    String goal,
    String level,
    int sessionsPerWeek, {
    List<int>? availableWeekdays,
    UserProfile? profile,
  }) {
    final all = ExerciseRepository.getAll();
    final n = sessionsPerWeek.clamp(1, 5).toInt();
    final conservative =
        level == 'beginner' ||
        (profile != null &&
            (profile.age >= 60 ||
                profile.bmi >= 30 ||
                profile.healthNotes.trim().isNotEmpty));
    final seq = _muscleByGoal[goal] ?? _muscleByGoal['muscle']!;

    const distributedDefaults = [1, 3, 5, 7, 2];
    final requested =
        (availableWeekdays ?? const <int>[])
            .where((day) => day >= 1 && day <= 7)
            .toSet()
            .toList()
          ..sort();
    final trainingDays = <int>[];
    for (final day in requested.isEmpty ? distributedDefaults : requested) {
      if (!trainingDays.contains(day)) trainingDays.add(day);
      if (trainingDays.length == n) break;
    }

    final days = <PlanDay>[];
    var trained = 0;
    for (var weekday = 1; weekday <= 7; weekday++) {
      if (!trainingDays.contains(weekday)) {
        days.add(
          PlanDay(dayName: _dayNames[weekday - 1], isRest: true, exercises: []),
        );
        continue;
      }
      final group = seq[trained % seq.length];
      final exercises = conservative
          ? [
              'Ngực',
              'Lưng',
              'Chân',
            ].expand((muscle) => _pick(all, muscle, 1)).toList()
          : _pick(all, group, 4);
      days.add(
        PlanDay(
          dayName: _dayNames[weekday - 1],
          isRest: false,
          exercises: exercises
              .map(
                (exercise) => PlanExercise(
                  exercise: exercise,
                  sets: conservative ? 2 : _setsFor(level),
                  reps: _repsFor(level),
                  weight: conservative ? 0 : _defaultWeight(exercise),
                ),
              )
              .toList(),
        ),
      );
      trained++;
    }
    return days;
  }
}
