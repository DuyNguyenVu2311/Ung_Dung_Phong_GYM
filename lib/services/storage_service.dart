import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/data_models.dart';
import 'app_clock.dart';

class StorageService {
  StorageService._internal();
  static final StorageService instance = StorageService._internal();

  static SharedPreferences? _prefs;
  int _userGeneration = 0;
  static Map<String, Map<String, int>>? _syncPendingCache;
  Future<void>? _writeTail;

  Future<T> _serializeWrites<T>(Future<T> Function() write) {
    final previous = _writeTail;
    final completed = Completer<void>();
    _writeTail = completed.future;
    return () async {
      if (previous != null) await previous;
      try {
        return await write();
      } finally {
        completed.complete();
      }
    }();
  }

  String? get activeUserId => _prefs?.getString('active_user');

  bool isBoundToUser(String userId) => activeUserId == userId;

  Future<void> bindUser(String userId) => _serializeWrites(() async {
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
    _syncPendingCache = _readPendingSyncChanges();
  });

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _syncPendingCache = _readPendingSyncChanges();
    _writeTail = null;
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
  static const _kWorkoutMinutes = 'fit_workout_minutes';
  static const _kThemeMode = 'fit_theme_mode';
  static const _kLanguage = 'fit_language';
  static const _kSyncPending = 'fit_sync_pending';
  static const _kSyncRevisionCounter = 'fit_sync_revision';
  static const _kSyncJournalInitialized = 'fit_sync_journal_initialized';

  static const syncProfile = 'profile';
  static const syncCheckIns = 'check_ins';
  static const syncMeasurements = 'measurements';
  static const syncFavorites = 'favorites';
  static const syncSessions = 'sessions';

  Map<String, Map<String, int>> get pendingSyncChanges {
    final pending = _syncPendingCache ?? _readPendingSyncChanges();
    return {
      for (final entry in pending.entries)
        entry.key: Map<String, int>.from(entry.value),
    };
  }

  Map<String, Map<String, int>> _readPendingSyncChanges() {
    final encoded = _prefs?.getString(_kSyncPending);
    if (encoded == null) return {};
    final decoded = jsonDecode(encoded) as Map<String, dynamic>;
    return {
      for (final entry in decoded.entries)
        entry.key: {
          for (final change in (entry.value as Map<String, dynamic>).entries)
            change.key: (change.value as num).toInt(),
        },
    };
  }

  bool get hasPendingSyncChanges =>
      pendingSyncChanges.values.any((changes) => changes.isNotEmpty);

  Future<void> _markSyncPending(String domain, String id) async {
    final prefs = _prefs;
    if (prefs == null) return;
    final pending = pendingSyncChanges;
    var revision = prefs.getInt(_kSyncRevisionCounter) ?? 0;
    for (final changes in pending.values) {
      for (final current in changes.values) {
        if (current > revision) revision = current;
      }
    }
    revision++;
    pending.putIfAbsent(domain, () => {})[id] = revision;
    _syncPendingCache = pending;
    await prefs.setInt(_kSyncRevisionCounter, revision);
    await prefs.setString(_kSyncPending, jsonEncode(pending));
  }

  Future<void> acknowledgeSyncChange(
    String domain,
    String id,
    int revision, {
    String? userId,
  }) => _serializeWrites(() async {
    if (userId != null && activeUserId != userId) return;
    final pending = pendingSyncChanges;
    if (pending[domain]?[id] != revision) return;
    pending[domain]!.remove(id);
    if (pending[domain]!.isEmpty) pending.remove(domain);
    _syncPendingCache = pending;
    await _prefs?.setString(_kSyncPending, jsonEncode(pending));
  });

  Future<void> ensureSyncJournalInitialized() => _serializeWrites(() async {
    final prefs = _prefs;
    if (prefs == null || prefs.getBool(_kSyncJournalInitialized) == true) {
      return;
    }

    final profile = loadProfile();
    if (profile != null) await _markSyncPending(syncProfile, 'profile');
    for (final checkIn in loadDailyCheckIns()) {
      await _markSyncPending(syncCheckIns, _checkInKey(checkIn.date));
    }
    for (final measurement in loadBodyMeasurements()) {
      await _markSyncPending(syncMeasurements, measurement.id);
    }
    for (final favorite in loadFavoriteExerciseIds()) {
      await _markSyncPending(syncFavorites, favorite);
    }
    for (final session in loadWorkoutSessions()) {
      await _markSyncPending(syncSessions, session.id);
    }
    await prefs.setBool(_kSyncJournalInitialized, true);
  });

