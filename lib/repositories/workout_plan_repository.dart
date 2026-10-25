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
  };

  static int _setsFor(String level) => level == 'beginner' ? 3 : 4;
  static int _repsFor(String level) => level == 'beginner' ? 10 : 12;

  static double _defaultWeight(Exercise ex) {
    switch (ex.muscleGroup) {
      case 'Ngực': return 60;
      case 'Lưng': return 50;
      case 'Chân': return 70;
      case 'Vai': return 30;
      case 'Tay': return 20;
      case 'Cơ bụng': return 0;
      default: return 40;
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
  static List<PlanDay> generatePlan(String goal, String level, int sessionsPerWeek) {
    final all = ExerciseRepository.getAll();
    final n = sessionsPerWeek.clamp(1, 5);
    final seq = _muscleByGoal[goal] ?? _muscleByGoal['muscle']!;

    final List<PlanDay> days = [];
    int trained = 0;
    int dayIndex = 0;

    while (trained < n && dayIndex < _dayNames.length) {
      final group = seq[trained % seq.length];
      final exercises = _pick(all, group, _setsFor(level) == 3 ? 3 : 4);
      days.add(PlanDay(
        dayName: _dayNames[dayIndex],
        isRest: false,
        exercises: exercises.map((e) => PlanExercise(
          exercise: e,
          sets: _setsFor(level),
          reps: _repsFor(level),
          weight: _defaultWeight(e),
        )).toList(),
      ));
      trained++;
      dayIndex++;

      // nghỉ sau mỗi 2 buổi tập (trừ buổi cuối cùng trong tuần)
      if (trained % 2 == 0 && trained < n && dayIndex < _dayNames.length) {
        days.add(PlanDay(
          dayName: _dayNames[dayIndex],
          isRest: true,
          exercises: [],
        ));
        dayIndex++;
      }
    }

    return days;
  }
}
