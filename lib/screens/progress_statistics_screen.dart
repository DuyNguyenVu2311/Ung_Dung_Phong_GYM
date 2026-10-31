import 'package:flutter/material.dart';

import '../services/app_localization.dart';
import '../services/app_clock.dart';
import '../models/data_models.dart';
import '../services/storage_service.dart';
import '../services/cloud_sync_service.dart';
import '../theme/app_theme.dart';

class ProgressStatisticsScreen extends StatefulWidget {
  const ProgressStatisticsScreen({super.key});

  @override
  State<ProgressStatisticsScreen> createState() =>
      _ProgressStatisticsScreenState();
}

class _WeightTrendPainter extends CustomPainter {
  const _WeightTrendPainter(this.measurements);

  final List<BodyMeasurement> measurements;

  @override
  void paint(Canvas canvas, Size size) {
    if (measurements.length < 2) return;
    final values = measurements.map((item) => item.weight).toList();
    var minValue = values.reduce((a, b) => a < b ? a : b);
    var maxValue = values.reduce((a, b) => a > b ? a : b);
    if ((maxValue - minValue).abs() < .1) {
      minValue -= 1;
      maxValue += 1;
    }
    final line = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x5567E0B1), Color(0x0067E0B1)],
      ).createShader(Offset.zero & size);
    final grid = Paint()
      ..color = AppColors.divider
      ..strokeWidth = 1;
    for (var i = 0; i < 3; i++) {
      final y = size.height * i / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    Offset pointAt(int index) {
      final x = size.width * index / (values.length - 1);
      final ratio = (values[index] - minValue) / (maxValue - minValue);
      return Offset(x, size.height - ratio * (size.height - 12) - 6);
    }

    final path = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (var index = 1; index < values.length; index++) {
      final point = pointAt(index);
      path.lineTo(point.dx, point.dy);
    }
    final area = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(area, fill);
    canvas.drawPath(path, line);
    final dot = Paint()..color = AppColors.primary;
    for (var index = 0; index < values.length; index++) {
      canvas.drawCircle(pointAt(index), 4, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _WeightTrendPainter oldDelegate) =>
      oldDelegate.measurements != measurements;
}

class _ProgressStatisticsScreenState extends State<ProgressStatisticsScreen> {
  late List<BodyMeasurement> _measurements;

  @override
  void initState() {
    super.initState();
    _measurements = StorageService.instance.loadBodyMeasurements();
  }

  @override
  Widget build(BuildContext context) {
    AppSettingsScope.watch(context);
    final sessions = StorageService.instance.loadWorkoutSessions();
    final profile = StorageService.instance.loadProfile();
    final today = AppClock.today;
    final weekStart = DateTime(
      today.year,
      today.month,
      today.day - (today.weekday - 1),
    );
    final weekEnd = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day + 7,
    );

    final volumes = List<double>.filled(7, 0);
    var totalVolume = 0.0;

    for (final session in sessions) {
      final volume = session.logs.fold<double>(
        0,
        (sum, log) => sum + log.sets * log.reps * log.weight,
      );

      // Tổng khối lượng vẫn tính toàn bộ lịch sử.
      totalVolume += volume;

      // Biểu đồ dùng ngày Việt Nam, từ thứ Hai đến hết Chủ nhật.
      final performedDay = AppClock.day(AppClock.inVietnam(session.date));
      if (performedDay.isBefore(weekStart) || !performedDay.isBefore(weekEnd)) {
        continue;
      }

      volumes[performedDay.weekday - 1] += volume;
    }
    final maxVolume = volumes.fold<double>(
      1,
      (max, value) => value > max ? value : max,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: LocalizedText('Tiến độ của bạn')),
      body: ListView(
        physics: BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20, 10, 20, 30),
        children: [
          Container(
            padding: EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: AppGradients.primary,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LocalizedText(
                        'Bạn đang tiến bộ',
                        style: AppTextTheme.headlineMedium.copyWith(
                          color: AppColors.textInverse,
                        ),
                      ),
                      SizedBox(height: 7),
                      LocalizedText(
                        '${sessions.length} buổi đã ghi nhận',
                        style: AppTextTheme.bodyMedium.copyWith(
                          color: AppColors.textInverse.withValues(alpha: .75),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.trending_up_rounded,
                  color: AppColors.textInverse,
                  size: 54,
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _stat(
                  'Tổng khối lượng',
                  '${(totalVolume / 1000).toStringAsFixed(1)} tấn',
                  Icons.fitness_center_rounded,
                  AppColors.primary,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _stat(
                  'BMI hiện tại',
                  profile?.bmi.toStringAsFixed(1) ?? '--',
                  Icons.monitor_weight_outlined,
                  AppColors.secondary,
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          _weightProgress(profile),
          SizedBox(height: 24),
          LocalizedText(
            'Khối lượng tập trong tuần',
            style: AppTextTheme.titleLarge,
          ),
          SizedBox(height: 6),
          LocalizedText(
            'Tổng sets × reps × mức tạ theo từng ngày',
            style: AppTextTheme.bodySmall,
          ),
          SizedBox(height: 14),
          Container(
            height: 250,
            padding: EdgeInsets.fromLTRB(18, 22, 18, 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (index) {
                final ratio = volumes[index] / maxVolume;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 5),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (volumes[index] > 0)
                          LocalizedText(
                            '${(volumes[index] / 1000).toStringAsFixed(1)}k',
                            style: AppTextTheme.caption,
                          ),
                        SizedBox(height: 5),
                        AnimatedContainer(
                          duration: Duration(milliseconds: 400),
                          height: 24 + ratio * 140,
                          decoration: BoxDecoration(
                            gradient: ratio > 0 ? AppGradients.primary : null,
                            color: ratio == 0 ? AppColors.divider : null,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        SizedBox(height: 9),
                        LocalizedText(
                          ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'][index],
                          style: AppTextTheme.caption,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          SizedBox(height: 24),
          LocalizedText('Thành tích gần đây', style: AppTextTheme.titleLarge),
          SizedBox(height: 12),
          if (sessions.isEmpty)
            Container(
              padding: EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(22),
              ),
              child: LocalizedText(
                'Hoàn thành buổi tập đầu tiên để xem thành tích tại đây.',
              ),
            )
          else
            ...sessions.reversed.take(3).map(_sessionTile),
        ],
      ),
    );
  }

  Widget _weightProgress(UserProfile? profile) {
    final latest = _measurements.isNotEmpty
        ? _measurements.last.weight
        : profile?.weight;
    final first = _measurements.isNotEmpty
        ? _measurements.first.weight
        : profile?.weight;
    final change = latest != null && first != null ? latest - first : null;
    final recent = _measurements.length > 8
        ? _measurements.sublist(_measurements.length - 8)
        : _measurements;

    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LocalizedText('Cân nặng', style: AppTextTheme.titleLarge),
                    SizedBox(height: 4),
                    LocalizedText(
                      latest == null
                          ? 'Chưa có dữ liệu'
                          : '${latest.toStringAsFixed(1)} kg',
                      style: AppTextTheme.headlineLarge,
                    ),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: _showAddMeasurement,
                icon: Icon(Icons.add_rounded),
                label: LocalizedText('Ghi cân nặng'),
              ),
            ],
          ),
          SizedBox(height: 16),
          if (recent.length < 2)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceBright,
                borderRadius: BorderRadius.circular(16),
              ),
              child: LocalizedText(
                'Ghi ít nhất 2 lần để xem xu hướng thay đổi.',
                style: AppTextTheme.bodySmall,
              ),
            )
          else ...[
            SizedBox(
              height: 112,
              width: double.infinity,
              child: CustomPaint(painter: _WeightTrendPainter(recent)),
            ),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                LocalizedText(
                  '${recent.first.date.day}/${recent.first.date.month}',
                  style: AppTextTheme.caption,
                ),
                LocalizedText(
                  change == null
                      ? '--'
                      : '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)} kg từ lần đầu',
                  style: AppTextTheme.labelMedium.copyWith(
                    color: change != null && change.abs() < .1
                        ? AppColors.textSecondary
                        : AppColors.primary,
                  ),
                ),
                LocalizedText(
                  '${recent.last.date.day}/${recent.last.date.month}',
                  style: AppTextTheme.caption,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showAddMeasurement() async {
    final initial = _measurements.isNotEmpty
        ? _measurements.last.weight
        : StorageService.instance.loadProfile()?.weight;
    final controller = TextEditingController(
      text: initial?.toStringAsFixed(1) ?? '',
    );
    String? error;
    final value = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surfaceElevated,
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
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LocalizedText(
                  'Ghi cân nặng',
                  style: AppTextTheme.headlineMedium,
                ),
                SizedBox(height: 6),
                LocalizedText(
                  'Nên cân cùng một thời điểm trong ngày để dữ liệu nhất quán.',
                  style: AppTextTheme.bodySmall,
                ),
                SizedBox(height: 18),
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: tr('Cân nặng'),
                    suffixText: 'kg',
                    errorText: error,
                  ),
                ),
                SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: Size.fromHeight(54),
                    ),
                    onPressed: () {
                      final parsed = double.tryParse(
                        controller.text.trim().replaceAll(',', '.'),
                      );
                      if (parsed == null || parsed < 20 || parsed > 400) {
                        setModalState(
                          () => error = 'Nhập cân nặng từ 20 đến 400 kg',
                        );
                        return;
                      }
                      Navigator.pop(context, parsed);
                    },
                    child: LocalizedText('Lưu số đo'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (value == null) return;
    final measurement = BodyMeasurement(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      date: DateTime.now(),
      weight: value,
    );
    await StorageService.instance.addBodyMeasurement(measurement);
    await CloudSyncService.instance.syncNow();
    if (!mounted) return;
    setState(
      () => _measurements = StorageService.instance.loadBodyMeasurements(),
    );
  }

  Widget _stat(String label, String value, IconData icon, Color color) =>
      Container(
        padding: EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(21),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            SizedBox(height: 14),
            LocalizedText(value, style: AppTextTheme.titleLarge),
            SizedBox(height: 3),
            LocalizedText(label, style: AppTextTheme.caption),
          ],
        ),
      );

  Widget _sessionTile(WorkoutSession session) => Container(
    margin: EdgeInsets.only(bottom: 10),
    padding: EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(19),
    ),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: .13),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check_rounded, color: AppColors.primary),
        ),
        SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LocalizedText(session.dayName, style: AppTextTheme.titleMedium),
              LocalizedText(
                '${session.logs.length} bài · ${session.date.day}/${session.date.month}',
                style: AppTextTheme.bodySmall,
              ),
            ],
          ),
        ),
        Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
      ],
    ),
  );
}
