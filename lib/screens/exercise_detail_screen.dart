import 'package:flutter/material.dart';

import '../services/app_localization.dart';
import '../services/app_clock.dart';

import '../models/data_models.dart';
import '../theme/app_theme.dart';
import '../widgets/modern_components.dart';

class ExerciseDetailScreen extends StatelessWidget {
  const ExerciseDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    AppSettingsScope.watch(context);
    final exercise = ModalRoute.of(context)?.settings.arguments as Exercise?;
    if (exercise == null) {
      return Scaffold(
        body: Center(child: LocalizedText('Không tìm thấy bài tập')),
      );
    }
    final color = _muscleColor(exercise.muscleGroup);
    final steps = exercise.instructions.isEmpty
        ? [
            'Chuẩn bị tư thế vững và giữ lưng trung lập.',
            'Thực hiện chậm, thở ra khi dùng lực.',
            'Trở về vị trí đầu có kiểm soát.',
          ]
        : exercise.instructions;

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: SafeArea(
        minimum: EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: Size.fromHeight(56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          onPressed: () => Navigator.pushNamed(
            context,
            '/session',
            arguments: {
              'dayName': exercise.name,
              'date': AppClock.today.toIso8601String(),
              'exercises': [
                {
                  'exerciseId': exercise.id,
                  'exerciseName': exercise.name,
                  'focusGroup': exercise.focusGroup,
                  'targetArea': exercise.targetArea,
                  'sets': 2,
                  'reps': 10,
                  'weight': 0,
                  'warmupSets': 1,
                },
              ],
            },
          ),
          icon: Icon(Icons.play_arrow_rounded, size: 27),
          label: LocalizedText('Bắt đầu bài tập'),
        ),
      ),
      body: CustomScrollView(
        physics: BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 300,
            backgroundColor: AppColors.background,
            foregroundColor: AppColors.textPrimary,
            flexibleSpace: FlexibleSpaceBar(background: _hero(exercise, color)),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 22, 20, 32),
            sliver: SliverList.list(
              children: [
                LocalizedText(exercise.name, style: AppTextTheme.headlineLarge),
                SizedBox(height: 8),
                LocalizedText(
                  exercise.description,
                  style: AppTextTheme.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _info(
                        Icons.speed_rounded,
                        'Độ khó',
                        exercise.difficulty,
                        _difficultyColor(exercise.difficulty),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: _info(
                        Icons.fitness_center_rounded,
                        'Dụng cụ',
                        exercise.equipment,
                        AppColors.secondary,
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: _info(
                        Icons.schedule_rounded,
                        'Thời gian',
                        '${exercise.durationMinutes} phút',
                        AppColors.accentPurple,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 28),
                SectionHeader(title: 'Hướng dẫn 3 bước'),
                SizedBox(height: 12),
                ...List.generate(
                  steps.length,
                  (index) =>
                      _step(index + 1, steps[index], index == steps.length - 1),
                ),
                SizedBox(height: 22),
                Container(
                  padding: EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: .25),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.health_and_safety_outlined,
                        color: AppColors.warning,
                        size: 27,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LocalizedText(
                              'Lưu ý an toàn',
                              style: AppTextTheme.titleMedium.copyWith(
                                color: AppColors.warning,
                              ),
                            ),
                            SizedBox(height: 5),
                            LocalizedText(
                              exercise.safetyTip,
                              style: AppTextTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero(Exercise exercise, Color color) => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          color.withValues(alpha: .4),
          AppColors.surface,
          AppColors.background,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: SafeArea(
      child: Stack(
        children: [
          Positioned(
            right: -25,
            bottom: -20,
            child: Icon(
              _icon(exercise.muscleGroup),
              size: 230,
              color: color.withValues(alpha: .12),
            ),
          ),
          Center(
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: .12),
                border: Border.all(
                  color: color.withValues(alpha: .4),
                  width: 2,
                ),
              ),
              child: Icon(_icon(exercise.muscleGroup), size: 72, color: color),
            ),
          ),
          Positioned(
            left: 20,
            bottom: 18,
            child: MuscleTag(muscleGroup: exercise.muscleGroup, fontSize: 13),
          ),
        ],
      ),
    ),
  );

  Widget _info(IconData icon, String label, String value, Color color) =>
      Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(17),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 23),
            SizedBox(height: 8),
            LocalizedText(
              value,
              style: AppTextTheme.labelMedium,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 2),
            LocalizedText(
              label,
              style: AppTextTheme.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );

  Widget _step(int number, String text, bool last) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: LocalizedText(
                '$number',
                style: AppTextTheme.labelLarge.copyWith(
                  color: AppColors.textInverse,
                ),
              ),
            ),
          ),
          if (!last) Container(width: 2, height: 48, color: AppColors.divider),
        ],
      ),
      SizedBox(width: 13),
      Expanded(
        child: Padding(
          padding: EdgeInsets.only(top: 7, bottom: 22),
          child: LocalizedText(text, style: AppTextTheme.bodyMedium),
        ),
      ),
    ],
  );

  Color _muscleColor(String group) => switch (group) {
    'Ngực' => AppColors.primary,
    'Lưng' => AppColors.secondary,
    'Chân' => AppColors.warning,
    'Vai' => AppColors.accent,
    'Tay' => AppColors.accentPurple,
    _ => AppColors.error,
  };

  Color _difficultyColor(String difficulty) => difficulty == 'Nâng cao'
      ? AppColors.error
      : difficulty == 'Vừa'
      ? AppColors.warning
      : AppColors.primary;
  IconData _icon(String group) => group == 'Chân'
      ? Icons.directions_run_rounded
      : group == 'Cơ bụng'
      ? Icons.self_improvement_rounded
      : Icons.accessibility_new_rounded;
}
