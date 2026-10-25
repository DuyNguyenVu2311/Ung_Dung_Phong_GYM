import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/modern_components.dart';
import '../services/storage_service.dart';
import 'schedule_screen.dart';

class LevelScreen extends StatefulWidget {
  const LevelScreen({super.key});

  @override
  State<LevelScreen> createState() => _LevelScreenState();
}

class _LevelScreenState extends State<LevelScreen> {
  String exp = 'exp';
  int days = 4;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: ModernAppBar(title: 'Trình độ & Lịch trình', centerTitle: false),
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
                        value: 1.0,
                        strokeWidth: 8,
                        backgroundColor: AppColors.divider,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                    const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 32),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text('Bước 3/3 • Hoàn tất hồ sơ', style: AppTextTheme.labelMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 24),
              Text('Trình độ & Lịch trình tập', style: AppTextTheme.headlineMedium),
              const SizedBox(height: 6),
              Text('Xác lập kinh nghiệm để thiết kế khối lượng tập an toàn, tối ưu hiệu suất và tránh chấn thương.', style: AppTextTheme.bodySmall.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 24),

              SectionHeader(title: 'Kinh nghiệm rèn luyện'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _expButton('Mới bắt đầu', 'Dưới 6 tháng tập', Icons.spa_rounded, active: exp == 'beginner', onTap: () => setState(() => exp = 'beginner'))),
                  const SizedBox(width: 10),
                  Expanded(child: _expButton('Có kinh nghiệm', 'Trên 6 tháng tập', Icons.bolt_rounded, active: exp == 'exp', onTap: () => setState(() => exp = 'exp'))),
                ],
              ),
              const SizedBox(height: 24),

              SectionHeader(title: 'Số ngày tập mỗi tuần'),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(5, (i) {
                  final d = i + 2;
                  return _dayButton(d, active: days == d, onTap: () => setState(() => days = d));
                }),
              ),
              const SizedBox(height: 24),

              GlassCard(
                padding: const EdgeInsets.all(18),
                borderRadius: 18,
                color: AppColors.surfaceElevated,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.secondary.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.auto_awesome_rounded, color: AppColors.secondary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Khuyến nghị AI Coach', style: AppTextTheme.labelLarge.copyWith(fontWeight: FontWeight.w700, color: AppColors.secondary)),
                          const SizedBox(height: 2),
                          Text(
                            '4 buổi/tuần (Upper/Lower Split) kích thích từng nhóm cơ 2 lần/tuần, đảm bảo chu kỳ tái tổng hợp protein và phục hồi khớp tối đa.',
                            style: AppTextTheme.bodySmall.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              SectionHeader(title: 'Cấu hình giáo trình FitPlan'),
              const SizedBox(height: 12),
              GlassCard(
                padding: const EdgeInsets.all(16),
                borderRadius: 16,
                color: AppColors.surface.withOpacity(0.6),
                child: Column(
                  children: [
                    _chip('Mục tiêu: Tăng cơ', Icons.flag_rounded, AppColors.primary),
                    const SizedBox(height: 8),
                    _chip('Lịch: $days buổi / tuần', Icons.event_repeat_rounded, AppColors.secondary),
                    const SizedBox(height: 8),
                    _chip('Trình độ: Có kinh nghiệm', Icons.speed_rounded, AppColors.primary),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: GradientButton(
                  onPressed: () async {
                    await StorageService.instance.saveLevel(exp);
                    await StorageService.instance.saveSessionsPerWeek(days);
                    if (!mounted) return;
                    Navigator.pushReplacementNamed(context, '/schedule');
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Tạo lịch tập tự động', style: AppTextTheme.labelLarge.copyWith(fontWeight: FontWeight.w700, color: AppColors.textInverse)),
                      const SizedBox(width: 8),
                      const Icon(Icons.auto_awesome_rounded, color: AppColors.textInverse, size: 20),
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

  Widget _expButton(String title, String sub, IconData icon, {required bool active, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: active ? AppColors.surfaceElevated : AppColors.surface.withOpacity(0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? AppColors.primary : AppColors.divider, width: active ? 1.5 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(color: active ? AppColors.primary.withOpacity(0.2) : AppColors.divider, borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: active ? AppColors.primary : AppColors.textMuted, size: 18),
                ),
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(color: active ? AppColors.primary : Colors.transparent, shape: BoxShape.circle),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(title, style: AppTextTheme.titleMedium.copyWith(fontWeight: FontWeight.w700, color: active ? AppColors.primary : AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(sub, style: AppTextTheme.bodySmall.copyWith(color: active ? AppColors.textPrimary : AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _dayButton(int d, {required bool active, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 80,
        width: 80,
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.surface.withOpacity(0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? AppColors.primary : AppColors.divider, width: active ? 0 : 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(d.toString(), style: AppTextTheme.headlineMedium.copyWith(fontSize: 22, color: active ? AppColors.textInverse : AppColors.textPrimary, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text('buổi', style: AppTextTheme.caption.copyWith(color: active ? AppColors.textInverse : AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontFamily: AppTextTheme.font, fontSize: 13, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}
