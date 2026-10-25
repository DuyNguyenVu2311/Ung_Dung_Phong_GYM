import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/modern_components.dart';
import '../models/data_models.dart';
import '../services/storage_service.dart';
import 'schedule_screen.dart';
import 'exercise_library_screen.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  UserProfile? profile;
  int _navIndex = 0;

  String _goalLabel(String g) {
    switch (g) {
      case 'muscle': return 'Tăng cơ';
      case 'fatloss': return 'Giảm mỡ';
      default: return 'Duy trì';
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = StorageService.instance.loadProfile() ??
        UserProfile(name: 'Bạn', age: 22, height: 170, weight: 70, gender: 'Nam', goal: 'muscle', experienceLevel: 'beginner', sessionsPerWeek: 3);
    if (!mounted) return;
    setState(() => profile = p);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: const ModernAppBar(title: 'FitPlan', centerTitle: false, showShadow: false),
      body: profile == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Chào mừng trở lại,', style: AppTextTheme.bodyMedium.copyWith(color: AppColors.textSecondary)),
                              const SizedBox(height: 2),
                              Text(
                                '${profile!.name}!',
                                style: AppTextTheme.displayLarge.copyWith(fontSize: 26),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Mục tiêu hôm nay: ${_goalLabel(profile!.goal)}',
                                style: AppTextTheme.bodySmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: AppGradients.primary,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(color: AppColors.primary.withOpacity(0.45), blurRadius: 16, offset: const Offset(0, 6)),
                            ],
                          ),
                          child: const Icon(Icons.fitness_center_rounded, color: AppColors.textInverse, size: 24),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        const Text('Hôm nay, ', style: TextStyle(fontFamily: AppTextTheme.font, fontSize: 14, color: AppColors.textMuted)),
                        Text(
                          '${_weekday(DateTime.now())}, ${DateTime.now().day} ${_month(DateTime.now().month)}',
                          style: AppTextTheme.titleMedium.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _statsRow(),
                          const SizedBox(height: 24),

                          SectionHeader(
                            title: 'Buổi tập tiếp theo',
                            action: TextButton(
                              onPressed: () => Navigator.pushNamed(context, '/schedule'),
                              child: const Text('Lịch tập', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(height: 12),
                          GlassCard(
                            padding: const EdgeInsets.all(18),
                            borderRadius: 20,
                            color: AppColors.surfaceElevated,
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.today_rounded, color: AppColors.primary, size: 22),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Thứ Hai - Buổi 1', style: AppTextTheme.titleMedium.copyWith(fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 4),
                                      Text('Squat · Bench Press · Lat Pulldown', style: AppTextTheme.bodySmall.copyWith(color: AppColors.textSecondary)),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          SectionHeader(title: 'Lối tắt nhanh'),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _shortcut(Icons.calendar_month_rounded, 'Lịch tập tuần', AppColors.secondary, () => Navigator.pushNamed(context, '/schedule'))),
                              const SizedBox(width: 10),
                              Expanded(child: _shortcut(Icons.library_add_rounded, 'Thư viện bài tập', AppColors.primary, () => Navigator.pushNamed(context, '/library'))),
                              const SizedBox(width: 10),
                              Expanded(child: _shortcut(Icons.history_rounded, 'Lịch sử tập', AppColors.accent, () => Navigator.pushNamed(context, '/history'))),
                            ],
                          ),
                          const SizedBox(height: 24),

                          GlassCard(
                            padding: const EdgeInsets.all(18),
                            borderRadius: 20,
                            gradient: AppGradients.surface,
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    gradient: AppGradients.primary,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.emoji_events_rounded, color: AppColors.textInverse, size: 22),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Kỷ lục cá nhân mới!', style: AppTextTheme.labelLarge.copyWith(fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 2),
                                      Text('Squat đạt 85kg hôm qua', style: AppTextTheme.bodySmall.copyWith(color: AppColors.textSecondary)),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.trending_up_rounded, color: AppColors.primary, size: 20),
                              ],
                            ),
                          ),
                          const SizedBox(height: 26),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: ModernBottomNav(currentIndex: _navIndex, onTap: (i) => setState(() => _navIndex = i)),
    );
  }

  Widget _statsRow() {
    return Row(
      children: [
        Expanded(
          child: ModernStatCard(
            label: 'BMI',
            value: '${profile!.bmi.toStringAsFixed(1)}',
            icon: Icons.monitor_weight_rounded,
            color: AppColors.primary,
            subtext: profile!.bmiLabel,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ModernStatCard(
            label: 'Buổi tập/tuần',
            value: '${profile!.sessionsPerWeek}',
            icon: Icons.calendar_today_rounded,
            color: AppColors.secondary,
          ),
        ),
      ],
    );
  }

  Widget _shortcut(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.3), width: 1),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label, style: AppTextTheme.labelMedium.copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  String _weekday(DateTime d) {
    const map = {1: 'Thứ Hai', 2: 'Thứ Ba', 3: 'Thứ Tư', 4: 'Thứ Năm', 5: 'Thứ Sáu', 6: 'Thứ Bảy', 7: 'Chủ Nhật'};
    return map[d.weekday] ?? '';
  }

  String _month(int m) {
    const map = {1: 'Tháng 1', 2: 'Tháng 2', 3: 'Tháng 3', 4: 'Tháng 4', 5: 'Tháng 5', 6: 'Tháng 6', 7: 'Tháng 7', 8: 'Tháng 8', 9: 'Tháng 9', 10: 'Tháng 10', 11: 'Tháng 11', 12: 'Tháng 12'};
    return map[m] ?? '';
  }
}
