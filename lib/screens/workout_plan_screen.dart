import 'package:flutter/material.dart';

import '../services/app_localization.dart';

import '../theme/app_theme.dart';
import '../widgets/modern_components.dart';
import '../models/data_models.dart';
import '../repositories/workout_plan_repository.dart';
import '../repositories/workout_schedule_repository.dart';
import '../services/cloud_sync_service.dart';
import '../services/storage_service.dart';

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
    final profile = StorageService.instance.loadProfile();
    final goal =
        profile?.goal ?? StorageService.instance.loadGoal() ?? 'muscle';
    final level =
        profile?.experienceLevel ??
        StorageService.instance.loadLevel() ??
        'beginner';
    final sessions =
        profile?.sessionsPerWeek ??
        StorageService.instance.loadSessionsPerWeek() ??
        3;
    final plan = WorkoutPlanRepository.generatePlan(
      goal,
      level,
      sessions,
      availableWeekdays: profile?.availableWeekdays,
      profile: profile,
      availableMinutes: WorkoutScheduleRepository.workoutMinutes,
    );
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
      case 'muscle':
        return 'Tăng cơ';
      case 'fatloss':
        return 'Giảm mỡ';
      default:
        return 'Duy trì thể lực';
    }
  }

  String _levelLabel(String l) {
    switch (l) {
      case 'beginner':
        return 'Mới bắt đầu';
      default:
        return 'Có kinh nghiệm';
    }
  }

  @override
  Widget build(BuildContext context) {
    AppSettingsScope.watch(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: ModernAppBar(title: 'Kế hoạch tập', centerTitle: false),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 12),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LocalizedText(
                          '${_goalLabel(_goal)}  ·  ${_levelLabel(_level)}  ·  $_sessions buổi/tuần',
                          style: AppTextTheme.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 12),
                        LocalizedText(
                          'Lên lịch trong tuần',
                          style: AppTextTheme.headlineMedium,
                        ),
                        SizedBox(height: 4),
                        LocalizedText(
                          'Lịch theo ngày rảnh và thời gian mỗi buổi. Ít buổi hoặc buổi ngắn: luân phiên bài qua các tuần để bao phủ đủ nhóm cơ và góc tập.',
                          style: AppTextTheme.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          initialValue:
                              WorkoutScheduleRepository.workoutMinutes,
                          decoration: InputDecoration(
                            labelText: tr('Thời gian mỗi buổi'),
                          ),
                          items: [30, 45, 60, 75, 90]
                              .map(
                                (minutes) => DropdownMenuItem(
                                  value: minutes,
                                  child: LocalizedText('$minutes phút'),
                                ),
                              )
                              .toList(),
                          onChanged: (minutes) async {
                            if (minutes == null) return;
                            await WorkoutScheduleRepository.setWorkoutMinutes(
                              minutes,
                            );
                            await CloudSyncService.instance.syncNow();
                            await _load();
                          },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  Expanded(
                    child: _plan.isEmpty
                        ? EmptyState(
                            icon: Icons.fitness_center_rounded,
                            title: 'Không có kế hoạch',
                            message: 'Hãy hoàn tất hồ sơ để tạo kế hoạch tập.',
                          )
                        : ListView.builder(
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            itemCount: _plan.length,
                            itemBuilder: (context, i) {
                              final day = _plan[i];
                              return _dayCard(day);
                            },
                          ),
                  ),
                  SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: GradientButton(
                        onPressed: _plan.isEmpty
                            ? null
                            : () async {
                                await WorkoutScheduleRepository.updateFutureSchedule(
                                  _plan,
                                );
                                if (context.mounted) {
                                  Navigator.pushNamed(context, '/schedule');
                                }
                              },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: LocalizedText(
                                'Áp dụng vào lịch tập',
                                overflow: TextOverflow.ellipsis,
                                style: AppTextTheme.labelLarge.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textInverse,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(
                              Icons.calendar_today_rounded,
                              color: AppColors.textInverse,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _dayCard(PlanDay day) {
    if (day.isRest) {
      return Container(
        margin: EdgeInsets.only(bottom: 14),
        child: GlassCard(
          padding: EdgeInsets.all(16),
          borderRadius: 16,
          color: AppColors.surface.withValues(alpha: 0.6),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.textMuted,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LocalizedText(
                      day.dayName,
                      style: AppTextTheme.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    LocalizedText(
                      'Nghỉ phục hồi',
                      style: AppTextTheme.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: EdgeInsets.only(bottom: 14),
      child: GlassCard(
        padding: EdgeInsets.all(16),
        borderRadius: 16,
        color: AppColors.surfaceElevated,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: LocalizedText(
                    day.dayName,
                    style: AppTextTheme.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                LocalizedText(
                  '${day.exercises.length} bài',
                  style: AppTextTheme.labelLarge.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            ...day.exercises.map(
              (e) => Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppColors.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LocalizedText(
                            e.exercise.name,
                            style: AppTextTheme.bodyMedium.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          LocalizedText(
                            '${e.sets} hiệp chính × ${e.reps} lần${e.warmupSets > 0 ? ' + 1 hiệp khởi động' : ''}',
                            style: AppTextTheme.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          LocalizedText(
                            '${e.exercise.focusGroup} · ${e.exercise.targetArea}',
                            style: AppTextTheme.caption,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textMuted,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
