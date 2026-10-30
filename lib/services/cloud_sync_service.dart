import 'package:flutter/foundation.dart';

import '../models/data_models.dart';
import 'storage_service.dart';
import 'supabase_service.dart';

class CloudSyncService {
  CloudSyncService._();

  static final instance = CloudSyncService._();

  final ValueNotifier<bool> syncing = ValueNotifier(false);
  DateTime? lastSyncAt;
  String? lastError;

  bool get canSync => SupabaseService.currentUser != null;

  Future<bool> restoreOrUpload() async {
    final client = SupabaseService.client;
    final user = SupabaseService.currentUser;
    if (client == null || user == null) return false;
    try {
      final profile = await client
          .from('profiles')
          .select('user_id')
          .eq('user_id', user.id)
          .maybeSingle();
      if (profile == null) return await syncNow();
      return await _restoreFromCloud(user.id);
    } catch (error) {
      lastError = error.toString();
      return false;
    }
  }

  Future<bool> _restoreFromCloud(String userId) async {
    final client = SupabaseService.client!;
    if (syncing.value) return false;
    syncing.value = true;
    lastError = null;
    try {
      final storage = StorageService.instance;
      final profileJson = await client
          .from('profiles')
          .select()
          .eq('user_id', userId)
          .single();
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
      await storage.saveProfile(profile);
      await storage.saveGoal(profile.goal);
      await storage.saveLevel(profile.experienceLevel);
      await storage.saveSessionsPerWeek(profile.sessionsPerWeek);

      final checkIns = await client
          .from('daily_check_ins')
          .select()
          .eq('user_id', userId)
          .order('check_in_date', ascending: false);
      if (checkIns.isNotEmpty) {
        final restored = checkIns
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
        await storage.saveDailyCheckIns(restored);
        await storage.saveDailyCheckIn(restored.first);
      }

      final measurementRows = await client
          .from('body_measurements')
          .select()
          .eq('user_id', userId)
          .order('measured_at');
      await storage.saveBodyMeasurements(
        measurementRows
            .map(
              (item) => BodyMeasurement(
                id: item['client_id'] as String,
                date: DateTime.parse(item['measured_at'] as String),
                weight: (item['weight_kg'] as num).toDouble(),
              ),
            )
            .toList(),
      );

      final favoriteRows = await client
          .from('favorite_exercises')
          .select('exercise_id')
          .eq('user_id', userId);
      await storage.saveFavoriteExerciseIds(
        favoriteRows.map((item) => item['exercise_id'] as String).toSet(),
      );

      final sessionRows = await client
          .from('workout_sessions')
          .select(
            'id,client_session_id,day_name,performed_at,branch_name,check_in_at,exercise_logs(exercise_name,sets,reps,weight_kg,rpe,is_personal_record)',
          )
          .eq('user_id', userId)
          .order('performed_at');
      final sessions = sessionRows.map((item) {
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
      }).toList();
      await storage.saveWorkoutSessions(sessions);

      final membershipRows = await client
          .from('memberships')
          .select()
          .eq('user_id', userId)
          .eq('active', true)
          .order('end_date', ascending: false)
          .limit(1);
      if (membershipRows.isNotEmpty) {
        final item = membershipRows.first;
        await storage.saveMembership(
          MembershipPlan(
            id: item['id'] as String,
            name: item['name'] as String,
            branchName: item['branch_name'] as String,
            startDate: DateTime.parse(item['start_date'] as String),
            endDate: DateTime.parse(item['end_date'] as String),
            usedSessions: (item['used_sessions'] as num).toInt(),
            totalSessions: (item['total_sessions'] as num).toInt(),
            price: (item['price'] as num).toInt(),
            active: item['active'] as bool? ?? true,
          ),
        );
      }

      final noticeRows = await client
          .from('app_notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
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
      lastSyncAt = DateTime.now();
      return true;
    } catch (error) {
      lastError = error.toString();
      return false;
    } finally {
      syncing.value = false;
    }
  }

  Future<bool> syncNow() async {
    final client = SupabaseService.client;
    final user = SupabaseService.currentUser;
    if (client == null || user == null || syncing.value) return false;
    syncing.value = true;
    lastError = null;
    try {
      final storage = StorageService.instance;
      final profile = storage.loadProfile();
      if (profile != null) {
        await client.from('profiles').upsert({
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
        }, onConflict: 'user_id');
      }

      final checkIns = storage.loadDailyCheckIns();
      for (final checkIn in checkIns) {
        final date = checkIn.date;
        final dateOnly =
            '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        await client.from('daily_check_ins').upsert({
          'user_id': user.id,
          'check_in_date': dateOnly,
          'energy': checkIn.energy,
          'soreness': checkIn.soreness,
          'sleep_quality': checkIn.sleepQuality,
          'available_minutes': checkIn.availableMinutes,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'user_id,check_in_date');
      }

      final measurements = storage.loadBodyMeasurements();
      if (measurements.isNotEmpty) {
        await client
            .from('body_measurements')
            .upsert(
              measurements
                  .map(
                    (item) => {
                      'user_id': user.id,
                      'client_id': item.id,
                      'measured_at': item.date.toUtc().toIso8601String(),
                      'weight_kg': item.weight,
                    },
                  )
                  .toList(),
              onConflict: 'user_id,client_id',
            );
      }

      final favorites = storage.loadFavoriteExerciseIds();
      await client.from('favorite_exercises').delete().eq('user_id', user.id);
      if (favorites.isNotEmpty) {
        await client
            .from('favorite_exercises')
            .insert(
              favorites
                  .map((id) => {'user_id': user.id, 'exercise_id': id})
                  .toList(),
            );
      }

      for (final session in storage.loadWorkoutSessions()) {
        final remote = await client
            .from('workout_sessions')
            .upsert({
              'user_id': user.id,
              'client_session_id': session.id,
              'day_name': session.dayName,
              'performed_at': session.date.toUtc().toIso8601String(),
              'branch_name': session.branchName,
              'check_in_at': (session.checkedInAt ?? session.date)
                  .toUtc()
                  .toIso8601String(),
            }, onConflict: 'user_id,client_session_id')
            .select('id')
            .single();
        final remoteSessionId = remote['id'] as String;
        await client
            .from('exercise_logs')
            .delete()
            .eq('user_id', user.id)
            .eq('session_id', remoteSessionId);
        if (session.logs.isNotEmpty) {
          await client
              .from('exercise_logs')
              .insert(
                session.logs
                    .map(
                      (log) => {
                        'user_id': user.id,
                        'session_id': remoteSessionId,
                        'exercise_name': log.exerciseName,
                        'sets': log.sets,
                        'reps': log.reps,
                        'weight_kg': log.weight,
                        'rpe': log.rpe,
                        'is_personal_record': log.isPersonalRecord,
                      },
                    )
                    .toList(),
              );
        }
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
