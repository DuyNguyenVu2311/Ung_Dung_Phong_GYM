import 'package:fit_gym/models/data_models.dart';
import 'package:fit_gym/repositories/workout_plan_repository.dart';
import 'package:fit_gym/repositories/workout_schedule_repository.dart';
import 'package:fit_gym/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final storage = StorageService.instance;
  final monday = DateTime(2026, 11, 2);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await storage.init();
    await storage.bindUser('account-a');
  });

  UserProfile profile() => UserProfile(
    name: 'Member',
    age: 30,
    height: 170,
    weight: 65,
    gender: 'Nam',
    goal: 'muscle',
    experienceLevel: 'beginner',
    sessionsPerWeek: 3,
    availableWeekdays: const [1, 3, 5],
  );

  int firstTrainingDuration(List<Map<String, dynamic>> schedule) =>
      schedule.firstWhere((day) => day['isRest'] != true)['estimatedMinutes']
          as int;

  test(
    'cloud-restored duration rebuilds only the current future plan',
    () async {
      final member = profile();
      await storage.saveProfile(member, fromCloud: true);
      await storage.saveWorkoutMinutes(30, fromCloud: true);
      final shortPlan = WorkoutPlanRepository.generatePlan(
        member.goal,
        member.experienceLevel,
        member.sessionsPerWeek,
        profile: member,
        availableMinutes: 30,
        weekOf: monday,
      );
      final shortSchedule = await WorkoutScheduleRepository.generateSchedule(
        shortPlan,
        start: monday,
      );
      final shortDuration = firstTrainingDuration(shortSchedule);
      expect(shortDuration, lessThanOrEqualTo(30));

      await storage.saveWorkoutMinutes(90, fromCloud: true);
      final restored = await WorkoutScheduleRepository.ensureCurrentWeek(
        now: monday,
      );

      expect(firstTrainingDuration(restored), greaterThan(shortDuration));
      expect(firstTrainingDuration(restored), lessThanOrEqualTo(90));
      expect(storage.pendingSyncChanges[StorageService.syncProfile], isNull);
    },
  );

  test(
    'member duration changes are marked for profile synchronization',
    () async {
      await storage.saveProfile(profile());
      await storage.saveWorkoutMinutes(75);

      expect(storage.loadWorkoutMinutes(), 75);
      expect(
        storage.pendingSyncChanges[StorageService.syncProfile]!['profile'],
        isNotNull,
      );
    },
  );
}
