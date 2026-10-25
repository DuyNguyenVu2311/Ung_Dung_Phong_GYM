import 'dart:convert';

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/modern_components.dart';
import '../models/data_models.dart';
import '../repositories/workout_schedule_repository.dart';
import '../services/storage_service.dart';

class WorkoutSessionScreen extends StatefulWidget {
  const WorkoutSessionScreen({super.key});

  @override
  State<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends State<WorkoutSessionScreen> {
  String _dayName = 'Buổi tập';
  List<Map<String, dynamic>> _exercises = [];
  List<TextEditingController> _setsCtrls = [];
  List<TextEditingController> _repsCtrls = [];
  List<TextEditingController> _weightCtrls = [];
  String _sessionId = '';

  bool _loaded = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _loadArgs();
    }
  }

  void _loadArgs() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args == null) {
      _buildDefault();
      return;
    }
    final map = args as Map?;
    if (map == null) {
      _buildDefault();
      return;
    }
    _dayName = (map['dayName'] as String? ?? 'Buổi tập');
    _sessionId = (map['id'] as String? ?? 'session_${DateTime.now().millisecondsSinceEpoch}');
    final exList = (map['exercises'] as List? ?? []);
    _exercises = exList.cast<Map<String, dynamic>>().toList();
    _initControllers();
  }

  void _buildDefault() {
    _dayName = 'Ngực & Tay sau';
    _sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
    _exercises = [
      {'exerciseName': 'Bench Press', 'sets': 3, 'reps': 10, 'weight': 60.0},
      {'exerciseName': 'Incline Dumbbell Press', 'sets': 3, 'reps': 10, 'weight': 25.0},
      {'exerciseName': 'Cable Chest Flyes', 'sets': 3, 'reps': 12, 'weight': 20.0},
      {'exerciseName': 'Push-up', 'sets': 3, 'reps': 12, 'weight': 0.0},
    ];
    _initControllers();
  }

  void _initControllers() {
    _setsCtrls = [];
    _repsCtrls = [];
    _weightCtrls = [];
    for (final e in _exercises) {
      _setsCtrls.add(TextEditingController(text: e['sets'].toString()));
      _repsCtrls.add(TextEditingController(text: e['reps'].toString()));
      _weightCtrls.add(TextEditingController(text: e['weight'].toString()));
    }
  }

  @override
  void dispose() {
    for (final c in _setsCtrls) c.dispose();
    for (final c in _repsCtrls) c.dispose();
    for (final c in _weightCtrls) c.dispose();
    super.dispose();
  }

  List<ExerciseLog> _readLogs() {
    final logs = <ExerciseLog>[];
    for (var i = 0; i < _exercises.length; i++) {
      final sets = int.tryParse(_setsCtrls[i].text) ?? 0;
      final reps = int.tryParse(_repsCtrls[i].text) ?? 0;
      final weight = double.tryParse(_weightCtrls[i].text) ?? 0.0;
      if (sets <= 0 && reps <= 0 && weight <= 0) continue;
      logs.add(ExerciseLog(
        id: '${_sessionId}_${i}',
        sessionId: _sessionId,
        exerciseName: _exercises[i]['exerciseName'] as String? ?? 'Bài tập',
        sets: sets,
        reps: reps,
        weight: weight,
      ));
    }
    return logs;
  }

  Future<void> _complete() async {
    final logs = _readLogs();
    if (logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập ít nhất một kết quả tập')),
      );
      return;
    }

    final session = WorkoutSession(
      id: _sessionId,
      dayName: _dayName,
      date: DateTime.now(),
      logs: logs,
    );
    await StorageService.instance.addWorkoutSession(session);
    await WorkoutScheduleRepository.setStatus(_sessionId, 'completed');

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã lưu kết quả buổi tập')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: ModernAppBar(title: _dayName, centerTitle: false),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                physics: const BouncingScrollPhysics(),
                itemCount: _exercises.length,
                itemBuilder: (context, i) {
                  final ex = _exercises[i];
                  return _exerciseItem(i, ex);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: GradientButton(
                onPressed: _complete,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Hoàn thành buổi tập', style: AppTextTheme.labelLarge.copyWith(fontWeight: FontWeight.w700, color: AppColors.textInverse)),
                    const SizedBox(width: 8),
                    const Icon(Icons.check_circle_rounded, color: AppColors.textInverse, size: 22),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const ModernBottomNav(currentIndex: 1, onTap: null),
    );
  }

  Widget _exerciseItem(int index, Map<String, dynamic> ex) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        borderRadius: 16,
        color: AppColors.surfaceElevated,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ex['exerciseName'] as String? ?? 'Bài tập',
              style: AppTextTheme.titleMedium.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _inputField(_setsCtrls[index], 'Hiệp', 'số hiệp'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _inputField(_repsCtrls[index], 'Lần', 'số lần'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _inputField(_weightCtrls[index], 'Tạ (kg)', 'mức tạ'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputField(TextEditingController c, String label, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextTheme.caption.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        SizedBox(
          height: 46,
          child: TextField(
            controller: c,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontFamily: AppTextTheme.font, fontSize: 14, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(fontFamily: AppTextTheme.font, fontSize: 12, color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
      ],
    );
  }
}
