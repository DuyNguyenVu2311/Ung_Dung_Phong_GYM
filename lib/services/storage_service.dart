import 'package:shared_preferences/shared_preferences.dart';
import '../models/data_models.dart';

class StorageService {
  StorageService._internal();
  static final StorageService instance = StorageService._internal();

  static SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static const _kProfile = 'fit_profile';
  static const _kGoal = 'fit_goal';
  static const _kLevel = 'fit_level';
  static const _kSessionsPerWeek = 'fit_sessions';
  static const _kWorkoutSessions = 'fit_workout_sessions';

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
    return UserProfile.fromJsonString(s);
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
    final list = sessions.map((s) => s.toJson()).toList();
    await _prefs?.setStringList(_kWorkoutSessions, list.map((e) => e.toString()).toList());
  }

  List<WorkoutSession> loadWorkoutSessions() {
    final list = _prefs?.getStringList(_kWorkoutSessions) ?? [];
    return list.map((e) => WorkoutSession.fromJsonString(e)).toList();
  }

  Future<void> addWorkoutSession(WorkoutSession session) async {
    final current = loadWorkoutSessions();
    current.add(session);
    await saveWorkoutSessions(current);
  }

  Future<void> clearAll() async {
    await _prefs?.clear();
  }
}
