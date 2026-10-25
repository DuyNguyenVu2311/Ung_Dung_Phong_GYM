import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/modern_components.dart';
import '../repositories/workout_plan_repository.dart';
import '../repositories/workout_schedule_repository.dart';
import '../services/storage_service.dart';
import 'workout_session_screen.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  List<Map<String, dynamic>> _schedule = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final goal = StorageService.instance.loadGoal() ?? 'muscle';
    final level = StorageService.instance.loadLevel() ?? 'beginner';
    final sessions = StorageService.instance.loadSessionsPerWeek() ?? 4;

    final plan = WorkoutPlanRepository.generatePlan(goal, level, sessions);
    final existing = WorkoutScheduleRepository.loadSchedule();
    final schedule = existing.isEmpty
        ? WorkoutScheduleRepository.generateSchedule(plan)
        : existing;

    if (!mounted) return;
    setState(() {
      _schedule = schedule;
      _loading = false;
    });
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'planned': return 'Đã lên lịch';
      case 'in_progress': return 'Đang thực hiện';
      case 'completed': return 'Hoàn thành';
      case 'rest_day': return 'Nghỉ';
      default: return s;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'completed': return AppColors.primary;
      case 'in_progress': return AppColors.secondary;
      case 'rest_day': return AppColors.textMuted;
      default: return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: ModernAppBar(title: 'Lịch tập tuần', centerTitle: false),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Tháng 10, 2026', style: AppTextTheme.headlineMedium),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.fitness_center_rounded, color: AppColors.primary, size: 14),
                              const SizedBox(width: 6),
                              Text('Tập trung', style: AppTextTheme.caption.copyWith(fontWeight: FontWeight.w700, color: AppColors.primary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _weekStrip(),
                  const SizedBox(height: 20),
                  Expanded(
                    child: _schedule.isEmpty
                        ? EmptyState(
                            icon: Icons.calendar_today_rounded,
                            title: 'Chưa có lịch tập',
                            message: 'Hãy tạo kế hoạch tập để bắt đầu lên lịch.',
                            action: GradientButton(
                              onPressed: () => Navigator.pushNamed(context, '/plan'),
                              child: Text('Tạo kế hoạch', style: AppTextTheme.labelLarge.copyWith(fontWeight: FontWeight.w700, color: AppColors.textInverse)),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: _schedule.length,
                            itemBuilder: (context, i) {
                              final d = _schedule[i];
                              return _dayCard(d);
                            },
                          ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
      bottomNavigationBar: const ModernBottomNav(currentIndex: 1, onTap: null),
    );
  }

  Widget _weekStrip() {
    final labels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text('Lịch tập trong tuần', style: TextStyle(fontFamily: AppTextTheme.font, fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 0.4)),
        ),
        const SizedBox(height: 10),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(color: AppColors.surface.withOpacity(0.6), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.divider, width: 1)),
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 7,
            mainAxisSpacing: 3,
            crossAxisSpacing: 3,
            children: List.generate(7, (i) {
              final d = _schedule.isNotEmpty && i < _schedule.length ? _schedule[i] : null;
              final active = d != null && d['status'] == 'planned';
              final done = d != null && d['status'] == 'completed';
              final rest = d != null && d['status'] == 'rest_day';
              return Column(
                children: [
                  Text(labels[i], style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: active ? AppColors.primary : AppColors.textMuted)),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () {},
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: done
                            ? AppColors.primary
                            : active
                                ? AppColors.primary.withOpacity(0.5)
                                : rest
                                    ? AppColors.textMuted.withOpacity(0.2)
                                    : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          d != null ? (d['date'] as String).substring(8, 10) : (i + 25).toString(),
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: done ? AppColors.textInverse : AppColors.textPrimary),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _dayCard(Map<String, dynamic> d) {
    final isRest = d['isRest'] == true;
    final status = d['status'] as String;
    final completed = status == 'completed';

    return GestureDetector(
      onTap: isRest ? null : () => Navigator.pushNamed(context, '/session', arguments: d),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: completed ? AppColors.surface : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: completed ? AppColors.primary : AppColors.divider,
            width: completed ? 1.5 : 1,
          ),
          boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 16, offset: Offset(0, 6))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: completed ? AppColors.primary : AppColors.divider,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Icon(
                        completed ? Icons.check_rounded : Icons.fitness_center_rounded,
                        color: completed ? AppColors.textInverse : AppColors.primary,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(d['dayName'] as String, style: AppTextTheme.titleMedium.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: isRest ? null : () => _cycleStatus(d),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: _statusColor(status).withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(_statusLabel(status), style: TextStyle(fontSize: 10, color: _statusColor(status), fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.edit, size: 10, color: AppColors.textMuted),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (isRest)
                          Text('Ngày nghỉ phục hồi', style: AppTextTheme.bodySmall.copyWith(color: AppColors.textSecondary))
                        else
                          Text('${d['exerciseCount']} bài tập · ${_statusLabel(status)}', style: AppTextTheme.bodySmall.copyWith(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  if (!isRest) const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _cycleStatus(Map<String, dynamic> d) async {
    final status = d['status'] as String;
    String next;
    if (status == 'planned') next = 'in_progress';
    else if (status == 'in_progress') next = 'completed';
    else next = 'planned';
    await WorkoutScheduleRepository.setStatus(d['id'] as String, next);
    if (!mounted) return;
    setState(() {
      final idx = _schedule.indexWhere((e) => e['id'] == d['id']);
      if (idx >= 0) _schedule[idx]['status'] = next;
    });
  }
}
