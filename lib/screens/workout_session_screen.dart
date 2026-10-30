import 'dart:async';

import 'package:flutter/material.dart';

import '../services/app_localization.dart';
import '../services/app_clock.dart';

import '../models/data_models.dart';
import '../repositories/workout_schedule_repository.dart';
import '../services/storage_service.dart';
import '../services/cloud_sync_service.dart';
import '../theme/app_theme.dart';

class WorkoutSessionScreen extends StatefulWidget {
  const WorkoutSessionScreen({super.key});

  @override
  State<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends State<WorkoutSessionScreen> {
  String _dayName = 'Buổi tập chủ động';
  String _sessionId = '';
  List<Map<String, dynamic>> _exercises = [];
  List<List<bool>> _completedSets = [];
  List<TextEditingController> _weightControllers = [];
  List<int> _rpeValues = [];
  List<bool> _warmups = [];
  Timer? _timer;
  final int _restSeconds = 60;
  int _remaining = 0;
  bool _loaded = false;
  final DateTime _startedAt = DateTime.now();
  String? _branch;
  DateTime? _scheduledDate;
  Timer? _dayTimer;
  DateTime _visibleDay = AppClock.today;
  bool get _canTrain => AppClock.sameDay(
    _scheduledDate ?? AppClock.inVietnam(_startedAt),
    AppClock.now(),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    _dayTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final today = AppClock.today;
      if (mounted && !AppClock.sameDay(_visibleDay, today)) {
        setState(() => _visibleDay = today);
      }
    });
    final membership = StorageService.instance.loadMembership();
    if (['Thủ Đức', 'Bình Thạnh', 'Quận 1'].contains(membership.branchName)) {
      _branch = membership.branchName;
    }
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _scheduledDate = DateTime.tryParse(args['date'] as String? ?? '');
      // A scheduled workout must have a valid date before it can be recorded.
      _scheduledDate ??= DateTime(1970);
      _dayName = args['dayName'] as String? ?? 'Buổi tập';
      _sessionId =
          args['id'] as String? ??
          'session_${DateTime.now().millisecondsSinceEpoch}';
      _exercises = (args['exercises'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    if (_exercises.isEmpty) {
      _sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
      _exercises = [
        {'exerciseName': 'Bench Press', 'sets': 3, 'reps': 10, 'weight': 40.0},
        {'exerciseName': 'Lat Pulldown', 'sets': 3, 'reps': 12, 'weight': 35.0},
        {'exerciseName': 'Squat', 'sets': 3, 'reps': 10, 'weight': 50.0},
      ];
    }
    _completedSets = _exercises
        .map((e) => List<bool>.filled((e['sets'] as num?)?.toInt() ?? 3, false))
        .toList();
    _weightControllers = _exercises
        .map((e) => TextEditingController(text: '${e['weight'] ?? 0}'))
        .toList();
    _rpeValues = List<int>.filled(_exercises.length, 7);
    _warmups = List<bool>.filled(_exercises.length, false);
  }

  @override
  void dispose() {
    _dayTimer?.cancel();
    _timer?.cancel();
    for (final controller in _weightControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  int get _totalSets =>
      _completedSets.fold(0, (sum, sets) => sum + sets.length);
  int get _doneSets => _completedSets.fold(
    0,
    (sum, sets) => sum + sets.where((done) => done).length,
  );

  void _toggleSet(int exerciseIndex, int setIndex) {
    if (!_canTrain) return;
    setState(
      () => _completedSets[exerciseIndex][setIndex] =
          !_completedSets[exerciseIndex][setIndex],
    );
    if (_completedSets[exerciseIndex][setIndex]) _startRest(_restSeconds);
  }

  void _startRest(int seconds) {
    _timer?.cancel();
    setState(() => _remaining = seconds);
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_remaining <= 1) {
        timer.cancel();
        if (mounted) {
          setState(() => _remaining = 0);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: LocalizedText(
                'Hết giờ nghỉ — sẵn sàng cho hiệp tiếp theo!',
              ),
            ),
          );
        }
      } else if (mounted) {
        setState(() => _remaining--);
      }
    });
  }

  Future<void> _finish() async {
    if (!_canTrain) {
      setState(() {});
      return;
    }
    final logs = <ExerciseLog>[];
    final previousBest = <String, double>{};
    for (final session in StorageService.instance.loadWorkoutSessions()) {
      for (final log in session.logs) {
        final current = previousBest[log.exerciseName] ?? 0;
        if (log.weight > current) previousBest[log.exerciseName] = log.weight;
      }
    }
    for (var i = 0; i < _exercises.length; i++) {
      final completed = _completedSets[i].where((done) => done).length;
      if (completed == 0) continue;
      final exerciseName = _exercises[i]['exerciseName'] as String? ?? '';
      final weight = double.tryParse(_weightControllers[i].text) ?? 0;
      logs.add(
        ExerciseLog(
          id: '${_sessionId}_$i',
          sessionId: _sessionId,
          exerciseName: _exercises[i]['exerciseName'] as String? ?? 'Bài tập',
          sets: completed,
          reps: (_exercises[i]['reps'] as num?)?.toInt() ?? 0,
          weight: weight,
          rpe: _rpeValues[i],
          isPersonalRecord:
              weight > 0 && weight > (previousBest[exerciseName] ?? 0),
        ),
      );
    }
    if (logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: LocalizedText('Hãy hoàn thành ít nhất một hiệp tập')),
      );
      return;
    }
    if (_branch == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: LocalizedText('Chọn nơi tập để lưu lịch sử chính xác.'),
        ),
      );
      return;
    }
    await StorageService.instance.addWorkoutSession(
      WorkoutSession(
        id: _sessionId,
        dayName: _dayName,
        date: DateTime.now(),
        logs: logs,
        branchName: _branch!,
        checkedInAt: _startedAt,
      ),
    );
    await CloudSyncService.instance.syncNow();
    await WorkoutScheduleRepository.setStatus(_sessionId, 'completed');
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    AppSettingsScope.watch(context);
    if (!_canTrain) return _preview();
    final progress = _totalSets == 0 ? 0.0 : _doneSets / _totalSets;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LocalizedText(_dayName),
            LocalizedText(
              '$_doneSets/$_totalSets hiệp hoàn thành',
              style: AppTextTheme.caption,
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.close_rounded),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: Size.fromHeight(56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          onPressed: _finish,
          icon: Icon(Icons.flag_rounded),
          label: LocalizedText('Hoàn thành buổi tập'),
        ),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: AppColors.divider,
            borderRadius: BorderRadius.circular(9),
          ),
          if (_remaining > 0) _restBanner(),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: DropdownButtonFormField<String>(
              initialValue: _branch,
              decoration: InputDecoration(labelText: tr('Nơi tập')),
              items: ['Thủ Đức', 'Bình Thạnh', 'Quận 1', 'Tập tại nhà']
                  .map(
                    (branch) => DropdownMenuItem(
                      value: branch,
                      child: LocalizedText(branch),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _branch = value),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 26),
              physics: BouncingScrollPhysics(),
              itemCount: _exercises.length,
              separatorBuilder: (_, _) => SizedBox(height: 16),
              itemBuilder: (_, index) => _exerciseCard(index),
            ),
          ),
        ],
      ),
    );
  }

  Widget _preview() {
    final future =
        _scheduledDate != null &&
        AppClock.day(_scheduledDate!).isAfter(AppClock.today);
    return Scaffold(
      appBar: AppBar(title: LocalizedText(_dayName)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          LocalizedText(
            future ? 'Xem trước lịch tập' : 'Lịch tập chỉ xem',
            style: AppTextTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          if (_scheduledDate != null)
            LocalizedText(AppClock.date(_scheduledDate!)),
          const SizedBox(height: 8),
          LocalizedText(
            future
                ? 'Chưa đến ngày tập. Bạn chỉ có thể bắt đầu và ghi kết quả vào đúng ngày này.'
                : 'Chỉ có thể ghi kết quả cho buổi tập hôm nay.',
          ),
          const SizedBox(height: 16),
          ..._exercises.map(
            (exercise) => ListTile(
              leading: const Icon(Icons.fitness_center_rounded),
              title: LocalizedText(exercise['exerciseName'] as String? ?? ''),
              subtitle: LocalizedText(
                '${exercise['sets'] ?? 0} hiệp chính × ${exercise['reps'] ?? 0} lần'
                '${(exercise['warmupSets'] as num? ?? 0) > 0 ? ' + 1 hiệp khởi động' : ''}'
                '${(exercise['targetArea'] as String? ?? '').isNotEmpty ? '\n${exercise['focusGroup']} · ${exercise['targetArea']}' : ''}',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _restBanner() {
    final minutes = (_remaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remaining % 60).toString().padLeft(2, '0');
    return Container(
      margin: EdgeInsets.fromLTRB(20, 14, 20, 0),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppGradients.primary,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 58,
            height: 58,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: (_remaining / _restSeconds).clamp(0.0, 1.0),
                  strokeWidth: 6,
                  backgroundColor: Colors.black12,
                  valueColor: AlwaysStoppedAnimation(AppColors.textInverse),
                ),
                Icon(
                  Icons.hourglass_bottom_rounded,
                  color: AppColors.textInverse,
                ),
              ],
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LocalizedText(
                  'Đang nghỉ',
                  style: AppTextTheme.caption.copyWith(
                    color: AppColors.textInverse,
                  ),
                ),
                LocalizedText(
                  '$minutes:$seconds',
                  style: AppTextTheme.headlineLarge.copyWith(
                    color: AppColors.textInverse,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _remaining += 30),
            child: LocalizedText('+30s'),
          ),
          IconButton(
            onPressed: () {
              _timer?.cancel();
              setState(() => _remaining = 0);
            },
            icon: Icon(Icons.skip_next_rounded, color: AppColors.textInverse),
          ),
        ],
      ),
    );
  }

  Widget _exerciseCard(int index) {
    final exercise = _exercises[index];
    final sets = _completedSets[index];
    final reps = (exercise['reps'] as num?)?.toInt() ?? 10;
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: sets.every((done) => done)
              ? AppColors.primary
              : AppColors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.fitness_center_rounded,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LocalizedText(
                      exercise['exerciseName'] as String? ?? 'Bài tập',
                      style: AppTextTheme.titleMedium,
                    ),
                    LocalizedText(
                      '${sets.length} hiệp × $reps lần',
                      style: AppTextTheme.bodySmall,
                    ),
                    if ((exercise['targetArea'] as String? ?? '').isNotEmpty)
                      LocalizedText(
                        '${exercise['focusGroup']} · ${exercise['targetArea']}',
                        style: AppTextTheme.caption,
                      ),
                  ],
                ),
              ),
              SizedBox(
                width: 76,
                child: TextField(
                  controller: _weightControllers[index],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    suffixText: 'kg',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 9,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if ((exercise['warmupSets'] as num? ?? 0) > 0) ...[
            SizedBox(height: 12),
            Material(
              color: Colors.transparent,
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: LocalizedText('1 hiệp khởi động · 12–15 lần nhẹ'),
                subtitle: LocalizedText(
                  'Dùng tải nhẹ, không đến kiệt sức. Không tính vào hiệp chính hay kỷ lục.',
                ),
                value: _warmups[index],
                onChanged: (value) {
                  if (_canTrain) {
                    setState(() => _warmups[index] = value ?? false);
                  }
                },
              ),
            ),
          ],
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.fromLTRB(14, 10, 8, 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.speed_rounded,
                      size: 19,
                      color: AppColors.secondary,
                    ),
                    SizedBox(width: 8),
                    Expanded(child: LocalizedText('Độ khó cảm nhận (RPE)')),
                    LocalizedText(
                      '${_rpeValues[index]}/10',
                      style: AppTextTheme.labelLarge.copyWith(
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _rpeValues[index].toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  onChanged: (value) =>
                      setState(() => _rpeValues[index] = value.round()),
                ),
              ],
            ),
          ),
          SizedBox(height: 18),
          ...List.generate(sets.length, (setIndex) {
            final done = sets[setIndex];
            return Padding(
              padding: EdgeInsets.only(
                bottom: setIndex == sets.length - 1 ? 0 : 9,
              ),
              child: Material(
                color: done
                    ? AppColors.primary.withValues(alpha: .13)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(15),
                child: InkWell(
                  onTap: () => _toggleSet(index, setIndex),
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    constraints: BoxConstraints(minHeight: 54),
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: Duration(milliseconds: 180),
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: done
                                ? AppColors.primary
                                : Colors.transparent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: done
                                  ? AppColors.primary
                                  : AppColors.textMuted,
                              width: 2,
                            ),
                          ),
                          child: done
                              ? Icon(
                                  Icons.check_rounded,
                                  size: 20,
                                  color: AppColors.textInverse,
                                )
                              : null,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: LocalizedText(
                            'Hiệp ${setIndex + 1}',
                            style: AppTextTheme.labelLarge,
                          ),
                        ),
                        LocalizedText(
                          '$reps lần',
                          style: AppTextTheme.bodyMedium.copyWith(
                            color: done
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
