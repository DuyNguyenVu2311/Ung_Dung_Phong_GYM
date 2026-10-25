import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/goal_screen.dart';
import 'screens/level_screen.dart';
import 'screens/schedule_screen.dart';
import 'screens/exercise_library_screen.dart';
import 'screens/exercise_detail_screen.dart';
import 'screens/workout_session_screen.dart';
import 'screens/workout_plan_screen.dart';
import 'screens/history_screen.dart';
import 'screens/progress_statistics_screen.dart';
import 'services/storage_service.dart';
import 'models/data_models.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.instance.init();
  if (StorageService.instance.loadProfile() == null) {
    await StorageService.instance.saveProfile(UserProfile(
      name: 'Nguyen Van A',
      age: 25,
      height: 175,
      weight: 72,
      gender: 'Nam',
      goal: 'muscle',
      experienceLevel: 'intermediate',
      sessionsPerWeek: 4,
    ));
  }
  if (StorageService.instance.loadWorkoutSessions().isEmpty) {
    final today = DateTime.now();
    await StorageService.instance.addWorkoutSession(WorkoutSession(
      id: 's1',
      dayName: 'Thứ Hai',
      date: today,
      logs: [ExerciseLog(id: 'l1', sessionId: 's1', exerciseName: 'Bench Press', sets: 4, reps: 8, weight: 60)],
    ));
  }
  runApp(const FitPlanApp());
}

class FitPlanApp extends StatelessWidget {
  const FitPlanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitPlan',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/goal': (context) => const GoalScreen(),
        '/level': (context) => const LevelScreen(),
        '/schedule': (context) => const ScheduleScreen(),
        '/library': (context) => const ExerciseLibraryScreen(),
        '/detail': (context) => const ExerciseDetailScreen(),
        '/session': (context) => const WorkoutSessionScreen(),
        '/plan': (context) => const WorkoutPlanScreen(),
        '/history': (context) => const HistoryScreen(),
        '/stats': (context) => const ProgressStatisticsScreen(),
      },
    );
  }
}
