import 'dart:async';

import 'package:flutter/material.dart';

import '../services/app_localization.dart';

import '../models/data_models.dart';
import '../repositories/workout_schedule_repository.dart';
import '../services/storage_service.dart';
import '../services/cloud_sync_service.dart';
import '../theme/app_theme.dart';
import '../widgets/modern_components.dart';
import 'history_screen.dart';
import 'notifications_screen.dart';
import 'promotions_screen.dart';
import 'settings_screen.dart';
import '../services/app_clock.dart';
import '../widgets/live_clock.dart';

class HomeScreen extends StatefulWidget {
  final ValueChanged<int>? onTabSelected;

  const HomeScreen({super.key, this.onTabSelected});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  UserProfile? _profile;
  DailyCheckIn? _checkIn;
  List<Map<String, dynamic>> _schedule = [];
  int _completed = 0;
  late final Timer _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addObserver(this);
    _refreshSchedule();
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _refreshSchedule(),
    );
  }

  Future<void> _refreshSchedule() async {
    await WorkoutScheduleRepository.ensureCurrentWeek();
    if (mounted) setState(_load);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshSchedule();
  }

  @override
  void dispose() {
    _refreshTimer.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _load() {
    _profile =
        StorageService.instance.loadProfile() ??
        UserProfile(
          name: 'Bạn',
          age: 22,
          height: 170,
          weight: 70,
          gender: 'Nam',
          goal: 'muscle',
          experienceLevel: 'beginner',
          sessionsPerWeek: 3,
        );
    _schedule = WorkoutScheduleRepository.loadSchedule();
    _checkIn = StorageService.instance.loadTodayCheckIn();
    _completed = _schedule.where((e) => e['status'] == 'completed').length;
  }

  void _openTab(int index, String fallbackRoute) {
    final callback = widget.onTabSelected;
    callback != null
        ? callback(index)
        : Navigator.pushNamed(context, fallbackRoute);
  }

  String get _greeting {
    final hour = AppClock.now().hour;
    if (hour < 11) return 'Chào buổi sáng';
    if (hour < 18) return 'Chào buổi chiều';
    return 'Chào buổi tối';
  }

  String _goalLabel(String goal) => switch (goal) {
    'fatloss' => 'Giảm mỡ & thon gọn',
    'mobility' => 'Xương khớp linh hoạt',
    'home' => 'Tập nhanh tại nhà',
    'cardio' => 'Sức bền & tim mạch',
    _ => 'Tăng cơ & sức mạnh',
  };

  Map<String, dynamic>? get _nextWorkout {
    final today = AppClock.today;
    for (final day in _schedule) {
      final date = DateTime.tryParse(day['date'] as String? ?? '');
      if (date != null &&
          !AppClock.day(date).isBefore(today) &&
          day['isRest'] != true &&
          day['status'] != 'completed') {
        return day;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    AppSettingsScope.watch(context);
    final profile = _profile;
    if (profile == null) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final planned = _schedule.where((e) => e['isRest'] != true).length;
    final progress = planned == 0
        ? 0.0
        : (_completed / planned).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshSchedule,
          child: CustomScrollView(
            physics: AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                sliver: SliverToBoxAdapter(child: _header(profile)),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 6, 20, 6),
                sliver: SliverToBoxAdapter(child: LiveClock()),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
                sliver: SliverToBoxAdapter(child: _workoutHero(profile)),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 18, 20, 0),
                sliver: SliverToBoxAdapter(child: _readinessCard()),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _weeklyProgress(progress, planned),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
                sliver: SliverToBoxAdapter(child: _quickActions()),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    children: [
                      Card(
                        child: ListTile(
                          leading: Icon(Icons.calendar_month_outlined),
                          title: LocalizedText('Lịch sử check-in'),
                          subtitle: LocalizedText(
                            'Xem lịch, buổi tập và giờ check-in',
                          ),
                          trailing: Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => HistoryScreen(),
                            ),
                          ),
                        ),
                      ),
                      Card(
                        child: ListTile(
                          leading: Icon(Icons.local_offer_outlined),
                          title: LocalizedText('Chương trình khuyến mãi'),
                          trailing: Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => PromotionsScreen(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 24, 20, 28),
                sliver: SliverToBoxAdapter(child: _insightCard(profile)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(UserProfile profile) => Row(
    children: [
      Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          gradient: AppGradients.primary,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(
          child: LocalizedText(
            profile.name.isEmpty ? 'B' : profile.name[0].toUpperCase(),
            style: AppTextTheme.headlineMedium.copyWith(
              color: AppColors.textInverse,
            ),
          ),
        ),
      ),
      SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LocalizedText(_greeting, style: AppTextTheme.bodySmall),
            SizedBox(height: 2),
            LocalizedText(
              profile.name,
              style: AppTextTheme.headlineMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      IconButton.filledTonal(
        tooltip: tr('Thông báo'),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => NotificationsScreen()),
          );
          if (mounted) setState(_load);
        },
        icon: Badge(
          isLabelVisible: StorageService.instance.loadNotices().any(
            (notice) => !notice.read,
          ),
          label: Text(
            '${StorageService.instance.loadNotices().where((notice) => !notice.read).length}',
          ),
          child: Icon(Icons.notifications_none_rounded),
        ),
      ),
      IconButton(
        tooltip: tr('Cài đặt'),
        icon: Icon(Icons.settings_outlined),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => SettingsScreen()),
        ),
      ),
    ],
  );

  Widget _workoutHero(UserProfile profile) {
    final workout = _nextWorkout;
    final exercises = workout?['exercises'] as List? ?? [];
    final names = exercises
        .take(3)
        .map((e) => (e as Map)['exerciseName'] as String? ?? '')
        .where((e) => e.isNotEmpty)
        .join(' • ');
    return Container(
      padding: EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.surfaceBright,
            AppColors.surfaceElevated,
            AppColors.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.primary.withValues(alpha: .35)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: .12),
            blurRadius: 30,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _pill(
                Icons.auto_awesome_rounded,
                'Dành cho bạn',
                AppColors.primary,
              ),
              LocalizedText(
                _goalLabel(profile.goal),
                style: AppTextTheme.caption,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          SizedBox(height: 22),
          LocalizedText(
            workout?['dayName'] as String? ??
                (_schedule.isEmpty
                    ? 'Sẵn sàng cho buổi tập mới?'
                    : 'Nghỉ ngơi và phục hồi'),
            style: AppTextTheme.headlineLarge,
          ),
          if (workout != null)
            LocalizedText(
              AppClock.date(DateTime.parse(workout['date'] as String)),
              style: AppTextTheme.caption,
            ),
          SizedBox(height: 8),
          LocalizedText(
            names.isEmpty
                ? (_schedule.isEmpty
                      ? 'Tạo lịch tập cá nhân để bắt đầu hành trình khỏe mạnh.'
                      : 'Không còn buổi tập sắp tới trong tuần. Lịch tuần mới sẽ cập nhật tự động.')
                : names,
            style: AppTextTheme.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _metric(Icons.schedule_rounded, '${exercises.length * 10} phút'),
              _metric(Icons.fitness_center_rounded, '${exercises.length} bài'),
            ],
          ),
          SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textInverse,
                minimumSize: Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
              onPressed: workout == null
                  ? () => _openTab(1, '/schedule')
                  : () => Navigator.pushNamed(
                      context,
                      '/session',
                      arguments: workout,
                    ),
              icon: Icon(Icons.play_arrow_rounded, size: 26),
              label: LocalizedText(
                workout == null
                    ? (_schedule.isEmpty ? 'Tạo lịch tập' : 'Xem lịch tập')
                    : 'Bắt đầu ngay',
                style: AppTextTheme.labelLarge.copyWith(
                  color: AppColors.textInverse,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _readinessCard() {
    final checkIn = _checkIn;
    final score = checkIn?.readinessScore;
    final color = checkIn?.shouldRest == true
        ? AppColors.error
        : score == null
        ? AppColors.secondary
        : score >= 75
        ? AppColors.primary
        : score >= 50
        ? AppColors.warning
        : AppColors.accent;
    return Material(
      color: AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: _showDailyCheckIn,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: EdgeInsets.all(17),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(
                  checkIn == null
                      ? Icons.monitor_heart_outlined
                      : Icons.bolt_rounded,
                  color: color,
                ),
              ),
              SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LocalizedText(
                      checkIn == null
                          ? 'Hôm nay cơ thể bạn thế nào?'
                          : '${checkIn.recommendation} · $score%',
                      style: AppTextTheme.titleMedium,
                    ),
                    SizedBox(height: 4),
                    LocalizedText(
                      checkIn == null
                          ? 'Check-in 20 giây để điều chỉnh buổi tập hợp lý.'
                          : '${checkIn.availableMinutes} phút sẵn có · Chạm để cập nhật',
                      style: AppTextTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDailyCheckIn() async {
    var energy = _checkIn?.energy ?? 3;
    var soreness = _checkIn?.soreness ?? 2;
    var sleep = _checkIn?.sleepQuality ?? 3;
    var minutes = _checkIn?.availableMinutes ?? 45;
    final result = await showModalBottomSheet<DailyCheckIn>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceElevated,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              4,
              20,
              20 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                LocalizedText(
                  'Check-in thể trạng',
                  style: AppTextTheme.headlineMedium,
                ),
                SizedBox(height: 6),
                LocalizedText(
                  'Không phải ngày nào cũng cần tập hết sức.',
                  style: AppTextTheme.bodySmall,
                ),
                SizedBox(height: 20),
                _checkInSlider('Năng lượng', Icons.bolt_rounded, energy, [
                  'Kiệt sức',
                  'Mệt',
                  'Bình thường',
                  'Khỏe',
                  'Rất sung sức',
                ], (value) => setModalState(() => energy = value)),
                _checkInSlider(
                  'Đau mỏi cơ',
                  Icons.healing_rounded,
                  soreness,
                  [
                    'Không đau',
                    'Hơi căng',
                    'Đau nhẹ',
                    'Đau nhiều',
                    'Đau bất thường',
                  ],
                  (value) => setModalState(() => soreness = value),
                  higherIsBetter: false,
                ),
                _checkInSlider(
                  'Chất lượng ngủ',
                  Icons.bedtime_outlined,
                  sleep,
                  ['Rất kém', 'Kém', 'Tạm ổn', 'Ngủ tốt', 'Ngủ rất tốt'],
                  (value) => setModalState(() => sleep = value),
                ),
                SizedBox(height: 8),
                LocalizedText(
                  'Thời gian bạn có thể dành hôm nay',
                  style: AppTextTheme.titleMedium,
                ),
                LocalizedText(
                  'Đây là thời gian bạn có, không phải thời lượng bắt buộc phải tập.',
                  style: AppTextTheme.caption,
                ),
                SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [45, 60, 75, 90]
                      .map(
                        (value) => ChoiceChip(
                          selected: minutes == value,
                          label: LocalizedText('$value phút'),
                          onSelected: (_) =>
                              setModalState(() => minutes = value),
                        ),
                      )
                      .toList(),
                ),
                SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: Size.fromHeight(54),
                    ),
                    onPressed: () => Navigator.pop(
                      context,
                      DailyCheckIn(
                        date: AppClock.now(),
                        energy: energy,
                        soreness: soreness,
                        sleepQuality: sleep,
                        availableMinutes: minutes,
                      ),
                    ),
                    child: LocalizedText('Lưu check-in hôm nay'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result == null) return;
    await StorageService.instance.saveDailyCheckIn(result);
    await CloudSyncService.instance.syncNow();
    if (!mounted) return;
    setState(() => _checkIn = result);
    await _showCheckInPlan(result);
  }

  Widget _checkInSlider(
    String label,
    IconData icon,
    int value,
    List<String> descriptions,
    ValueChanged<int> onChanged, {
    bool higherIsBetter = true,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          SizedBox(width: 8),
          Expanded(
            child: LocalizedText(label, style: AppTextTheme.titleMedium),
          ),
          LocalizedText('Mức $value', style: AppTextTheme.caption),
        ],
      ),
      Slider(
        value: value.toDouble(),
        min: 1,
        max: 5,
        divisions: 4,
        activeColor: _checkInColor(value, higherIsBetter),
        thumbColor: _checkInColor(value, higherIsBetter),
        label: tr(descriptions[value - 1]),
        onChanged: (newValue) => onChanged(newValue.round()),
      ),
      AnimatedSwitcher(
        duration: Duration(milliseconds: 180),
        child: LocalizedText(
          descriptions[value - 1],
          key: ValueKey('$label-$value'),
          style: AppTextTheme.caption.copyWith(
            color: _checkInColor(value, higherIsBetter),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: LocalizedText(
              '1 · ${descriptions.first}',
              style: AppTextTheme.caption,
            ),
          ),
          Expanded(
            child: LocalizedText(
              '5 · ${descriptions.last}',
              style: AppTextTheme.caption,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
      SizedBox(height: 6),
    ],
  );

  Color _checkInColor(int value, bool higherIsBetter) {
    final favorable = higherIsBetter ? value : 6 - value;
    return favorable <= 2
        ? AppColors.error
        : favorable == 3
        ? AppColors.warning
        : AppColors.primary;
  }

  Future<void> _showCheckInPlan(DailyCheckIn checkIn) async {
    final shouldRest = checkIn.suggestedMinutes == 0;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceElevated,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      shouldRest
                          ? Icons.bedtime_rounded
                          : Icons.task_alt_rounded,
                      color: shouldRest ? AppColors.warning : AppColors.primary,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: LocalizedText(
                        shouldRest
                            ? 'Hôm nay nên nghỉ tập'
                            : 'Kế hoạch hôm nay',
                        style: AppTextTheme.headlineMedium,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                LocalizedText(
                  checkIn.trainingDecision,
                  style: AppTextTheme.bodyLarge,
                ),
                SizedBox(height: 14),
                _planRow('Mức sẵn sàng', '${checkIn.readinessScore}%'),
                _planRow(
                  'Thời lượng khuyến nghị',
                  shouldRest
                      ? 'Không xếp buổi tập'
                      : '${checkIn.suggestedMinutes} phút',
                ),
                _planRow(
                  'Cường độ',
                  shouldRest
                      ? 'Ưu tiên nghỉ ngơi'
                      : checkIn.recoveryOnly
                      ? 'Phục hồi nhẹ'
                      : checkIn.readinessScore >= 75
                      ? 'Theo kế hoạch'
                      : 'Cường độ vừa',
                ),
                SizedBox(height: 12),
                LocalizedText(
                  'Nếu bạn đau bất thường, chóng mặt, khó thở hoặc kiệt sức, hãy dừng tập và tìm tư vấn y tế.',
                  style: AppTextTheme.caption,
                ),
                SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: LocalizedText('Đã hiểu'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _planRow(String label, String value) => Padding(
    padding: EdgeInsets.only(bottom: 9),
    child: Row(
      children: [
        Expanded(child: LocalizedText(label, style: AppTextTheme.bodySmall)),
        Expanded(
          child: LocalizedText(
            value,
            style: AppTextTheme.labelLarge,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    ),
  );

  Widget _weeklyProgress(double progress, int planned) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionHeader(title: 'Tiến độ tuần này'),
      SizedBox(height: 12),
      GlassCard(
        padding: EdgeInsets.all(18),
        borderRadius: 22,
        color: AppColors.surfaceElevated,
        child: Row(
          children: [
            SizedBox(
              width: 84,
              height: 84,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 9,
                      strokeCap: StrokeCap.round,
                      backgroundColor: AppColors.divider,
                      valueColor: AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  ),
                  LocalizedText(
                    '${(progress * 100).round()}%',
                    style: AppTextTheme.titleLarge,
                  ),
                ],
              ),
            ),
            SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LocalizedText(
                    '$_completed/$planned buổi hoàn thành',
                    style: AppTextTheme.titleMedium,
                  ),
                  SizedBox(height: 6),
                  LocalizedText(
                    progress >= .7
                        ? 'Tuyệt vời! Bạn đang giữ nhịp rất tốt.'
                        : 'Mỗi buổi tập là một bước tiến nhỏ.',
                    style: AppTextTheme.bodySmall,
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: List.generate(
                      7,
                      (index) => Expanded(
                        child: Container(
                          height: 7,
                          margin: EdgeInsets.only(right: index == 6 ? 0 : 5),
                          decoration: BoxDecoration(
                            color: index < _completed
                                ? AppColors.primary
                                : AppColors.divider,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _quickActions() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionHeader(title: 'Khám phá nhanh'),
      SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _actionCard(
              Icons.calendar_month_rounded,
              'Lịch tập',
              'Xem tuần này',
              AppColors.secondary,
              () => _openTab(1, '/schedule'),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: _actionCard(
              Icons.directions_run_rounded,
              'Bài tập',
              'Hướng dẫn chuẩn',
              AppColors.primary,
              () => _openTab(2, '/library'),
            ),
          ),
        ],
      ),
      SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _actionCard(
              Icons.insights_rounded,
              'Thống kê',
              'Xem tiến bộ',
              AppColors.accentPurple,
              () => Navigator.pushNamed(context, '/stats'),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: _actionCard(
              Icons.history_rounded,
              'Lịch sử',
              'Buổi đã tập',
              AppColors.warning,
              () => Navigator.pushNamed(context, '/history'),
            ),
          ),
        ],
      ),
    ],
  );

  Widget _actionCard(
    IconData icon,
    String title,
    String subtitle,
    Color color,
    VoidCallback onTap,
  ) => Material(
    color: AppColors.surfaceElevated,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color),
            ),
            SizedBox(height: 14),
            LocalizedText(title, style: AppTextTheme.titleMedium),
            SizedBox(height: 3),
            LocalizedText(subtitle, style: AppTextTheme.caption),
          ],
        ),
      ),
    ),
  );

  Widget _insightCard(UserProfile profile) => Container(
    padding: EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.secondary.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppColors.secondary.withValues(alpha: .22)),
    ),
    child: Row(
      children: [
        Icon(
          Icons.lightbulb_outline_rounded,
          color: AppColors.secondary,
          size: 28,
        ),
        SizedBox(width: 14),
        Expanded(
          child: LocalizedText(
            'BMI ${profile.bmi.toStringAsFixed(1)} · ${profile.bmiLabel}. Hãy ưu tiên ngủ đủ và tăng mức tạ từ từ.',
            style: AppTextTheme.bodySmall,
          ),
        ),
      ],
    ),
  );

  Widget _pill(IconData icon, String label, Color color) => Container(
    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        SizedBox(width: 6),
        LocalizedText(
          label,
          style: AppTextTheme.caption.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  Widget _metric(IconData icon, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 18, color: AppColors.textSecondary),
      SizedBox(width: 6),
      LocalizedText(label, style: AppTextTheme.bodySmall),
    ],
  );
}
