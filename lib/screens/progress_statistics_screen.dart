import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/modern_components.dart';
import '../models/data_models.dart';
import '../services/storage_service.dart';

class ProgressStatisticsScreen extends StatelessWidget {
  const ProgressStatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = StorageService.instance.loadProfile();
    final sessions = StorageService.instance.loadWorkoutSessions();
    final sessionsPerWeek = StorageService.instance.loadSessionsPerWeek() ?? 4;

    final totalCompleted = sessions.length;
    final now = DateTime.now();
    final thisWeek = sessions.where((s) {
      final diff = now.difference(s.date).inDays;
      return diff >= 0 && diff < 7;
    }).length;

    final rate = sessionsPerWeek == 0
        ? 0.0
        : (thisWeek / sessionsPerWeek) * 100;

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: ModernAppBar(title: 'Thống kê tiến độ', centerTitle: false),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tổng quan', style: AppTextTheme.labelLarge.copyWith(fontWeight: FontWeight.w700, color: AppColors.textMuted)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: ModernStatCard(label: 'Tổng buổi tập', value: totalCompleted.toString(), icon: Icons.fitness_center_rounded, color: AppColors.primary)),
                  const SizedBox(width: 12),
                  Expanded(child: ModernStatCard(label: 'Tuần này', value: thisWeek.toString(), icon: Icons.calendar_today_rounded, color: AppColors.secondary)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: ModernStatCard(label: 'Mục tiêu/tuần', value: sessionsPerWeek.toString(), icon: Icons.event_repeat_rounded, color: AppColors.warning)),
                  Expanded(child: ModernStatCard(label: 'Hoàn thành tuần', value: '${rate.toStringAsFixed(0)}%', icon: Icons.trending_up_rounded, color: AppColors.primary, subtext: '$thisWeek/$sessionsPerWeek')),
                ],
              ),
              const SizedBox(height: 24),

              if (profile != null) ...[
                Text('Thể lực', style: AppTextTheme.labelLarge.copyWith(fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                const SizedBox(height: 12),
                ModernStatCard(label: 'Cân nặng', value: '${profile.weight.toStringAsFixed(1)} kg', icon: Icons.monitor_weight_rounded, color: AppColors.secondary),
                const SizedBox(height: 24),
              ],

              Text('Ghi chú', style: AppTextTheme.labelLarge.copyWith(fontWeight: FontWeight.w700, color: AppColors.textMuted)),
              const SizedBox(height: 12),
              GlassCard(
                padding: const EdgeInsets.all(16),
                borderRadius: 16,
                color: AppColors.surfaceElevated,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tỷ lệ hoàn thành = Buổi tập tuần này / Mục tiêu mỗi tuần × 100%', style: AppTextTheme.bodySmall.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    Text('Số buổi mục tiêu mỗi tuần: $sessionsPerWeek', style: AppTextTheme.bodySmall.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    Text('Cân nặng hiện tại: ${profile != null ? profile.weight.toStringAsFixed(1) : '—'} kg', style: AppTextTheme.bodySmall.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const ModernBottomNav(currentIndex: 3, onTap: null),
    );
  }
}
