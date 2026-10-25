import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/modern_components.dart';
import '../models/data_models.dart';
import '../repositories/exercise_repository.dart';
import 'exercise_detail_screen.dart';

class ExerciseLibraryScreen extends StatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  String _query = '';
  String _filter = 'all';

  final Map<String, String?> _muscleByFilter = {
    'all': null,
    'chest': 'Ngực',
    'back': 'Lưng',
    'legs': 'Chân',
    'shoulders': 'Vai',
    'arms': 'Tay',
    'core': 'Cơ bụng',
    'equipment': null,
  };

  List<Exercise> get _filtered {
    return ExerciseRepository.filter(muscleGroup: _muscleByFilter[_filter], query: _query);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: ModernAppBar(title: 'Thư viện bài tập', centerTitle: false),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                borderRadius: 14,
                color: AppColors.surface.withOpacity(0.6),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        style: const TextStyle(fontFamily: AppTextTheme.font, color: AppColors.textPrimary, fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'Tìm tên bài tập, nhóm cơ, dụng cụ...',
                          hintStyle: TextStyle(fontFamily: AppTextTheme.font, color: AppColors.textMuted, fontSize: 13),
                          border: InputBorder.none,
                        ),
                        onChanged: (v) => setState(() => _query = v),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _filterChip('Tất cả', 'all', AppColors.primary),
                  _filterChip('Ngực', 'chest', AppColors.primary),
                  _filterChip('Lưng', 'back', AppColors.secondary),
                  _filterChip('Chân', 'legs', AppColors.warning),
                  _filterChip('Vai', 'shoulders', AppColors.accent),
                  _filterChip('Tay', 'arms', AppColors.accentPurple),
                  _filterChip('Cơ bụng', 'core', AppColors.error),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    _filtered.isEmpty ? 'Không tìm thấy bài tập' : '${_filtered.length} bài tập',
                    style: AppTextTheme.titleMedium.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  if (_filtered.isNotEmpty) Text('Nhấn để xem chi tiết', style: AppTextTheme.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _filtered.isEmpty
                  ? EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Không tìm thấy bài tập',
                      message: 'Thử từ khóa hoặc nhóm cơ khác.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _filtered.length,
                      itemBuilder: (context, i) {
                        final ex = _filtered[i];
                        return ExerciseCard(
                          title: ex.name,
                          subtitle: ex.description,
                          muscleGroup: ex.muscleGroup,
                          sets: 3,
                          reps: 10,
                          weight: 0,
                          onTap: () => Navigator.pushNamed(context, '/detail', arguments: ex),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: const ModernBottomNav(currentIndex: 2, onTap: null),
    );
  }

  Widget _filterChip(String label, String id, Color color) {
    final active = _filter == id;
    return GestureDetector(
      onTap: () => setState(() => _filter = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: active ? color : AppColors.surface.withOpacity(0.6),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: active ? color : AppColors.divider, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppTextTheme.font,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: active ? AppColors.textInverse : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
