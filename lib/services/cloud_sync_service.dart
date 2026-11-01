import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/data_models.dart';
import '../repositories/workout_schedule_repository.dart';
import 'sync_request_coordinator.dart';
import 'storage_service.dart';
import 'supabase_service.dart';

class CloudSyncService {
  CloudSyncService._();

  static final instance = CloudSyncService._();
  static const _pageSize = 500;
  final SyncRequestCoordinator _syncRequests = SyncRequestCoordinator();

  final ValueNotifier<bool> syncing = ValueNotifier(false);
  DateTime? lastSyncAt;
  String? lastError;
  Future<bool>? _restoreTask;

  bool get canSync => SupabaseService.currentUser != null;

  Future<bool> restoreOrUpload() {
    final activeRestore = _restoreTask;
    if (activeRestore != null) return activeRestore;
    final task = _restoreAfterCurrentSync();
    _restoreTask = task;
    return task.whenComplete(() {
      if (identical(_restoreTask, task)) _restoreTask = null;
    });
  }

  Future<bool> _restoreAfterCurrentSync() async {
    if (syncing.value && !await _syncRequests.run(_syncPass)) return false;
    return _restoreAndUpload();
  }

  Future<bool> _restoreAndUpload() async {
    final client = SupabaseService.client;
    final user = SupabaseService.currentUser;
    if (client == null || user == null) return false;
    try {
      final storage = StorageService.instance;
      _assertCurrentUser(user.id, storage);
      await storage.ensureSyncJournalInitialized();
      final profile = await client
          .from('profiles')
          .select('user_id')
          .eq('user_id', user.id)
          .maybeSingle();
      _assertCurrentUser(user.id, storage);
      if (profile == null) {
        await _syncRequests.run(_syncPass);
        return true;
      }
      if (!await _restoreFromCloud(user.id)) return false;
      await _syncRequests.run(_syncPass);
      return true;
    } catch (error) {
      lastError = error.toString();
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchRows({
    required SupabaseClient client,
    required StorageService storage,
    required String userId,
    required String table,
    required String orderBy,
    String columns = '*',
  }) async {
    final rows = <Map<String, dynamic>>[];
    var offset = 0;
    while (true) {
      final page = await client
          .from(table)
          .select(columns)
          .eq('user_id', userId)
          .order(orderBy)
          .order(orderBy == 'exercise_id' ? 'exercise_id' : 'id')
          .range(offset, offset + _pageSize - 1);
      _assertCurrentUser(userId, storage);
      rows.addAll(page);
      if (page.length < _pageSize) return rows;
      offset += _pageSize;
    }
  }

  void _assertCurrentUser(String userId, StorageService storage) {
    if (SupabaseService.currentUser?.id != userId ||
        !storage.isBoundToUser(userId)) {
      throw StateError('Tài khoản đã thay đổi trong khi đồng bộ');
    }
  }

  String _checkInKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Future<bool> _restoreFromCloud(String userId) async {
    final client = SupabaseService.client;
    final storage = StorageService.instance;
    if (client == null || syncing.value) return false;
    syncing.value = true;
    lastError = null;
    try {
      _assertCurrentUser(userId, storage);
      final profileJson = await client
          .from('profiles')
          .select()
          .eq('user_id', userId)
          .single();
      _assertCurrentUser(userId, storage);

      final checkInRows = await _fetchRows(
        client: client,
        storage: storage,
        userId: userId,
        table: 'daily_check_ins',
        orderBy: 'check_in_date',
      );
      final measurementRows = await _fetchRows(
        client: client,
        storage: storage,
        userId: userId,
        table: 'body_measurements',
        orderBy: 'measured_at',
      );
      final favoriteRows = await _fetchRows(
        client: client,
        storage: storage,
        userId: userId,
        table: 'favorite_exercises',
        orderBy: 'exercise_id',
        columns: 'exercise_id',
      );
      final sessionRows = await _fetchRows(
        client: client,
        storage: storage,
        userId: userId,
        table: 'workout_sessions',
        orderBy: 'performed_at',
        columns: 'id,client_session_id,day_name,performed_at,branch_name,check_in_at,exercise_logs(exercise_name,sets,reps,weight_kg,rpe,is_personal_record)',
      );
      final membershipRows = await client
          .from('memberships')
          .select()
          .eq('user_id', userId)
          .eq('active', true)
          .order('end_date', ascending: false)
          .limit(1);
      _assertCurrentUser(userId, storage);
      final noticeRows = await _fetchRows(
        client: client,
        storage: storage,
        userId: userId,
        table: 'app_notifications',
        orderBy: 'created_at',
      );
      _assertCurrentUser(userId, storage);

      final profile = UserProfile(
        name: profileJson['name'] as String? ?? '',
        age: (profileJson['age'] as num?)?.toInt() ?? 22,
        height: (profileJson['height_cm'] as num?)?.toDouble() ?? 170,
        weight: (profileJson['weight_kg'] as num?)?.toDouble() ?? 65,
        gender: profileJson['gender'] as String? ?? 'Nam',
        goal: profileJson['goal'] as String? ?? 'maintenance',
        experienceLevel:
            profileJson['experience_level'] as String? ?? 'beginner',
        sessionsPerWeek:
            (profileJson['sessions_per_week'] as num?)?.toInt() ?? 3,
        occupation: profileJson['occupation'] as String? ?? '',
        activityLevel: profileJson['activity_level'] as String? ?? 'moderate',
        availableWeekdays:
            (profileJson['available_weekdays'] as List?)
                ?.map((item) => (item as num).toInt())
                .toList() ??
            const [1, 3, 5],
        preferredWorkoutTime:
            profileJson['preferred_workout_time'] as String? ?? 'evening',
        dietaryPreference:
            profileJson['dietary_preference'] as String? ?? 'balanced',
        healthNotes: profileJson['health_notes'] as String? ?? '',
      );

      final remoteCheckIns = checkInRows
          .map(
            (item) => DailyCheckIn(
              date: DateTime.parse(item['check_in_date'] as String),
              energy: (item['energy'] as num).toInt(),
              soreness: (item['soreness'] as num).toInt(),
              sleepQuality: (item['sleep_quality'] as num).toInt(),
              availableMinutes: (item['available_minutes'] as num).toInt(),
            ),
          )
          .toList();

      final remoteMeasurements = measurementRows
          .map(
            (item) => BodyMeasurement(
              id: item['client_id'] as String,
              date: DateTime.parse(item['measured_at'] as String),
              weight: (item['weight_kg'] as num).toDouble(),
            ),
          )
          .toList();
      final remoteFavorites = favoriteRows
          .map((item) => item['exercise_id'] as String)
          .toSet();
      final remoteSessions = sessionRows.map(_sessionFromCloud).toList();
      await storage.restoreCloudSnapshot(
        userId: userId,
        profile: profile,
        workoutMinutes: (profileJson['workout_minutes'] as num?)?.toInt() ?? 60,
        checkIns: remoteCheckIns,
        measurements: remoteMeasurements,
        favoriteIds: remoteFavorites,
        sessions: remoteSessions,
      );
      _assertCurrentUser(userId, storage);
      await WorkoutScheduleRepository.ensureCurrentWeek();

      await storage.saveNotices(
        noticeRows
            .map(
              (item) => AppNotice(
                id: item['id'] as String,
                title: item['title'] as String,
                message: item['message'] as String,
                createdAt: DateTime.parse(item['created_at'] as String),
                type: item['notice_type'] as String? ?? 'system',
                read: item['is_read'] as bool? ?? false,
              ),
            )
            .toList(),
      );
      _assertCurrentUser(userId, storage);
      // Reuse the successfully fetched rows and clean stale expiry notices
      // after restoring notifications, so the restore cannot re-add them.
      await storage.refreshMembership(
        () async => membershipRows,
        userId: userId,
      );
      _assertCurrentUser(userId, storage);
      lastSyncAt = DateTime.now();
      return lastError == null;
    } catch (error) {
      lastError = error.toString();
      return false;
    } finally {
      syncing.value = false;
    }
  }

  bool _isMissingWorkoutMinutesColumn(PostgrestException error) =>
      error.code == 'PGRST204' &&
      error.message.contains('workout_minutes') &&
      error.message.contains('profiles');

  WorkoutSession _sessionFromCloud(Map<String, dynamic> item) {
    final localId =
        item['client_session_id'] as String? ?? item['id'] as String;
    final logs = (item['exercise_logs'] as List<dynamic>? ?? [])
        .map(
          (raw) => ExerciseLog(
            id: '${localId}_${raw.hashCode}',
            sessionId: localId,
            exerciseName: raw['exercise_name'] as String? ?? '',
            sets: (raw['sets'] as num?)?.toInt() ?? 0,
            reps: (raw['reps'] as num?)?.toInt() ?? 0,
            weight: (raw['weight_kg'] as num?)?.toDouble() ?? 0,
            rpe: (raw['rpe'] as num?)?.toInt() ?? 7,
            isPersonalRecord: raw['is_personal_record'] as bool? ?? false,
          ),
        )
        .toList();
    return WorkoutSession(
      id: localId,
      dayName: item['day_name'] as String? ?? '',
      date: DateTime.parse(item['performed_at'] as String),
      logs: logs,
      branchName: item['branch_name'] as String? ?? 'FitPlan Center',
      checkedInAt: item['check_in_at'] == null
          ? null
          : DateTime.tryParse(item['check_in_at'] as String),
    );
  }

  Future<bool> syncNow() {
    final activeRestore = _restoreTask;
    if (activeRestore != null) return activeRestore;
    return _syncRequests.run(_syncPass);
  }

  Future<bool> _syncPass() async {
    final client = SupabaseService.client;
    final user = SupabaseService.currentUser;
    final storage = StorageService.instance;
    if (client == null || user == null || syncing.value) return false;
    syncing.value = true;
    lastError = null;
    try {
      _assertCurrentUser(user.id, storage);
      await storage.ensureSyncJournalInitialized();
      final pending = storage.pendingSyncChanges;
      final profileRevision = pending[StorageService.syncProfile]?['profile'];
      final checkInRevisions =
          pending[StorageService.syncCheckIns] ?? const <String, int>{};
      final measurementRevisions =
          pending[StorageService.syncMeasurements] ?? const <String, int>{};
      final favoriteRevisions =
          pending[StorageService.syncFavorites] ?? const <String, int>{};
      final sessionRevisions =
          pending[StorageService.syncSessions] ?? const <String, int>{};

      final profile = profileRevision == null ? null : storage.loadProfile();
      final checkIns = {
        for (final item in storage.loadDailyCheckIns())
          _checkInKey(item.date): item,
      };
      final measurements = {
        for (final item in storage.loadBodyMeasurements()) item.id: item,
      };
      final favorites = storage.loadFavoriteExerciseIds();
      final sessions = {
        for (final item in storage.loadWorkoutSessions()) item.id: item,
      };

      if (profileRevision != null) {
        if (profile == null) {
          throw StateError('Hồ sơ chờ đồng bộ không tồn tại');
        }
        final profileValues = {
          'user_id': user.id,
          'name': profile.name,
          'age': profile.age,
          'height_cm': profile.height,
          'weight_kg': profile.weight,
          'gender': profile.gender,
          'goal': profile.goal,
          'experience_level': profile.experienceLevel == 'exp'
              ? 'intermediate'
              : profile.experienceLevel,
          'sessions_per_week': profile.sessionsPerWeek,
          'occupation': profile.occupation,
          'activity_level': profile.activityLevel,
          'available_weekdays': profile.availableWeekdays,
          'preferred_workout_time': profile.preferredWorkoutTime,
          'dietary_preference': profile.dietaryPreference,
          'health_notes': profile.healthNotes,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        };
        try {
          await client.from('profiles').upsert({
            ...profileValues,
            'workout_minutes': storage.loadWorkoutMinutes(),
          }, onConflict: 'user_id');
          await storage.acknowledgeSyncChange(
            StorageService.syncProfile,
            'profile',
            profileRevision,
            userId: user.id,
          );
        } on PostgrestException catch (error) {
          if (!_isMissingWorkoutMinutesColumn(error)) rethrow;
          await client
              .from('profiles')
              .upsert(profileValues, onConflict: 'user_id');
          lastError =
              'Hồ sơ đã đồng bộ, nhưng thời lượng tập chưa lên cloud. '
              'Chạy migration 20261101010000_workout_duration_sync.sql '
              'trong Supabase rồi đồng bộ lại.';
        }
        _assertCurrentUser(user.id, storage);
      }

      for (final entry in checkInRevisions.entries) {
        final checkIn = checkIns[entry.key];
        if (checkIn == null) {
          throw StateError('Check-in chờ đồng bộ không tồn tại: ${entry.key}');
        }
        await client.from('daily_check_ins').upsert({
          'user_id': user.id,
          'check_in_date': entry.key,
          'energy': checkIn.energy,
          'soreness': checkIn.soreness,
          'sleep_quality': checkIn.sleepQuality,
          'available_minutes': checkIn.availableMinutes,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'user_id,check_in_date');
        _assertCurrentUser(user.id, storage);
        await storage.acknowledgeSyncChange(
          StorageService.syncCheckIns,
          entry.key,
          entry.value,
          userId: user.id,
        );
      }

      for (final entry in measurementRevisions.entries) {
        final item = measurements[entry.key];
        if (item == null) {
          throw StateError('Số đo chờ đồng bộ không tồn tại: ${entry.key}');
        }
        await client.from('body_measurements').upsert({
          'user_id': user.id,
          'client_id': item.id,
          'measured_at': item.date.toUtc().toIso8601String(),
          'weight_kg': item.weight,
        }, onConflict: 'user_id,client_id');
        _assertCurrentUser(user.id, storage);
        await storage.acknowledgeSyncChange(
          StorageService.syncMeasurements,
          entry.key,
          entry.value,
          userId: user.id,
        );
      }

      for (final entry in favoriteRevisions.entries) {
        if (favorites.contains(entry.key)) {
          await client.from('favorite_exercises').upsert({
            'user_id': user.id,
            'exercise_id': entry.key,
          }, onConflict: 'user_id,exercise_id');
        } else {
          await client
              .from('favorite_exercises')
              .delete()
              .eq('user_id', user.id)
              .eq('exercise_id', entry.key);
        }
        _assertCurrentUser(user.id, storage);
        await storage.acknowledgeSyncChange(
          StorageService.syncFavorites,
          entry.key,
          entry.value,
          userId: user.id,
        );
      }

      for (final entry in sessionRevisions.entries) {
        final session = sessions[entry.key];
        if (session == null) {
          throw StateError('Buổi tập chờ đồng bộ không tồn tại: ${entry.key}');
        }
        await client.rpc(
          'sync_workout_session',
          params: {
            'p_client_session_id': session.id,
            'p_day_name': session.dayName,
            'p_performed_at': session.date.toUtc().toIso8601String(),
            'p_branch_name': session.branchName,
            'p_check_in_at': (session.checkedInAt ?? session.date)
                .toUtc()
                .toIso8601String(),
            'p_logs': session.logs
                .map(
                  (log) => {
                    'exercise_name': log.exerciseName,
                    'sets': log.sets,
                    'reps': log.reps,
                    'weight_kg': log.weight,
                    'rpe': log.rpe,
                    'is_personal_record': log.isPersonalRecord,
                  },
                )
                .toList(),
          },
        );
        _assertCurrentUser(user.id, storage);
        await storage.acknowledgeSyncChange(
          StorageService.syncSessions,
          entry.key,
          entry.value,
          userId: user.id,
        );
      }

      final notices = storage.loadNotices();
      if (notices.isNotEmpty) {
        await client
            .from('app_notifications')
            .upsert(
              notices
                  .map(
                    (notice) => {
                      'id': notice.id,
                      'user_id': user.id,
                      'title': notice.title,
                      'message': notice.message,
                      'notice_type': notice.type,
                      'is_read': notice.read,
                      'created_at': notice.createdAt.toUtc().toIso8601String(),
                    },
                  )
                  .toList(),
              onConflict: 'user_id,id',
            );
        _assertCurrentUser(user.id, storage);
      }

      lastSyncAt = DateTime.now();
      return true;
    } catch (error) {
      lastError = error.toString();
      return false;
    } finally {
      syncing.value = false;
    }
  }
}
