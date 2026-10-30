import 'dart:convert';

import '../models/data_models.dart';
import '../services/storage_service.dart';
import '../services/app_clock.dart';
import 'workout_plan_repository.dart';

class WorkoutScheduleRepository {
  static const _kSchedule = 'fit_schedule';
  static Future<List<Map<String, dynamic>>> ensureCurrentWeek({
    DateTime? now,
  }) async {
    final current = AppClock.day(now ?? AppClock.now());
    final monday = current.subtract(Duration(days: current.weekday - 1));
    final existing = loadSchedule();
    final first = existing.isEmpty
        ? null
        : DateTime.tryParse(existing.first['date'] as String? ?? '');
    if (first != null && AppClock.sameDay(first, monday)) return existing;
    final profile = StorageService.instance.loadProfile();
    if (profile == null) return existing;
    return generateSchedule(
      WorkoutPlanRepository.generatePlan(
        profile.goal,
        profile.experienceLevel,
        profile.sessionsPerWeek,
        availableWeekdays: profile.availableWeekdays,
        profile: profile,
      ),
      start: current,
    );
  }

  static Future<void> updateFutureSchedule(List<PlanDay> plan) async {
    final old = loadSchedule();
    final generated = await generateSchedule(plan);
    final now = AppClock.now();
    final today = DateTime(now.year, now.month, now.day);
    final result = generated.map((day) {
      final date = DateTime.parse(day['date'] as String);
      final previous = old.where((item) => item['id'] == day['id']);
      if ((date.isBefore(today) ||
              previous.any((item) => item['status'] == 'completed')) &&
          previous.isNotEmpty) {
        return previous.first;
      }
      return day;
    }).toList();
    await StorageService.setString(_kSchedule, jsonEncode(result));
  }

  /// Chuyển kế hoạch (PlanDay) thành danh sách buổi tập đã lên lịch trong tuần.
  static Future<List<Map<String, dynamic>>> generateSchedule(
    List<PlanDay> planDays, {
    DateTime? start,
  }) async {
    final now = AppClock.day(start ?? AppClock.now());
    final previous = loadSchedule();
    final archiveRaw = StorageService.getString('fit_schedule_archive');
    final archive = <String, Map<String, dynamic>>{};
    if (archiveRaw != null) {
      try {
        for (final item in jsonDecode(archiveRaw) as List) {
          final row = Map<String, dynamic>.from(item as Map);
          archive[row['id'] as String] = row;
        }
      } catch (_) {}
    }
    for (final item in previous) {
      final date = DateTime.tryParse(item['date'] as String? ?? '');
      if (date != null && AppClock.day(date).isBefore(now)) {
        archive[item['id'] as String] = item;
      }
    }
    await StorageService.setString(
      'fit_schedule_archive',
      jsonEncode(archive.values.toList()),
    );
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
        'exercises': pd.exercises
            .map(
              (e) => {
                'exerciseName': e.exercise.name,
                'sets': e.sets,
                'reps': e.reps,
                'weight': e.weight,
              },
            )
            .toList(),
      });
      dayIdx++;
    }

    await StorageService.setString(_kSchedule, jsonEncode(schedule));
    return schedule;
  }

  /// Đọc lịch tập đã lưu (bắt lỗi JSON hỏng/trống).
  static List<Map<String, dynamic>> loadSchedule() {
    final s = StorageService.getString(_kSchedule);
    if (s == null || s.isEmpty) return [];
    try {
      final decoded = jsonDecode(s);
      if (decoded is! List) return [];
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Cập nhật trạng thái một buổi tập.
  static Future<void> setStatus(String id, String status) async {
    final list = loadSchedule();
    final idx = list.indexWhere((e) => e['id'] == id);
    if (idx >= 0) {
      final date = DateTime.tryParse(list[idx]['date'] as String? ?? '');
      if (date != null && AppClock.day(date).isBefore(AppClock.today)) {
        throw StateError('Ngày đã qua chỉ được xem.');
      }
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
  static int completedCount() =>
      loadSchedule().where((e) => e['status'] == 'completed').length;

  /// Tổng buổi có kế hoạch (không tính ngày nghỉ).
  static int plannedCount() =>
      loadSchedule().where((e) => e['isRest'] != true).length;
}
