import 'package:flutter/material.dart';

import '../services/app_localization.dart';

import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class GoalScreen extends StatefulWidget {
  const GoalScreen({super.key});

  @override
  State<GoalScreen> createState() => _GoalScreenState();
}

class _GoalScreenState extends State<GoalScreen> {
  String _selected = 'fatloss';

  static List<(String, String, String, IconData, Color)> get _goals => [
    (
      'fatloss',
      'Giảm mỡ & thon gọn',
      'Tập toàn thân, đốt năng lượng bền vững',
      Icons.local_fire_department_rounded,
      AppColors.accent,
    ),
    (
      'muscle',
      'Tăng cơ & sức mạnh',
      'Phát triển cơ bắp với lộ trình tăng tiến',
      Icons.fitness_center_rounded,
      AppColors.primary,
    ),
    (
      'mobility',
      'Xương khớp linh hoạt',
      'Giảm đau mỏi, phù hợp dân văn phòng và 40+',
      Icons.self_improvement_rounded,
      AppColors.secondary,
    ),
    (
      'home',
      'Tập nhanh tại nhà',
      '20 phút, ít hoặc không cần dụng cụ',
      Icons.home_work_outlined,
      AppColors.warning,
    ),
    (
      'cardio',
      'Sức bền & tim mạch',
      'Khỏe hơn mỗi ngày với bài tập nhịp tim',
      Icons.favorite_rounded,
      AppColors.error,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    AppSettingsScope.watch(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: LocalizedText('Mục tiêu của bạn')),
      bottomNavigationBar: SafeArea(
        minimum: EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: Size.fromHeight(56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          onPressed: () async {
            await StorageService.instance.saveGoal(_selected);
            if (context.mounted) {
              Navigator.pushReplacementNamed(context, '/level');
            }
          },
          child: LocalizedText('Tiếp tục'),
        ),
      ),
      body: ListView(
        physics: BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20, 10, 20, 28),
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppGradients.surface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: AppGradients.primary,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(Icons.flag_rounded, color: AppColors.textInverse),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LocalizedText(
                        'Bạn muốn thay đổi điều gì?',
                        style: AppTextTheme.titleLarge,
                      ),
                      SizedBox(height: 5),
                      LocalizedText(
                        'Chọn mục tiêu gần với cuộc sống của bạn nhất.',
                        style: AppTextTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
          ..._goals.map((goal) => _goalCard(goal)),
        ],
      ),
    );
  }

  Widget _goalCard((String, String, String, IconData, Color) goal) {
    final (id, title, subtitle, icon, color) = goal;
    final active = id == _selected;
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Material(
        color: active
            ? color.withValues(alpha: .12)
            : AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: () => setState(() => _selected = id),
          borderRadius: BorderRadius.circular(22),
          child: AnimatedContainer(
            duration: Duration(milliseconds: 180),
            constraints: BoxConstraints(minHeight: 98),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: active ? color : AppColors.divider,
                width: active ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Icon(icon, color: color, size: 27),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LocalizedText(
                        title,
                        style: AppTextTheme.titleMedium.copyWith(
                          color: active ? color : AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 5),
                      LocalizedText(subtitle, style: AppTextTheme.bodySmall),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                AnimatedContainer(
                  duration: Duration(milliseconds: 180),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active ? color : Colors.transparent,
                    border: Border.all(
                      color: active ? color : AppColors.textMuted,
                      width: 2,
                    ),
                  ),
                  child: active
                      ? Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: AppColors.textInverse,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
