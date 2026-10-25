import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/modern_components.dart';
import '../models/data_models.dart';
import '../repositories/workout_plan_repository.dart';
import '../services/storage_service.dart';
import 'schedule_screen.dart';

class WorkoutPlanScreen extends StatefulWidget {
  const WorkoutPlanScreen({super.key});

  @override
  State<WorkoutPlanScreen> createState() => _WorkoutPlanScreenState();
}

class _WorkoutPlanScreenState extends State<WorkoutPlanScreen> {
  String _goal = 'muscle';
  String _level = 'beginner';
  int _sessions = 4;
  List<PlanDay> _plan = [];
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
    if (!mounted) return;
    setState(() {
      _goal = goal;
      _level = level;
      _sessions = sessions;
      _plan = plan;
      _loading = false;
    });
  }

  String _goalLabel(String g) {
    switch (g) {
      case 'muscle': return 'Tăng cơ';
      case 'fatloss': return 'Giảm mỡ';
      default: return 'Duy trì thể lực';
    }
  }

  String _levelLabel(String l) {
    switch (l) {
      case 'beginner': return 'Mới bắt đầu';
      default: return 'Có kinh nghiệm';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: ModernAppBar(title: 'Kế hoạch tập', centerTitle: false),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_goalLabel(_goal)}  ·  ${_levelLabel(_level)}  ·  $_sessions buổi/tuần',
                          style: AppTextTheme.bodySmall.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        const Text('Lên lịch trong tuần', style: AppTextTheme.headlineMedium),
                        const SizedBox(height: 4),
                        Text('Chọn từng ngày để xem chi tiết bài tập của buổi tập đó.', style: AppTextTheme.bodySmall.copyWith(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _plan.isEmpty
                        ? EmptyState(
                            icon: Icons.fitness_center_rounded,
                            title: 'Không có kế hoạch',
                            message: 'Hãy hoàn tất hồ sơ để tạo kế hoạch tập.',
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: _plan.length,
                            itemBuilder: (context, i) {
                              final day = _plan[i];
                              return _dayCard(day);
                            },
                          ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: GradientButton(
                        onPressed: _plan.isEmpty ? null : () => Navigator.pushNamed(context, '/schedule'),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Áp dụng vào lịch tập', style: AppTextTheme.labelLarge.copyWith(fontWeight: FontWeight.w700, color: AppColors.textInverse)),
                            const SizedBox(width: 8),
                            const Icon(Icons.calendar_today_rounded, color: AppColors.textInverse, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
      bottomNavigationBar: const ModernBottomNav(currentIndex: 2, onTap: null),
    );
  }

  Widget _dayCard(PlanDay day) {
    if (day.isRest) {
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        child: GlassCard(
          padding: const EdgeInsets.all(16),
          borderRadius: 16,
          color: AppColors.surface.withOpacity(0.6),
          child: Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.textMuted, shape: BoxShape.circle)),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(day.dayName, style: AppTextTheme.titleMedium.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('Nghỉ phục hồi', style: AppTextTheme.bodySmall.copyWith(color: AppColors.textSecondary)),
                ],
              )),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        borderRadius: 16,
        color: AppColors.surfaceElevated,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                const SizedBox(width: 12),
                Expanded(child: Text(day.dayName, style: AppTextTheme.titleMedium.copyWith(fontWeight: FontWeight.w700))),
                Text('${day.exercises.length} bài', style: AppTextTheme.labelLarge.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 12),
            ...day.exercises.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(width: 6, height: 6, decoration: BoxDecoration(color: AppColors.textMuted, shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.exercise.name, style: AppTextTheme.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
                      Text('${e.sets} hiệp · ${e.reps} lần · ${e.weight.toStringAsFixed(0)} kg',
                          style: AppTextTheme.bodySmall.copyWith(color: AppColors.textSecondary)),
                    ],
                  )),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 16),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}