  Future<void> restoreCloudSnapshot({
    required String userId,
    required UserProfile profile,
    required int workoutMinutes,
    required List<DailyCheckIn> checkIns,
    required List<BodyMeasurement> measurements,
    required Set<String> favoriteIds,
    required List<WorkoutSession> sessions,
  }) => _serializeWrites(() async {
    if (activeUserId != userId) {
      throw StateError('Tài khoản đã thay đổi trong khi đồng bộ');
    }

    final pending = pendingSyncChanges;
    if (pending[syncProfile]?.containsKey('profile') != true) {
      await _prefs?.setString(_kProfile, profile.toJsonString());
      await _prefs?.setString(_kGoal, profile.goal);
      await _prefs?.setString(_kLevel, profile.experienceLevel);
      await _prefs?.setInt(_kSessionsPerWeek, profile.sessionsPerWeek);
      await _prefs?.setString(
        _kWorkoutMinutes,
        '${workoutMinutes.clamp(15, 120)}',
      );
    }

    final mergedCheckIns = {
      for (final item in loadDailyCheckIns()) _checkInKey(item.date): item,
    };
    final pendingCheckIns = pending[syncCheckIns] ?? {};
    for (final item in checkIns) {
      final key = _checkInKey(item.date);
      if (!pendingCheckIns.containsKey(key)) mergedCheckIns[key] = item;
    }
    final checkInValues = mergedCheckIns.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    await _saveDailyCheckIns(checkInValues, fromCloud: true);
    if (checkInValues.isEmpty) {
      await _prefs?.remove(_kDailyCheckIn);
    } else {
      await _prefs?.setString(
        _kDailyCheckIn,
        jsonEncode(checkInValues.first.toJson()),
      );
    }

    final mergedMeasurements = {
      for (final item in loadBodyMeasurements()) item.id: item,
    };
    final pendingMeasurements = pending[syncMeasurements] ?? {};
    for (final item in measurements) {
      if (!pendingMeasurements.containsKey(item.id)) {
        mergedMeasurements[item.id] = item;
      }
    }
    await _saveBodyMeasurements(
      mergedMeasurements.values.toList(),
      fromCloud: true,
    );

    final mergedFavorites = Set<String>.from(favoriteIds);
    final localFavorites = loadFavoriteExerciseIds();
    for (final id in (pending[syncFavorites] ?? {}).keys) {
      if (localFavorites.contains(id)) {
        mergedFavorites.add(id);
      } else {
        mergedFavorites.remove(id);
      }
    }
    await _saveFavoriteExerciseIds(mergedFavorites, fromCloud: true);

    final mergedSessions = {
      for (final item in loadWorkoutSessions()) item.id: item,
    };
    final pendingSessions = pending[syncSessions] ?? {};
    for (final item in sessions) {
      if (!pendingSessions.containsKey(item.id)) {
        mergedSessions[item.id] = item;
      }
    }
    await _saveWorkoutSessions(mergedSessions.values.toList(), fromCloud: true);
  });

  static String _checkInKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static Future<void> setString(String key, String value) async {
    await _prefs?.setString(key, value);
  }

  static String? getString(String key) {
    return _prefs?.getString(key);
  }

  Future<void> saveProfile(UserProfile profile, {bool fromCloud = false}) =>
      _serializeWrites(() async {
        await _prefs?.setString(_kProfile, profile.toJsonString());
        if (!fromCloud) await _markSyncPending(syncProfile, 'profile');
      });

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

  int loadWorkoutMinutes() =>
      int.tryParse(_prefs?.getString(_kWorkoutMinutes) ?? '') ?? 60;

  Future<void> saveWorkoutMinutes(int minutes, {bool fromCloud = false}) =>
      _serializeWrites(() async {
        final boundedMinutes = minutes.clamp(15, 120);
        await _prefs?.setString(_kWorkoutMinutes, '$boundedMinutes');
        if (!fromCloud && loadProfile() != null) {
          await _markSyncPending(syncProfile, 'profile');
        }
      });

  Future<void> saveWorkoutSessions(
    List<WorkoutSession> sessions, {
    bool fromCloud = false,
  }) => _serializeWrites(() async {
    await _saveWorkoutSessions(sessions, fromCloud: fromCloud);
  });

