import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/modern_components.dart';
import '../models/data_models.dart';
import '../repositories/exercise_repository.dart';
import 'workout_session_screen.dart';

class ExerciseDetailScreen extends StatelessWidget {
  const ExerciseDetailScreen({super.key});

  Color _muscleColor(String g) {
    switch (g) {
      case 'Ngực': return AppColors.primary;
      case 'Lưng': return AppColors.secondary;
      case 'Chân': return AppColors.warning;
      case 'Vai': return AppColors.accent;
      case 'Tay': return AppColors.accentPurple;
      case 'Cơ bụng': return AppColors.error;
      default: return AppColors.textMuted;
    }
  }

  IconData _muscleIcon(String g) {
    switch (g) {
      case 'Ngực': return Icons.fitness_center_rounded;
      case 'Lưng': return Icons.pool_rounded;
      case 'Chân': return Icons.directions_run_rounded;
      case 'Vai': return Icons.accessibility_rounded;
      case 'Tay': return Icons.accessibility_new_rounded;
      case 'Cơ bụng': return Icons.widgets_rounded;
      default: return Icons.widgets_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercise = ModalRoute.of(context)?.settings.arguments as Exercise?;
    final ex = exercise ?? ExerciseRepository.findById('ex001');
    final color = _muscleColor(ex.muscleGroup);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.background,
            elevation: 0,
            leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary), onPressed: () => Navigator.pop(context)),
            actions: [
              IconButton(icon: const Icon(Icons.favorite_border, color: AppColors.textSecondary), onPressed: () {}),
              IconButton(icon: const Icon(Icons.share_rounded, color: AppColors.textSecondary), onPressed: () {}),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                width: double.infinity,
                height: 260,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.15), AppColors.background],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Container(
                          color: color.withOpacity(0.08),
                        ),
                      ),
                      Positioned(
                        top: 16,
                        left: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: AppColors.background.withOpacity(0.5), borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_muscleIcon(ex.muscleGroup), color: color, size: 14),
                              const SizedBox(width: 4),
                              Text(ex.muscleGroup, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: AppColors.background.withOpacity(0.5), borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.verified_rounded, color: AppColors.primary, size: 14),
                              const SizedBox(width: 4),
                              Text('Chuẩn thi đấu', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 20,
                        left: 20,
                        right: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('BÀI TẬP CƠ BẢN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.5)),
                            const SizedBox(height: 6),
                            Text(ex.name, style: AppTextTheme.displayLarge.copyWith(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                            const SizedBox(height: 4),
                            Text(ex.description, style: AppTextTheme.bodyMedium.copyWith(color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoSection(ex),
                  const SizedBox(height: 24),
                  const Text('Hướng dẫn thực hiện', style: AppTextTheme.headlineMedium),
                  const SizedBox(height: 14),
                  _step(1, 'Ổn định tư thế & Điểm tựa', 'Nằm vững lưng trên ghế phẳng, siết chặt xương bả vai và đặt 2 bàn chân bám chắc sàn.', color),
                  const SizedBox(height: 14),
                  _step(2, 'Tháo tạ & Gồng cơ lõi', 'Nắm đòn tạ rộng hơn vai, tháo đòn có kiểm soát và hít sâu gồng cơ lõi (brace core).', color),
                  const SizedBox(height: 14),
                  _step(3, 'Hạ đòn có kiểm soát', 'Hạ đòn tạ chậm chạm nhẹ vùng ngực dưới trong 2-3 giây.', color),
                  const SizedBox(height: 14),
                  _step(4, 'Phát lực đẩy & Khóa ngực', 'Thở ra và dùng lực cơ đẩy mạnh đòn lên vị trí ban đầu (không khóa khớp cùi chỏ).', color),
                  const SizedBox(height: 24),
                  _safetyBox(color),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: GradientButton(
          onPressed: () => Navigator.pushNamed(context, '/session'),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_circle_rounded, color: AppColors.textInverse, size: 22),
              const SizedBox(width: 8),
              Text('Thêm vào buổi tập', style: AppTextTheme.labelLarge.copyWith(fontWeight: FontWeight.w700, color: AppColors.textInverse)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoSection(Exercise ex) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      borderRadius: 18,
      color: AppColors.surfaceElevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: _muscleColor(ex.muscleGroup), shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text('THÔNG TIN BÀI TẬP', style: AppTextTheme.caption.copyWith(fontWeight: FontWeight.w700, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _stat('HIỆP ĐỀ XUẤT', '3', 'Hiệp', AppColors.primary),
              const SizedBox(width: 12),
              _stat('SỐ LẦN', '10-12', 'Lần/hiệp', AppColors.secondary),
              const SizedBox(width: 12),
              _stat('NGHỈ GIỮA HIỆP', '60-90s', 'Nghỉ', AppColors.warning),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, String sub, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextTheme.caption.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value, style: AppTextTheme.headlineMedium.copyWith(fontSize: 20, color: color, fontWeight: FontWeight.w800)),
              const SizedBox(width: 4),
              Text(sub, style: AppTextTheme.caption.copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _step(int num, String title, String desc, Color color) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      color: AppColors.surfaceElevated,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Text('$num', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textInverse))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextTheme.titleMedium.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(desc, style: AppTextTheme.bodySmall.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _safetyBox(Color color) {
    final warnColor = AppColors.accent;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      color: warnColor.withOpacity(0.1),
      border: Border.all(color: warnColor.withOpacity(0.3), width: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_rounded, color: warnColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lưu ý an toàn', style: AppTextTheme.labelLarge.copyWith(fontWeight: FontWeight.w700, color: warnColor)),
                const SizedBox(height: 4),
                Text(
                  'Không ưỡn thắt lưng quá cao khỏi ghế. Luôn nhờ người hỗ trợ (spotter) khi nâng tạ nặng trên 80% 1RM để tránh chấn thương khớp vai.',
                  style: AppTextTheme.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
