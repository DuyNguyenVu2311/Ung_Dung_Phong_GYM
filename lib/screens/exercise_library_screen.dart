import 'package:flutter/material.dart';

import '../services/app_localization.dart';

import '../models/data_models.dart';
import '../repositories/exercise_repository.dart';
import '../services/storage_service.dart';
import '../services/cloud_sync_service.dart';
import '../theme/app_theme.dart';
import '../widgets/modern_components.dart';

class ExerciseLibraryScreen extends StatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  String _query = '';
  String? _muscle;
  Set<String> _favorites = <String>{};
  bool _favoritesOnly = false;

  @override
  void initState() {
    super.initState();
    _favorites = StorageService.instance.loadFavoriteExerciseIds();
  }

  List<Exercise> get _exercises {
    final exercises = ExerciseRepository.filter(
      muscleGroup: _muscle,
      query: _query,
    );
    if (!_favoritesOnly) return exercises;
    return exercises
        .where((exercise) => _favorites.contains(exercise.id))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    AppSettingsScope.watch(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LocalizedText(
                      'Khám phá bài tập',
                      style: AppTextTheme.headlineLarge,
                    ),
                    SizedBox(height: 6),
                    LocalizedText(
                      'Hướng dẫn rõ ràng để bạn tập đúng và an toàn.',
                      style: AppTextTheme.bodySmall,
                    ),
                    SizedBox(height: 18),
                    TextField(
                      onChanged: (value) => setState(() => _query = value),
                      style: AppTextTheme.bodyMedium,
                      decoration: InputDecoration(
                        hintText: tr('Tìm bài tập hoặc nhóm cơ'),
                        prefixIcon: Icon(Icons.search_rounded),
                        suffixIcon: _query.isEmpty
                            ? null
                            : Icon(Icons.tune_rounded),
                      ),
                    ),
                    SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
              sliver: SliverToBoxAdapter(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FilterChip(
                    avatar: Icon(
                      _favoritesOnly
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 18,
                      color: _favoritesOnly
                          ? AppColors.accent
                          : AppColors.textMuted,
                    ),
                    selected: _favoritesOnly,
                    label: LocalizedText('Yêu thích (${_favorites.length})'),
                    onSelected: (selected) =>
                        setState(() => _favoritesOnly = selected),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  children:
                      [
                            null,
                            'Ngực',
                            'Lưng',
                            'Đùi trước',
                            'Đùi sau',
                            'Mông',
                            'Bắp chân',
                            'Chân',
                            'Vai',
                            'Tay trước',
                            'Tay sau',
                            'Tay',
                            'Cơ bụng',
                          ]
                          .map(
                            (muscle) => Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                selected: _muscle == muscle,
                                label: LocalizedText(muscle ?? 'Tất cả'),
                                onSelected: (_) =>
                                    setState(() => _muscle = muscle),
                              ),
                            ),
                          )
                          .toList(),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
              sliver: SliverToBoxAdapter(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    LocalizedText(
                      '${_exercises.length} bài tập',
                      style: AppTextTheme.titleMedium,
                    ),
                    _legend(Icons.shield_outlined, 'An toàn'),
                  ],
                ),
              ),
            ),
            _exercises.isEmpty
                ? SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Không tìm thấy',
                      message: 'Thử một từ khóa hoặc nhóm cơ khác.',
                    ),
                  )
                : SliverPadding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 28),
                    sliver: SliverList.separated(
                      itemCount: _exercises.length,
                      separatorBuilder: (_, _) => SizedBox(height: 12),
                      itemBuilder: (context, index) =>
                          _exerciseCard(_exercises[index], index),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _exerciseCard(Exercise exercise, int index) {
    final color = _muscleColor(exercise.muscleGroup);
    return Material(
      color: AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () =>
            Navigator.pushNamed(context, '/detail', arguments: exercise),
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 92,
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withValues(alpha: .35),
                      color.withValues(alpha: .08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      _muscleIcon(exercise.muscleGroup),
                      color: color,
                      size: 43,
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: LocalizedText(
                            exercise.name,
                            style: AppTextTheme.titleMedium,
                          ),
                        ),
                        IconButton(
                          tooltip: _favorites.contains(exercise.id)
                              ? 'Bỏ khỏi yêu thích'
                              : 'Thêm vào yêu thích',
                          onPressed: () => _toggleFavorite(exercise),
                          icon: Icon(
                            _favorites.contains(exercise.id)
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: _favorites.contains(exercise.id)
                                ? AppColors.accent
                                : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 5),
                    LocalizedText(
                      exercise.description,
                      style: AppTextTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 12),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _badge(exercise.muscleGroup, color),
                        _badge(exercise.equipment, AppColors.secondary),
                        _badge(
                          exercise.difficulty,
                          _difficultyColor(exercise.difficulty),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleFavorite(Exercise exercise) async {
    final isFavorite = await StorageService.instance.toggleFavoriteExercise(
      exercise.id,
    );
    await CloudSyncService.instance.syncNow();
    if (!mounted) return;
    setState(() {
      if (isFavorite) {
        _favorites.add(exercise.id);
      } else {
        _favorites.remove(exercise.id);
      }
    });
  }

  Widget _badge(String label, Color color) => Container(
    padding: EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(999),
    ),
    child: LocalizedText(
      label,
      style: AppTextTheme.caption.copyWith(
        color: color,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _legend(IconData icon, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: AppColors.primary),
      SizedBox(width: 5),
      LocalizedText(label, style: AppTextTheme.caption),
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

  IconData _muscleIcon(String group) => switch (group) {
    'Chân' => Icons.directions_run_rounded,
    'Cơ bụng' => Icons.self_improvement_rounded,
    'Lưng' => Icons.accessibility_new_rounded,
    _ => Icons.fitness_center_rounded,
  };

  Color _difficultyColor(String difficulty) => switch (difficulty) {
    'Nâng cao' => AppColors.error,
    'Vừa' => AppColors.warning,
    _ => AppColors.primary,
  };
}
