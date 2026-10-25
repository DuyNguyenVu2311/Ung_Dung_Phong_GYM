import 'dart:convert';

import '../models/data_models.dart';
import '../services/storage_service.dart';

class WorkoutScheduleRepository {
  static const _kSchedule = 'fit_schedule';

  /// Chuyển kế hoạch (PlanDay) thành danh sách buổi tập đã lên lịch trong tuần.
  static List<Map<String, dynamic>> generateSchedule(List<PlanDay> planDays, {DateTime? start}) {
    final now = start ?? DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final List<Map<String, dynamic>> schedule = [];
    int dayIdx = 0;

    for (final pd in planDays) {
      if (dayIdx >= 7) break;
      final date = monday.add(Duration(days: dayIdx));
      schedule.add({
        'id': 'ws_${date.year}_${date.month}_${date.day}',
        'dayName': pd.dayName,
        'date': date.toIso8601String(),
        'isRest': pd.isRest,
        'status': pd.isRest ? 'rest_day' : 'planned',
        'exerciseCount': pd.exercises.length,
        'exercises': pd.exercises.map((e) => {
          'exerciseName': e.exercise.name,
          'sets': e.sets,
          'reps': e.reps,
          'weight': e.weight,
        }).toList(),
      });
      dayIdx++;
    }

    StorageService.setString(_kSchedule, jsonEncode(schedule));
    return schedule;
  }

  /// Đọc lịch tập đã lưu (bắt lỗi JSON hỏng/trống).
  static List<Map<String, dynamic>> loadSchedule() {
    final s = StorageService.getString(_kSchedule);
    if (s == null || s.isEmpty) return [];
    try {
      final decoded = jsonDecode(s);
      if (decoded is! List) return [];
      return decoded.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Cập nhật trạng thái một buổi tập.
  static Future<void> setStatus(String id, String status) async {
    final list = loadSchedule();
    final idx = list.indexWhere((e) => e['id'] == id);
    if (idx >= 0) {
      list[idx]['status'] = status;
      await StorageService.setString(_kSchedule, jsonEncode(list));
    }
  }

  /// Danh sách ngày nghỉ trong tuần.
  static List<String> restDays() => loadSchedule()
      .where((e) => e['isRest'] == true)
      .map((e) => e['dayName'] as String)
      .toList();

  /// Số buổi đã hoàn thành trong tuần.
  static int completedCount() => loadSchedule().where((e) => e['status'] == 'completed').length;

  /// Tổng buổi có kế hoạch (không tính ngày nghỉ).
  static int plannedCount() => loadSchedule().where((e) => e['isRest'] != true).length;
}
