import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/data_models.dart';
import 'app_clock.dart';

class StorageService {
  StorageService._internal();
  static final StorageService instance = StorageService._internal();

  static SharedPreferences? _prefs;
  int _userGeneration = 0;

  Future<void> bindUser(String userId) async {
    final prefs = _prefs;
    if (prefs == null || prefs.getString('active_user') == userId) return;
    _userGeneration++;
    final previous = prefs.getString('active_user') ?? 'legacy';
    final keys = prefs
        .getKeys()
        .where(
          (key) =>
              key.startsWith('fit_') && key != _kThemeMode && key != _kLanguage,
        )
        .toList();
    final snapshot = <String, dynamic>{};
    for (final key in keys) {
      snapshot[key] = prefs.get(key);
      await prefs.remove(key);
    }
    await prefs.setString('account_cache_$previous', jsonEncode(snapshot));
    final saved = prefs.getString('account_cache_$userId');
    if (saved != null) {
      final values = jsonDecode(saved) as Map<String, dynamic>;
      for (final entry in values.entries) {
        final value = entry.value;
        if (value is String) await prefs.setString(entry.key, value);
        if (value is int) await prefs.setInt(entry.key, value);
        if (value is double) await prefs.setDouble(entry.key, value);
        if (value is bool) await prefs.setBool(entry.key, value);
        if (value is List) {
          await prefs.setStringList(entry.key, value.cast<String>());
        }
      }
    }
    await prefs.setString('active_user', userId);
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static const _kProfile = 'fit_profile';
  static const _kGoal = 'fit_goal';
  static const _kLevel = 'fit_level';
  static const _kSessionsPerWeek = 'fit_sessions';
  static const _kWorkoutSessions = 'fit_workout_sessions';
  static const _kDailyCheckIn = 'fit_daily_check_in';
  static const _kDailyCheckIns = 'fit_daily_check_ins';
  static const _kBodyMeasurements = 'fit_body_measurements';
  static const _kFavoriteExercises = 'fit_favorite_exercises';
  static const _kMembership = 'fit_membership';
  static const _kNotices = 'fit_notices';
  static const _kThemeMode = 'fit_theme_mode';
  static const _kLanguage = 'fit_language';

  static Future<void> setString(String key, String value) async {
    await _prefs?.setString(key, value);
  }

  static String? getString(String key) {
    return _prefs?.getString(key);
  }

  Future<void> saveProfile(UserProfile profile) async {
    await _prefs?.setString(_kProfile, profile.toJsonString());
  }

  UserProfile? loadProfile() {
    final s = _prefs?.getString(_kProfile);
    if (s == null) return null;
    try {
      return UserProfile.fromJsonString(s);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveGoal(String goal) async {
    await _prefs?.setString(_kGoal, goal);
  }

  String? loadGoal() {
    return _prefs?.getString(_kGoal);
  }

  Future<void> saveLevel(String level) async {
    await _prefs?.setString(_kLevel, level);
  }

  String? loadLevel() {
    return _prefs?.getString(_kLevel);
  }

  Future<void> saveSessionsPerWeek(int sessions) async {
    await _prefs?.setInt(_kSessionsPerWeek, sessions);
  }

  int? loadSessionsPerWeek() {
    return _prefs?.getInt(_kSessionsPerWeek);
  }

  Future<void> saveWorkoutSessions(List<WorkoutSession> sessions) async {
    final list = sessions.map((s) => s.toJsonString()).toList();
    await _prefs?.setStringList(_kWorkoutSessions, list);
  }

  List<WorkoutSession> loadWorkoutSessions() {
    final list = _prefs?.getStringList(_kWorkoutSessions) ?? [];
    final result = <WorkoutSession>[];
    for (final e in list) {
      try {
        result.add(WorkoutSession.fromJsonString(e));
      } catch (_) {
        // Bỏ qua hoặc tự phục hồi nếu gặp chuỗi JSON bị lỗi trước đó
      }
    }
    return result;
  }

  Future<void> addWorkoutSession(WorkoutSession session) async {
    final current = loadWorkoutSessions();
    current.removeWhere((item) => item.id == session.id);
    current.add(session);
    await saveWorkoutSessions(current);
  } // Thay đổi này bảo đảm mỗi ID chỉ có một buổi tập. Nếu lưu lại cùng ID, bản mới thay thế bản cũ; đồng thời loại các bản trùng ID đó nếu đã có.

  Future<void> saveDailyCheckIn(DailyCheckIn checkIn) async {
    await _prefs?.setString(_kDailyCheckIn, jsonEncode(checkIn.toJson()));
    final all = loadDailyCheckIns();
    final index = all.indexWhere(
      (item) =>
          item.date.year == checkIn.date.year &&
          item.date.month == checkIn.date.month &&
          item.date.day == checkIn.date.day,
    );
    if (index >= 0) {
      all[index] = checkIn;
    } else {
      all.add(checkIn);
    }
    all.sort((a, b) => b.date.compareTo(a.date));
    await saveDailyCheckIns(all);
  }

  DailyCheckIn? loadTodayCheckIn() {
    final history = loadDailyCheckIns();
    final now = AppClock.now();
    for (final item in history) {
      if (item.date.year == now.year &&
          item.date.month == now.month &&
          item.date.day == now.day) {
        return item;
      }
    }
    final value = _prefs?.getString(_kDailyCheckIn);
    if (value == null) return null;
    try {
      final checkIn = DailyCheckIn.fromJson(
        jsonDecode(value) as Map<String, dynamic>,
      );
      final now = AppClock.now();
      if (checkIn.date.year != now.year ||
          checkIn.date.month != now.month ||
          checkIn.date.day != now.day) {
        return null;
      }
      return checkIn;
    } catch (_) {
      return null;
    }
  }

  List<DailyCheckIn> loadDailyCheckIns() {
    final values = _prefs?.getStringList(_kDailyCheckIns) ?? [];
    final result = <DailyCheckIn>[];
    for (final value in values) {
      try {
        result.add(
          DailyCheckIn.fromJson(jsonDecode(value) as Map<String, dynamic>),
        );
      } catch (_) {}
    }
    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  Future<void> saveDailyCheckIns(List<DailyCheckIn> values) async {
    await _prefs?.setStringList(
      _kDailyCheckIns,
      values.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }

  List<BodyMeasurement> loadBodyMeasurements() {
    final values = _prefs?.getStringList(_kBodyMeasurements) ?? [];
    final measurements = <BodyMeasurement>[];
    for (final value in values) {
      try {
        measurements.add(
          BodyMeasurement.fromJson(jsonDecode(value) as Map<String, dynamic>),
        );
      } catch (_) {
        // Bỏ qua bản ghi hỏng để phần còn lại vẫn hiển thị được.
      }
    }
    measurements.sort((a, b) => a.date.compareTo(b.date));
    return measurements;
  }

  Future<void> addBodyMeasurement(BodyMeasurement measurement) async {
    final measurements = loadBodyMeasurements()..add(measurement);
    await _prefs?.setStringList(
      _kBodyMeasurements,
      measurements.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }

  Future<void> saveBodyMeasurements(List<BodyMeasurement> measurements) async {
    await _prefs?.setStringList(
      _kBodyMeasurements,
      measurements.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }

  Set<String> loadFavoriteExerciseIds() =>
      (_prefs?.getStringList(_kFavoriteExercises) ?? []).toSet();

  Future<void> saveFavoriteExerciseIds(Set<String> ids) async {
    await _prefs?.setStringList(_kFavoriteExercises, ids.toList());
  }

  Future<bool> toggleFavoriteExercise(String exerciseId) async {
    final ids = loadFavoriteExerciseIds();
    final isFavorite = ids.contains(exerciseId);
    isFavorite ? ids.remove(exerciseId) : ids.add(exerciseId);
    await _prefs?.setStringList(_kFavoriteExercises, ids.toList());
    return !isFavorite;
  }

  MembershipPlan loadMembership() {
    final value = _prefs?.getString(_kMembership);
    if (value != null) {
      try {
        return MembershipPlan.fromJson(
          jsonDecode(value) as Map<String, dynamic>,
        );
      } catch (_) {}
    }
    return MembershipPlan(
      id: '',
      name: '',
      branchName: '',
      startDate: DateTime(1970),
      endDate: DateTime(1970),
      usedSessions: 0,
      totalSessions: 0,
      price: 0,
      active: false,
    );
  }

  Future<void> saveMembership(MembershipPlan value) async {
    await _prefs?.setString(_kMembership, jsonEncode(value.toJson()));
  }

  /// Only a successful query may replace/clear membership cache. A thrown
  /// request leaves it intact; late results cannot cross account boundaries.
  Future<Map<String, dynamic>?> refreshMembership(
    Future<List<Map<String, dynamic>>> Function() fetch, {
    required String userId,
  }) async {
    final generation = _userGeneration;
    final rows = await fetch();
    bool sameAccount() =>
        generation == _userGeneration &&
        _prefs?.getString('active_user') == userId;
    if (!sameAccount()) return null;
    Map<String, dynamic>? selected;
    MembershipPlan? plan;
    for (final row in rows) {
      final candidate = MembershipPlan(
        id: row['id'] as String,
        name: row['name'] as String,
        branchName: row['branch_name'] as String,
        startDate: DateTime.parse(row['start_date'] as String),
        endDate: DateTime.parse(row['end_date'] as String),
        usedSessions: (row['used_sessions'] as num).toInt(),
        totalSessions: (row['total_sessions'] as num).toInt(),
        price: (row['price'] as num).toInt(),
        active: row['active'] == true,
      );
      if (candidate.isCurrent) {
        selected = row;
        plan = candidate;
        break;
      }
    }
    if (plan == null) {
      await _prefs?.remove(_kMembership);
    } else {
      await saveMembership(plan);
    }
    if (sameAccount()) {
      final notices = loadNotices();
      final retained = notices
          .where(
            (notice) =>
                notice.type != 'expiry' ||
                (plan != null && notice.id == 'expiry_${plan.id}'),
          )
          .toList();
      if (retained.length != notices.length) await saveNotices(retained);
    }
    return selected;
  }

  List<AppNotice> loadNotices() {
    final values = _prefs?.getStringList(_kNotices) ?? [];
    final notices = <AppNotice>[];
    for (final value in values) {
      try {
        notices.add(AppNotice.fromJson(jsonDecode(value)));
      } catch (_) {}
    }
    notices.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return notices;
  }

  Future<void> saveNotices(List<AppNotice> notices) async {
    await _prefs?.setStringList(
      _kNotices,
      notices.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }

  Future<void> addNotice(AppNotice notice) async {
    final notices = loadNotices()..add(notice);
    await saveNotices(notices);
  }

  Future<void> ensureMembershipNotices() async {
    final membership = loadMembership();
    if (!membership.isCurrent) return;
    final notices = loadNotices();
    if (membership.remainingDays <= 7 &&
        !notices.any((item) => item.type == 'expiry')) {
      await addNotice(
        AppNotice(
          id: 'expiry_${membership.id}',
          title: 'Gói tập sắp hết hạn',
          message:
              'Gói ${membership.name} còn ${membership.remainingDays} ngày. Bạn có thể gửi yêu cầu gia hạn ngay trong ứng dụng.',
          createdAt: DateTime.now(),
          type: 'expiry',
        ),
      );
    }
  }

  String loadThemeMode() => _prefs?.getString(_kThemeMode) ?? 'dark';
  Future<void> saveThemeMode(String value) async =>
      _prefs?.setString(_kThemeMode, value);

  String loadLanguage() => _prefs?.getString(_kLanguage) ?? 'vi';
  Future<void> saveLanguage(String value) async =>
      _prefs?.setString(_kLanguage, value);

  Future<void> clearAll() async {
    final prefs = _prefs;
    if (prefs == null) return;
    final userId = prefs.getString('active_user');
    for (final key
        in prefs
            .getKeys()
            .where(
              (key) =>
                  key.startsWith('fit_') &&
                  key != _kThemeMode &&
                  key != _kLanguage,
            )
            .toList()) {
      await prefs.remove(key);
    }
    if (userId != null) await prefs.remove('account_cache_$userId');
    await prefs.remove('active_user');
  }
}
