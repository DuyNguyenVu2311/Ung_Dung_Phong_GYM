import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/modern_components.dart';
import '../services/storage_service.dart';
import 'level_screen.dart';

class GoalScreen extends StatefulWidget {
  const GoalScreen({super.key});

  @override
  State<GoalScreen> createState() => _GoalScreenState();
}

class _GoalScreenState extends State<GoalScreen> {
  String selected = 'muscle';

  void _select(String g) => setState(() => selected = g);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: ModernAppBar(title: 'Mục tiêu tập luyện', centerTitle: false),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: CircularProgressIndicator(
                        value: 0.66,
                        strokeWidth: 8,
                        backgroundColor: AppColors.divider,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                    const Icon(Icons.fitness_center_rounded, color: AppColors.primary, size: 32),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text('Bước 2/3 • Hoàn tất 66%', style: AppTextTheme.labelMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 24),
              Text('Mục tiêu tập luyện của bạn là gì?', style: AppTextTheme.headlineMedium),
              const SizedBox(height: 6),
              Text('Chọn định hướng thể hình để FitPlan tối ưu hoá số hiệp và khoảng rep.', style: AppTextTheme.bodySmall.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 24),

              _goalCard(
                id: 'muscle',
                icon: Icons.fitness_center_rounded,
                name: 'Tăng cơ',
                subtitle: 'Hypertrophy',
                tag: 'Khuyên dùng',
                desc: 'Xây dựng khối cơ bắp rắn chắc, tối ưu kích thước cơ bắp và phát triển sức mạnh tối đa.',
                pills: const ['8-12 reps', 'Khối lượng tạ cao', 'Nghỉ 90s'],
                active: selected == 'muscle',
                onTap: () => _select('muscle'),
              ),
              const SizedBox(height: 14),
              _goalCard(
                id: 'fatloss',
                icon: Icons.local_fire_department_rounded,
                name: 'Giảm mỡ',
                subtitle: 'Fat Loss & Cutting',
                desc: 'Đốt cháy calo dư thừa, giảm mỡ dưới da và siết nét cơ bắp với cường độ chuyển hóa cao.',
                pills: const ['15-20 reps', 'Mật độ tập dày', 'Nghỉ 45s'],
                active: selected == 'fatloss',
                onTap: () => _select('fatloss'),
              ),
              const SizedBox(height: 14),
              _goalCard(
                id: 'maintenance',
                icon: Icons.health_and_safety_rounded,
                name: 'Duy trì thể lực',
                subtitle: 'Health & Fitness',
                desc: 'Duy trì vóc dáng, nâng cao độ dẻo dai khớp và tăng cường sức bền tim mạch toàn diện mỗi ngày.',
                pills: const ['10-15 reps', 'Cân bằng Cardio', 'Nghỉ 60s'],
                active: selected == 'maintenance',
                onTap: () => _select('maintenance'),
              ),
              const SizedBox(height: 24),

              GlassCard(
                padding: const EdgeInsets.all(16),
                borderRadius: 16,
                color: AppColors.surfaceElevated,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.psychology_rounded, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Bạn có thể tùy chỉnh hoặc chuyển đổi mục tiêu bất kỳ lúc nào trong cài đặt hồ sơ.', style: AppTextTheme.bodySmall.copyWith(color: AppColors.textSecondary)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: GradientButton(
                  onPressed: () async {
                    await StorageService.instance.saveGoal(selected);
                    if (!mounted) return;
                    Navigator.pushReplacementNamed(context, '/level');
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Tiếp tục sang Trình độ', style: AppTextTheme.labelLarge.copyWith(fontWeight: FontWeight.w700, color: AppColors.textInverse)),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, color: AppColors.textInverse, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const ModernBottomNav(currentIndex: 4, onTap: null),
    );
  }

  Widget _goalCard({
    required String id,
    required IconData icon,
    required String name,
    required String subtitle,
    String? tag,
    required String desc,
    required List<String> pills,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: active ? AppColors.surfaceElevated : AppColors.surface.withOpacity(0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? AppColors.primary : AppColors.divider, width: active ? 1.5 : 1),
          boxShadow: active
              ? [BoxShadow(color: AppColors.primary.withOpacity(0.25), blurRadius: 24, offset: const Offset(0, 0))]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(active ? 0.35 : 0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: active ? AppColors.primary : AppColors.textMuted, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(name, style: AppTextTheme.titleMedium.copyWith(fontWeight: FontWeight.w700, color: active ? AppColors.primary : AppColors.textPrimary)),
                          if (tag != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                              child: Text(tag, style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(subtitle, style: AppTextTheme.caption.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(active ? Icons.check_rounded : null, color: active ? AppColors.textInverse : Colors.transparent, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(desc, style: AppTextTheme.bodySmall.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: pills.map((p) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.divider)),
                child: Text(p, style: AppTextTheme.caption.copyWith(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
