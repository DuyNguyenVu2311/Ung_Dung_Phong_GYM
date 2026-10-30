import 'package:flutter/material.dart';

import '../services/app_localization.dart';

import '../models/data_models.dart';
import '../services/storage_service.dart';
import '../services/app_clock.dart';
import '../theme/app_theme.dart';
import '../widgets/modern_components.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = AppClock.now();
    _month = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    AppSettingsScope.watch(context);
    final sessions = StorageService.instance.loadWorkoutSessions()
      ..sort((a, b) => b.date.compareTo(a.date));
    final checkIns = StorageService.instance.loadDailyCheckIns();
    final monthSessions = sessions
        .where(
          (item) =>
              AppClock.inVietnam(item.date).year == _month.year &&
              AppClock.inVietnam(item.date).month == _month.month,
        )
        .toList();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: ModernAppBar(title: 'Lịch sử tập luyện'),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            _calendar(monthSessions),
            SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: _summary(
                    'Đã tập',
                    '${monthSessions.length} ngày',
                    Icons.fitness_center_rounded,
                    AppColors.primary,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _summary(
                    'Check-in thể trạng',
                    '${checkIns.where((item) => item.date.year == _month.year && item.date.month == _month.month).length} ngày',
                    Icons.monitor_heart_outlined,
                    AppColors.secondary,
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),
            LocalizedText('Các buổi tập', style: AppTextTheme.titleLarge),
            SizedBox(height: 12),
            if (monthSessions.isEmpty)
              EmptyState(
                icon: Icons.history_rounded,
                title: 'Chưa có buổi tập trong tháng',
                message: 'Buổi tập hoàn thành sẽ được hiển thị ở đây.',
              )
            else
              ...monthSessions.map(_sessionCard),
            SizedBox(height: 22),
            LocalizedText(
              'Lịch sử check-in thể trạng',
              style: AppTextTheme.titleLarge,
            ),
            SizedBox(height: 12),
            ...checkIns.take(10).map(_checkInCard),
          ],
        ),
      ),
    );
  }

  Widget _calendar(List<WorkoutSession> sessions) {
    final firstWeekday = DateTime(_month.year, _month.month, 1).weekday;
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final trainedDays = sessions
        .map((item) => AppClock.inVietnam(item.date).day)
        .toSet();
    final totalCells = firstWeekday - 1 + daysInMonth;
    final rows = (totalCells / 7).ceil();
    return GlassCard(
      padding: EdgeInsets.all(17),
      borderRadius: 22,
      color: AppColors.surfaceElevated,
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => setState(
                  () => _month = DateTime(_month.year, _month.month - 1),
                ),
                icon: Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: LocalizedText(
                  'Tháng ${_month.month}/${_month.year}',
                  textAlign: TextAlign.center,
                  style: AppTextTheme.titleLarge,
                ),
              ),
              IconButton(
                onPressed: () => setState(
                  () => _month = DateTime(_month.year, _month.month + 1),
                ),
                icon: Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          SizedBox(height: 10),
          Row(
            children: ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']
                .map(
                  (label) => Expanded(
                    child: LocalizedText(
                      label,
                      textAlign: TextAlign.center,
                      style: AppTextTheme.caption,
                    ),
                  ),
                )
                .toList(),
          ),
          SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: rows * 7,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 5,
              crossAxisSpacing: 5,
            ),
            itemBuilder: (_, index) {
              final day = index - (firstWeekday - 2);
              if (day < 1 || day > daysInMonth) return SizedBox.shrink();
              final date = DateTime(_month.year, _month.month, day);
              final trained = trainedDays.contains(day);
              final today = _sameDay(date, AppClock.now());
              final now = AppClock.now();
              final past = date.isBefore(
                DateTime(now.year, now.month, now.day),
              );
              return Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: trained
                      ? AppColors.secondary
                      : past
                      ? AppColors.surface.withValues(alpha: .45)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: today ? AppColors.primary : Colors.transparent,
                    width: today ? 2 : 1,
                  ),
                ),
                child: LocalizedText(
                  '$day',
                  style: AppTextTheme.caption.copyWith(
                    color: trained
                        ? AppColors.textInverse
                        : past
                        ? AppColors.textMuted
                        : AppColors.textPrimary,
                    fontWeight: today || trained
                        ? FontWeight.w800
                        : FontWeight.w500,
                  ),
                ),
              );
            },
          ),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legend(AppColors.secondary, 'Đã tập'),
              SizedBox(width: 16),
              _legend(AppColors.primary, 'Hôm nay', outline: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sessionCard(WorkoutSession session) {
    final time = AppClock.inVietnam(session.checkedInAt ?? session.date);
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: EdgeInsets.all(16),
        borderRadius: 18,
        color: AppColors.surfaceElevated,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: LocalizedText(
                    session.dayName,
                    style: AppTextTheme.titleMedium,
                  ),
                ),
                LocalizedText(
                  _date(AppClock.inVietnam(session.date)),
                  style: AppTextTheme.caption,
                ),
              ],
            ),
            SizedBox(height: 10),
            _detail(Icons.schedule_rounded, _time(time)),
            _detail(Icons.location_on_outlined, session.branchName),
            _detail(
              Icons.fitness_center_rounded,
              '${session.logs.length} bài tập',
            ),
          ],
        ),
      ),
    );
  }

  Widget _checkInCard(DailyCheckIn checkIn) => Padding(
    padding: EdgeInsets.only(bottom: 10),
    child: GlassCard(
      padding: EdgeInsets.all(14),
      borderRadius: 16,
      color: AppColors.surfaceElevated,
      child: Row(
        children: [
          Icon(Icons.monitor_heart_outlined, color: AppColors.primary),
          SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LocalizedText(
                  _date(checkIn.date),
                  style: AppTextTheme.titleMedium,
                ),
                LocalizedText(
                  checkIn.trainingDecision,
                  style: AppTextTheme.bodySmall,
                ),
              ],
            ),
          ),
          LocalizedText(
            '${checkIn.readinessScore}%',
            style: AppTextTheme.labelLarge,
          ),
        ],
      ),
    ),
  );

  Widget _summary(String label, String value, IconData icon, Color color) =>
      GlassCard(
        padding: EdgeInsets.all(14),
        borderRadius: 17,
        color: AppColors.surfaceElevated,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            SizedBox(height: 10),
            LocalizedText(value, style: AppTextTheme.titleMedium),
            LocalizedText(label, style: AppTextTheme.caption),
          ],
        ),
      );

  Widget _detail(IconData icon, String text) => Padding(
    padding: EdgeInsets.only(top: 6),
    child: Row(
      children: [
        Icon(icon, size: 17, color: AppColors.secondary),
        SizedBox(width: 8),
        Expanded(child: LocalizedText(text, style: AppTextTheme.bodySmall)),
      ],
    ),
  );

  Widget _legend(Color color, String label, {bool outline = false}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: outline ? Colors.transparent : color,
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      SizedBox(width: 6),
      LocalizedText(label, style: AppTextTheme.caption),
    ],
  );

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
