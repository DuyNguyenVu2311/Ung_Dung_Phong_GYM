import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'screens/main_app_shell.dart';
import 'screens/auth_gate.dart';
import 'screens/goal_screen.dart';
import 'screens/level_screen.dart';
import 'screens/exercise_detail_screen.dart';
import 'screens/workout_session_screen.dart';
import 'screens/workout_plan_screen.dart';
import 'screens/history_screen.dart';
import 'screens/progress_statistics_screen.dart';
import 'services/storage_service.dart';
import 'services/supabase_service.dart';
import 'services/app_settings_service.dart';
import 'services/app_localization.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Be Vietnam Pro',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  await StorageService.instance.init();
  await AppSettingsService.initialize();
  await SupabaseService.initialize();
  runApp(FitPlanApp());
}

class FitPlanApp extends StatelessWidget {
  const FitPlanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppSettingsService.themeMode,
      builder: (context, themeMode, _) => MaterialApp(
        title: 'FitPlan',
        builder: (context, child) => AppSettingsScope(child: child!),
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        initialRoute: '/',
        routes: {
          '/': (context) => AuthGate(),
          '/profile': (context) => MainAppShell(initialIndex: 4),
          '/goal': (context) => GoalScreen(),
          '/level': (context) => LevelScreen(),
          '/schedule': (context) => MainAppShell(initialIndex: 1),
          '/library': (context) => MainAppShell(initialIndex: 2),
          '/membership': (context) => MainAppShell(initialIndex: 3),
          '/detail': (context) => ExerciseDetailScreen(),
          '/session': (context) => WorkoutSessionScreen(),
          '/plan': (context) => WorkoutPlanScreen(),
          '/history': (context) => HistoryScreen(),
          '/stats': (context) => ProgressStatisticsScreen(),
        },
      ),
    );
  }
}
