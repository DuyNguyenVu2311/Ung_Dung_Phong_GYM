import 'dart:async';

import 'package:flutter/material.dart';

import '../services/app_localization.dart';

import '../repositories/workout_plan_repository.dart';
import '../repositories/workout_schedule_repository.dart';
import '../services/cloud_sync_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/modern_components.dart';
import '../services/app_clock.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> _schedule = [];
  bool _loading = true;
  late final Timer _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addObserver(this);
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) => _load());
  }

  @override
  void dispose() {
    _refreshTimer.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
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
    final existing = await WorkoutScheduleRepository.ensureCurrentWeek();
    final schedule = existing.isNotEmpty
        ? existing
        : await WorkoutScheduleRepository.generateSchedule(
            WorkoutPlanRepository.generatePlan(
              goal,
              level,
              sessions,
              availableWeekdays: profile?.availableWeekdays,
              profile: profile,
              availableMinutes: WorkoutScheduleRepository.workoutMinutes,
            ),
          );
    if (!mounted) return;
    setState(() {
      _schedule = schedule;
      _loading = false;
    });
  }

  String get _monthTitle {
    final date = _schedule.isEmpty
        ? AppClock.now()
        : DateTime.tryParse(_schedule.first['date'] as String? ?? '') ??
              AppClock.now();
    return 'Tháng ${date.month}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    AppSettingsScope.watch(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _loading
            ? Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: CustomScrollView(
                  physics: AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LocalizedText(
                              'Lịch tập',
                              style: AppTextTheme.headlineLarge,
                            ),
                            SizedBox(height: 5),
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                LocalizedText(
                                  _monthTitle,
                                  style: AppTextTheme.bodyMedium.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                _statusPill(
                                  Icons.auto_awesome_rounded,
                                  'Kế hoạch cá nhân',
                                  AppColors.primary,
                                ),
                              ],
                            ),
                            SizedBox(height: 20),
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
                            SizedBox(height: 8),
                            LocalizedText(
                              'Số bài theo thời gian bạn rảnh. Buổi ngắn hoặc ít buổi: luân phiên bài qua các tuần, không dồn toàn bộ nhóm cơ vào một buổi. Check-in hôm nay có thể giảm khối lượng.',
                              style: AppTextTheme.caption,
                            ),
                            SizedBox(height: 16),
                            _weekStrip(),
                            SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: LocalizedText(
                                    'Lịch trong tuần',
                                    style: AppTextTheme.titleLarge,
                                  ),
                                ),
                                LocalizedText(
                                  '${WorkoutScheduleRepository.completedCount()}/${WorkoutScheduleRepository.plannedCount()} hoàn thành',
                                  style: AppTextTheme.caption,
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                    if (_schedule.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyState(
                          icon: Icons.calendar_today_rounded,
                          title: 'Chưa có lịch tập',
                          message: 'Tạo kế hoạch phù hợp để bắt đầu.',
                          action: FilledButton(
                            onPressed: () =>
                                Navigator.pushNamed(context, '/plan'),
                            child: LocalizedText('Tạo kế hoạch'),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(20, 0, 20, 28),
                        sliver: SliverList.separated(
                          itemCount: _schedule.length,
                          separatorBuilder: (_, _) => SizedBox(height: 12),
                          itemBuilder: (_, index) => _dayCard(_schedule[index]),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _weekStrip() {
    const labels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    return SizedBox(
      height: 78 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        separatorBuilder: (_, _) => SizedBox(width: 8),
        itemBuilder: (_, index) {
          final day = index < _schedule.length ? _schedule[index] : null;
          final status = day?['status'] as String?;
          final active = status == 'planned' || status == 'in_progress';
          final done = status == 'completed';
          final date = DateTime.tryParse(day?['date'] as String? ?? '');
          final isToday = date != null && _isSameDay(date, AppClock.now());
          final isPast = date != null && _isPastDay(date);
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: day == null || day['isRest'] == true
                ? null
                : () => _openDay(day),
            child: Container(
              width: 48,
              padding: EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                color: isToday
                    ? AppColors.primary.withValues(alpha: .28)
                    : isPast
                    ? AppColors.surface.withValues(alpha: .55)
                    : active
                    ? AppColors.primary.withValues(alpha: .1)
                    : AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isToday
                      ? AppColors.primary
                      : done
                      ? AppColors.primary
                      : AppColors.divider,
                  width: isToday ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  LocalizedText(
                    labels[index],
                    style: AppTextTheme.caption.copyWith(
                      color: isPast
                          ? AppColors.textMuted.withValues(alpha: .55)
                          : active || done || isToday
                          ? AppColors.primary
                          : AppColors.textMuted,
                    ),
                  ),
                  SizedBox(height: 4),
                  LocalizedText(
                    '${date?.day ?? index + 1}',
                    style: AppTextTheme.labelLarge.copyWith(
                      color: isPast
                          ? AppColors.textMuted.withValues(alpha: .55)
                          : done || isToday
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _dayCard(Map<String, dynamic> day) {
    final isRest = day['isRest'] == true;
    final status = day['status'] as String? ?? 'planned';
    final done = status == 'completed';
    final date = DateTime.tryParse(day['date'] as String? ?? '');
    final isPast = date != null && _isPastDay(date);
    final isToday = date != null && _isSameDay(date, AppClock.now());
    final color = isRest
        ? AppColors.textMuted
        : done
        ? AppColors.primary
        : AppColors.secondary;
    return Material(
      color: isPast
          ? AppColors.surfaceElevated.withValues(alpha: .55)
          : AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: isRest ? null : () => _openDay(day),
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isRest
                      ? Icons.bedtime_outlined
                      : done
                      ? Icons.check_rounded
                      : Icons.fitness_center_rounded,
                  color: color,
                ),
              ),
              SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LocalizedText(
                      day['dayName'] as String? ?? '',
                      style: AppTextTheme.titleMedium,
                    ),
                    SizedBox(height: 6),
                    LocalizedText(
                      isRest
                          ? 'Ngày nghỉ và phục hồi'
                          : '${day['exerciseCount'] ?? 0} bài tập',
                      style: AppTextTheme.bodySmall,
                    ),
                    if (!isRest) ...[
                      SizedBox(height: 10),
                      _statusPill(
                        _statusIcon(status),
                        _statusLabel(status),
                        color,
                      ),
                    ],
                    if (isToday) ...[
                      SizedBox(height: 7),
                      LocalizedText(
                        'Hôm nay',
                        style: AppTextTheme.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                    if (isPast) ...[
                      SizedBox(height: 7),
                      LocalizedText(
                        'Chỉ xem - ngày đã qua',
                        style: AppTextTheme.caption.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                    if (date != null && !isPast && !isToday) ...[
                      SizedBox(height: 7),
                      LocalizedText(
                        'Chưa đến ngày - chỉ xem trước',
                        style: AppTextTheme.caption.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!isRest)
                Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openSession(Map<String, dynamic> day) async {
    await Navigator.pushNamed(context, '/session', arguments: day);
    if (!mounted) return;
    setState(() => _schedule = WorkoutScheduleRepository.loadSchedule());
  }

  Future<void> _openDay(Map<String, dynamic> day) async {
    final date = DateTime.tryParse(day['date'] as String? ?? '');
    if (date == null || !_isPastDay(date)) {
      await _openSession(day);
      return;
    }
    final exercises = (day['exercises'] as List? ?? []);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LocalizedText(
                  'Lịch ngày ${date.day}/${date.month}/${date.year}',
                  style: AppTextTheme.headlineMedium,
                ),
                SizedBox(height: 6),
                LocalizedText(
                  'Ngày đã qua nên nội dung được khóa và chỉ có thể xem.',
                  style: AppTextTheme.bodySmall,
                ),
                SizedBox(height: 16),
                if (exercises.isEmpty)
                  LocalizedText(
                    'Ngày nghỉ và phục hồi',
                    style: AppTextTheme.bodyLarge,
                  )
                else
                  ...exercises.map((raw) {
                    final item = Map<String, dynamic>.from(raw as Map);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.fitness_center_rounded),
                      title: LocalizedText(
                        item['exerciseName'] as String? ?? '',
                      ),
                      subtitle: LocalizedText(
                        '${item['sets'] ?? 0} hiệp × ${item['reps'] ?? 0} lần',
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isPastDay(DateTime date) {
    final today = AppClock.now();
    return DateTime(
      date.year,
      date.month,
      date.day,
    ).isBefore(DateTime(today.year, today.month, today.day));
  }

  Widget _statusPill(IconData icon, String label, Color color) => Container(
    padding: EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        SizedBox(width: 5),
        Flexible(
          child: LocalizedText(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextTheme.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );

  String _statusLabel(String status) => switch (status) {
    'completed' => 'Hoàn thành',
    'in_progress' => 'Đang tập',
    _ => 'Đã lên lịch',
  };
  IconData _statusIcon(String status) => switch (status) {
    'completed' => Icons.check_circle_outline_rounded,
    'in_progress' => Icons.timelapse_rounded,
    _ => Icons.event_available_rounded,
  };
}