  Future<void> _saveWorkoutSessions(
    List<WorkoutSession> sessions, {
    bool fromCloud = false,
  }) async {
    final oldSessions = {
      for (final session in loadWorkoutSessions()) session.id: session,
    };
    final list = sessions.map((s) => s.toJsonString()).toList();
    await _prefs?.setStringList(_kWorkoutSessions, list);
    if (!fromCloud) {
      for (final session in sessions) {
        if (oldSessions[session.id]?.toJsonString() != session.toJsonString()) {
          await _markSyncPending(syncSessions, session.id);
        }
      }
    }
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

  Future<void> addWorkoutSession(WorkoutSession session) =>
      _serializeWrites(() async {
        final current = loadWorkoutSessions();
        current.removeWhere((item) => item.id == session.id);
        current.add(session);
        await _saveWorkoutSessions(current);
      });

  Future<void> saveDailyCheckIn(
    DailyCheckIn checkIn, {
    bool fromCloud = false,
  }) => _serializeWrites(() async {
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
    await _saveDailyCheckIns(all, fromCloud: fromCloud);
  });

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

  Future<void> saveDailyCheckIns(
    List<DailyCheckIn> values, {
    bool fromCloud = false,
  }) =>
      _serializeWrites(() => _saveDailyCheckIns(values, fromCloud: fromCloud));

  Future<void> _saveDailyCheckIns(
    List<DailyCheckIn> values, {
    bool fromCloud = false,
  }) async {
    final oldCheckIns = {
      for (final checkIn in loadDailyCheckIns())
        _checkInKey(checkIn.date): checkIn,
    };
    await _prefs?.setStringList(
      _kDailyCheckIns,
      values.map((item) => jsonEncode(item.toJson())).toList(),
    );
    if (!fromCloud) {
      for (final checkIn in values) {
        final key = _checkInKey(checkIn.date);
        if (jsonEncode(oldCheckIns[key]?.toJson()) !=
            jsonEncode(checkIn.toJson())) {
          await _markSyncPending(syncCheckIns, key);
        }
      }
    }
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

  Future<void> addBodyMeasurement(BodyMeasurement measurement) =>
      _serializeWrites(() async {
        final measurements = loadBodyMeasurements()..add(measurement);
        await _prefs?.setStringList(
          _kBodyMeasurements,
          measurements.map((item) => jsonEncode(item.toJson())).toList(),
        );
        await _markSyncPending(syncMeasurements, measurement.id);
      });

  Future<void> saveBodyMeasurements(
    List<BodyMeasurement> measurements, {
    bool fromCloud = false,
  }) => _serializeWrites(
    () => _saveBodyMeasurements(measurements, fromCloud: fromCloud),
  );

  Future<void> _saveBodyMeasurements(
    List<BodyMeasurement> measurements, {
    bool fromCloud = false,
  }) async {
    final oldMeasurements = {
      for (final item in loadBodyMeasurements()) item.id: item,
    };
    await _prefs?.setStringList(
      _kBodyMeasurements,
      measurements.map((item) => jsonEncode(item.toJson())).toList(),
    );
    if (!fromCloud) {
      for (final item in measurements) {
        if (jsonEncode(oldMeasurements[item.id]?.toJson()) !=
            jsonEncode(item.toJson())) {
          await _markSyncPending(syncMeasurements, item.id);
        }
      }
    }
  }

  Set<String> loadFavoriteExerciseIds() =>
      (_prefs?.getStringList(_kFavoriteExercises) ?? []).toSet();

  Future<void> saveFavoriteExerciseIds(
    Set<String> ids, {
    bool fromCloud = false,
  }) => _serializeWrites(
    () => _saveFavoriteExerciseIds(ids, fromCloud: fromCloud),
  );

  Future<void> _saveFavoriteExerciseIds(
    Set<String> ids, {
    bool fromCloud = false,
  }) async {
    final oldIds = loadFavoriteExerciseIds();
    await _prefs?.setStringList(_kFavoriteExercises, ids.toList());
    if (!fromCloud) {
      for (final id in oldIds.difference(ids).union(ids.difference(oldIds))) {
        await _markSyncPending(syncFavorites, id);
      }
    }
  }

  Future<bool> toggleFavoriteExercise(String exerciseId) =>
      _serializeWrites(() async {
        final ids = loadFavoriteExerciseIds();
        final isFavorite = ids.contains(exerciseId);
        isFavorite ? ids.remove(exerciseId) : ids.add(exerciseId);
        await _saveFavoriteExerciseIds(ids);
        return !isFavorite;
      });

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

  Future<void> clearAll() => _serializeWrites(() async {
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
    _syncPendingCache = {};
  });
}
