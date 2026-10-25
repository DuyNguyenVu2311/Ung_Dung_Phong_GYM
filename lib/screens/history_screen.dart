import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/modern_components.dart';
import '../models/data_models.dart';
import '../services/storage_service.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sessions = StorageService.instance.loadWorkoutSessions()..reversed;

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: ModernAppBar(title: 'Lịch sử tập luyện', centerTitle: false),
      body: sessions.isEmpty
          ? SafeArea(
              child: EmptyState(
                icon: Icons.history_rounded,
                title: 'Chưa có buổi tập nào',
                message: 'Hãy hoàn thành một buổi tập để bắt đầu theo dõi tiến độ của bạn.',
              ),
            )
          : SafeArea(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                physics: const BouncingScrollPhysics(),
                itemCount: sessions.length,
                itemBuilder: (context, i) {
                  final s = sessions.elementAt(i);
                  final totalSets = s.logs.fold<int>(0, (sum, l) => sum + l.sets);
                  final totalReps = s.logs.fold<int>(0, (sum, l) => sum + l.reps);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    child: GlassCard(
                      padding: const EdgeInsets.all(16),
                      borderRadius: 16,
                      color: AppColors.surfaceElevated,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  s.dayName,
                                  style: AppTextTheme.titleMedium.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              Text(
                                '${s.date.day}/${s.date.month}/${s.date.year}',
                                style: AppTextTheme.bodySmall.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _chip('${s.logs.length} bài', AppColors.primary),
                              const SizedBox(width: 8),
                              _chip('$totalSets hiệp', AppColors.secondary),
                              const SizedBox(width: 8),
                              _chip('$totalReps lần', AppColors.warning),
                            ],
                          ),
                          const SizedBox(height: 12),
                          DividerLine(margin: const EdgeInsets.symmetric(vertical: 8)),
                          ...s.logs.map((l) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Container(width: 6, height: 6, decoration: BoxDecoration(color: AppColors.textMuted, shape: BoxShape.circle)),
                                const SizedBox(width: 10),
                                Expanded(child: Text(l.exerciseName, style: AppTextTheme.bodyMedium.copyWith(fontWeight: FontWeight.w700))),
                                Text('${l.sets} hiệp · ${l.reps} lần · ${l.weight.toStringAsFixed(0)} kg',
                                    style: AppTextTheme.bodySmall.copyWith(color: AppColors.textSecondary)),
                              ],
                            ),
                          )),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
      bottomNavigationBar: const ModernBottomNav(currentIndex: 3, onTap: null),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
    );
  }
}
