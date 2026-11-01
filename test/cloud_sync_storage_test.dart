import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fit_gym/models/data_models.dart';
import 'package:fit_gym/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.instance.init();
  });

  test('pending local data is durable and isolated by account', () async {
    final storage = StorageService.instance;
    await storage.bindUser('account-a');
    await storage.saveProfile(
      UserProfile(
        name: 'Local',
        age: 30,
        height: 170,
        weight: 65,
        gender: 'Nam',
        goal: 'muscle',
        experienceLevel: 'beginner',
        sessionsPerWeek: 3,
      ),
    );
    await storage.addBodyMeasurement(
      BodyMeasurement(
        id: 'measurement-a',
        date: DateTime(2026, 11),
        weight: 65,
      ),
    );
    await storage.saveFavoriteExerciseIds({'squat'});
    await storage.addWorkoutSession(
      WorkoutSession(
        id: 'session-a',
        dayName: 'Thứ Hai',
        date: DateTime(2026, 11, 1),
        logs: [],
      ),
    );
    await storage.saveDailyCheckIn(
      DailyCheckIn(
        date: DateTime(2026, 11, 1),
        energy: 4,
        soreness: 2,
        sleepQuality: 4,
        availableMinutes: 45,
      ),
    );

    expect(storage.hasPendingSyncChanges, isTrue);
    await storage.bindUser('account-b');
    expect(storage.hasPendingSyncChanges, isFalse);
    expect(storage.loadProfile(), isNull);

    await storage.bindUser('account-a');
    expect(storage.loadProfile()!.name, 'Local');
    expect(
      storage.pendingSyncChanges[StorageService.syncMeasurements]!.keys,
      contains('measurement-a'),
    );
    expect(
      storage.pendingSyncChanges[StorageService.syncSessions]!.keys,
      contains('session-a'),
    );
    expect(
      storage.pendingSyncChanges[StorageService.syncCheckIns]!.keys,
      contains('2026-11-01'),
    );
    expect(
      storage.pendingSyncChanges[StorageService.syncFavorites]!.keys,
      contains('squat'),
    );
  });

  test(
    'acknowledging an old revision keeps a newer local edit pending',
    () async {
      final storage = StorageService.instance;
      await storage.bindUser('account-a');
      UserProfile profile(String name) => UserProfile(
        name: name,
        age: 30,
        height: 170,
        weight: 65,
        gender: 'Nam',
        goal: 'muscle',
        experienceLevel: 'beginner',
        sessionsPerWeek: 3,
      );

      await storage.saveProfile(profile('First'));
      final oldRevision =
          storage.pendingSyncChanges[StorageService.syncProfile]!['profile']!;
      await storage.saveProfile(profile('Second'));
      final newRevision =
          storage.pendingSyncChanges[StorageService.syncProfile]!['profile']!;

      await storage.acknowledgeSyncChange(
        StorageService.syncProfile,
        'profile',
        oldRevision,
      );

      expect(
        storage.pendingSyncChanges[StorageService.syncProfile]!['profile'],
        newRevision,
      );
      expect(storage.loadProfile()!.name, 'Second');
    },
  );

  test('acknowledged revisions are never reused', () async {
    final storage = StorageService.instance;
    await storage.bindUser('account-a');
    final profile = UserProfile(
      name: 'Member',
      age: 30,
      height: 170,
      weight: 65,
      gender: 'Nam',
      goal: 'muscle',
      experienceLevel: 'beginner',
      sessionsPerWeek: 3,
    );

    await storage.saveProfile(profile);
    final acknowledged =
        storage.pendingSyncChanges[StorageService.syncProfile]!['profile']!;
    await storage.acknowledgeSyncChange(
      StorageService.syncProfile,
      'profile',
      acknowledged,
    );
    await storage.saveProfile(profile);

    expect(
      storage.pendingSyncChanges[StorageService.syncProfile]!['profile'],
      greaterThan(acknowledged),
    );
  });

  test(
    'a delayed acknowledgment cannot clear another account journal',
    () async {
      final storage = StorageService.instance;
      await storage.bindUser('account-a');
      final profile = UserProfile(
        name: 'Account A',
        age: 30,
        height: 170,
        weight: 65,
        gender: 'Nam',
        goal: 'muscle',
        experienceLevel: 'beginner',
        sessionsPerWeek: 3,
      );
      await storage.saveProfile(profile);
      final accountARevision =
          storage.pendingSyncChanges[StorageService.syncProfile]!['profile']!;

      await storage.bindUser('account-b');
      await storage.saveProfile(
        UserProfile(
          name: 'Account B',
          age: 25,
          height: 160,
          weight: 55,
          gender: 'Nữ',
          goal: 'maintenance',
          experienceLevel: 'beginner',
          sessionsPerWeek: 2,
        ),
      );
      await storage.acknowledgeSyncChange(
        StorageService.syncProfile,
        'profile',
        accountARevision,
        userId: 'account-a',
      );

      expect(storage.loadProfile()!.name, 'Account B');
      expect(
        storage.pendingSyncChanges[StorageService.syncProfile]!['profile'],
        isNotNull,
      );
    },
  );

  test('concurrent local changes retain every pending domain', () async {
    final storage = StorageService.instance;
    await storage.bindUser('account-a');

    await Future.wait([
      storage.saveProfile(
        UserProfile(
          name: 'Local',
          age: 30,
          height: 170,
          weight: 65,
          gender: 'Nam',
          goal: 'muscle',
          experienceLevel: 'beginner',
          sessionsPerWeek: 3,
        ),
      ),
      storage.addBodyMeasurement(
        BodyMeasurement(
          id: 'measurement-a',
          date: DateTime(2026, 11),
          weight: 65,
        ),
      ),
      storage.saveFavoriteExerciseIds({'squat'}),
    ]);

    expect(storage.pendingSyncChanges[StorageService.syncProfile], isNotEmpty);
    expect(
      storage.pendingSyncChanges[StorageService.syncMeasurements],
      contains('measurement-a'),
    );
    expect(
      storage.pendingSyncChanges[StorageService.syncFavorites],
      contains('squat'),
    );
  });

  test('concurrent measurements do not overwrite each other', () async {
    final storage = StorageService.instance;
    await storage.bindUser('account-a');

    await Future.wait([
      storage.addBodyMeasurement(
        BodyMeasurement(
          id: 'measurement-a',
          date: DateTime(2026, 11, 1),
          weight: 65,
        ),
      ),
      storage.addBodyMeasurement(
        BodyMeasurement(
          id: 'measurement-b',
          date: DateTime(2026, 11, 2),
          weight: 66,
        ),
      ),
    ]);

    expect(storage.loadBodyMeasurements().map((item) => item.id).toSet(), {
      'measurement-a',
      'measurement-b',
    });
    expect(storage.pendingSyncChanges[StorageService.syncMeasurements]!.keys, {
      'measurement-a',
      'measurement-b',
    });
  });

  test('favorite removals remain as pending tombstones', () async {
    final storage = StorageService.instance;
    await storage.bindUser('account-a');
    await storage.saveFavoriteExerciseIds({'squat'});
    final addRevision =
        storage.pendingSyncChanges[StorageService.syncFavorites]!['squat']!;
    await storage.acknowledgeSyncChange(
      StorageService.syncFavorites,
      'squat',
      addRevision,
    );

    await storage.saveFavoriteExerciseIds({});

    expect(storage.loadFavoriteExerciseIds(), isEmpty);
    expect(
      storage.pendingSyncChanges[StorageService.syncFavorites]!.keys,
      contains('squat'),
    );
  });

  test('cloud-applied values do not become local pending changes', () async {
    final storage = StorageService.instance;
    await storage.bindUser('account-a');
    await storage.saveProfile(
      UserProfile(
        name: 'Remote',
        age: 30,
        height: 170,
        weight: 65,
        gender: 'Nam',
        goal: 'muscle',
        experienceLevel: 'beginner',
        sessionsPerWeek: 3,
      ),
      fromCloud: true,
    );
    await storage.saveFavoriteExerciseIds({'remote-favorite'}, fromCloud: true);

    expect(storage.hasPendingSyncChanges, isFalse);
  });

  test('local edits made during restore win and stay pending', () async {
    final storage = StorageService.instance;
    await storage.bindUser('account-a');
    UserProfile profile(String name) => UserProfile(
      name: name,
      age: 30,
      height: 170,
      weight: 65,
      gender: 'Nam',
      goal: 'muscle',
      experienceLevel: 'beginner',
      sessionsPerWeek: 3,
    );

    final restore = storage.restoreCloudSnapshot(
      userId: 'account-a',
      profile: profile('Cloud'),
      workoutMinutes: 75,
      checkIns: [],
      measurements: [],
      favoriteIds: {},
      sessions: [],
    );
    final localEdit = storage.saveProfile(profile('Local'));
    await Future.wait([restore, localEdit]);

    expect(storage.loadProfile()!.name, 'Local');
    expect(storage.loadWorkoutMinutes(), 75);
    expect(
      storage.pendingSyncChanges[StorageService.syncProfile]?['profile'],
      isNotNull,
    );
  });

  test('existing account cache is journaled once during upgrade', () async {
    final storage = StorageService.instance;
    await storage.bindUser('account-a');
    await storage.saveProfile(
      UserProfile(
        name: 'Existing',
        age: 30,
        height: 170,
        weight: 65,
        gender: 'Nam',
        goal: 'muscle',
        experienceLevel: 'beginner',
        sessionsPerWeek: 3,
      ),
      fromCloud: true,
    );
    await storage.saveDailyCheckIn(
      DailyCheckIn(
        date: DateTime(2026, 11, 1),
        energy: 4,
        soreness: 2,
        sleepQuality: 4,
        availableMinutes: 45,
      ),
      fromCloud: true,
    );
    await storage.saveBodyMeasurements([
      BodyMeasurement(
        id: 'existing-measurement',
        date: DateTime(2026, 11),
        weight: 65,
      ),
    ], fromCloud: true);
    await storage.saveFavoriteExerciseIds({
      'existing-favorite',
    }, fromCloud: true);
    await storage.saveWorkoutSessions([
      WorkoutSession(
        id: 'existing-session',
        dayName: 'Thứ Hai',
        date: DateTime(2026, 11, 1),
        logs: [],
      ),
    ], fromCloud: true);

    await storage.ensureSyncJournalInitialized();
    final firstJournal = storage.pendingSyncChanges;
    await storage.ensureSyncJournalInitialized();

    expect(storage.pendingSyncChanges, firstJournal);
    expect(firstJournal[StorageService.syncProfile]!.keys, contains('profile'));
    expect(
      firstJournal[StorageService.syncCheckIns]!.keys,
      contains('2026-11-01'),
    );
    expect(
      firstJournal[StorageService.syncMeasurements]!.keys,
      contains('existing-measurement'),
    );
    expect(
      firstJournal[StorageService.syncFavorites]!.keys,
      contains('existing-favorite'),
    );
    expect(
      firstJournal[StorageService.syncSessions]!.keys,
      contains('existing-session'),
    );
  });
}
