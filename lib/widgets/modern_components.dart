import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? color;
  final Gradient? gradient;
  final Border? border;
  final bool blur;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 20,
    this.color,
    this.gradient,
    this.border,
    this.blur = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface.withOpacity(0.85),
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        border: border ?? Border.all(color: AppColors.divider, width: 1),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 20, offset: Offset(0, 10)),
        ],
      ),
      child: child,
    );

    if (blur) {
      card = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: card,
        ),
      );
    }
    return card;
  }
}

class GradientButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double height;
  final Gradient gradient;
  final EdgeInsetsGeometry padding;

  const GradientButton({
    super.key,
    required this.child,
    this.onPressed,
    this.isLoading = false,
    this.height = 56,
    this.gradient = AppGradients.primary,
    this.padding = const EdgeInsets.symmetric(horizontal: 24),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: padding,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.textInverse),
                ),
              )
            : child,
      ),
    );
  }
}

class OutlineButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onPressed;
  final double height;
  final Color borderColor;
  final Color textColor;

  const OutlineButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.height = 56,
    this.borderColor = AppColors.divider,
    this.textColor = AppColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: textColor,
          side: BorderSide(color: borderColor, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: child,
      ),
    );
  }
}

class ModernStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtext;

  const ModernStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppColors.primary,
    this.subtext,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Icon(Icons.trending_up, color: color.withOpacity(0.6), size: 16),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: AppTextTheme.headlineMedium.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextTheme.caption.copyWith(color: AppColors.textSecondary),
          ),
          if (subtext != null) ...[
            const SizedBox(height: 4),
            Text(subtext!, style: AppTextTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  final VoidCallback? onActionTap;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextTheme.headlineMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: AppTextTheme.bodySmall.copyWith(color: AppColors.textMuted)),
                ],
              ],
            ),
          ),
          if (action != null) action!,
          if (onActionTap != null && action == null)
            InkWell(
              onTap: onActionTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Xem tất cả', style: AppTextTheme.labelMedium.copyWith(color: AppColors.primary)),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right, color: AppColors.primary, size: 16),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ModernBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;

  const ModernBottomNav({
    super.key,
    required this.currentIndex,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final items = const [
      BottomNavItem(icon: Icons.home_rounded, label: 'Trang chủ'),
      BottomNavItem(icon: Icons.calendar_today_rounded, label: 'Lịch tập'),
      BottomNavItem(icon: Icons.fitness_center_rounded, label: 'Bài tập'),
      BottomNavItem(icon: Icons.trending_up_rounded, label: 'Tiến độ'),
      BottomNavItem(icon: Icons.person_rounded, label: 'Cá nhân'),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.divider, width: 1),
        boxShadow: [
          BoxShadow(color: AppColors.shadow.withOpacity(0.4), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final isActive = currentIndex == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap?.call(i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    height: double.infinity,
                    color: isActive ? AppColors.primary.withOpacity(0.12) : Colors.transparent,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          items[i].icon,
                          color: isActive ? AppColors.primary : AppColors.textMuted,
                          size: 24,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          items[i].label,
                          style: TextStyle(
                            fontFamily: AppTextTheme.font,
                            fontSize: 11,
                            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                            color: isActive ? AppColors.primary : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class BottomNavItem {
  final IconData icon;
  final String label;
  const BottomNavItem({required this.icon, required this.label});
}

class ModernAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool centerTitle;
  final bool showShadow;

  const ModernAppBar({
    super.key,
    required this.title,
    this.leading,
    this.actions,
    this.centerTitle = false,
    this.showShadow = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: preferredSize.height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0x80000000), Color(0x1A000000)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border(bottom: BorderSide(color: AppColors.divider.withOpacity(0.5), width: 1)),
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: centerTitle,
            leading: leading,
            title: Text(title, style: AppTextTheme.titleLarge),
            actions: actions,
          ),
        ),
      ),
    );
  }
}

class MuscleTag extends StatelessWidget {
  final String muscleGroup;
  final double fontSize;

  const MuscleTag({super.key, required this.muscleGroup, this.fontSize = 11});

  Color _color(String g) {
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

  @override
  Widget build(BuildContext context) {
    final color = _color(muscleGroup);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Text(
        muscleGroup,
        style: TextStyle(
          fontFamily: AppTextTheme.font,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class ExerciseCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String muscleGroup;
  final int sets;
  final int reps;
  final double weight;
  final bool isDone;
  final VoidCallback onTap;

  const ExerciseCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.muscleGroup,
    required this.sets,
    required this.reps,
    required this.weight,
    this.isDone = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _muscleColor(muscleGroup);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDone ? AppColors.primary : AppColors.divider,
            width: isDone ? 1.5 : 1,
          ),
          boxShadow: const [
            BoxShadow(color: AppColors.shadow, blurRadius: 16, offset: Offset(0, 6)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: color.withOpacity(0.4), width: 1),
                    ),
                    child: Center(
                      child: Icon(_muscleIcon(muscleGroup), color: color, size: 24),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: AppTextTheme.titleMedium.copyWith(fontWeight: FontWeight.w700),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isDone)
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check, color: AppColors.textInverse, size: 14),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: AppTextTheme.bodySmall.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _miniStat('${sets} hiệp', Icons.repeat),
                            const SizedBox(width: 10),
                            _miniStat('${reps} lần', Icons.fitness_center),
                            const SizedBox(width: 10),
                            _miniStat('${weight.toStringAsFixed(0)} kg', Icons.monitor_weight),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniStat(String value, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(value, style: AppTextTheme.caption.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }

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
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final Color iconColor;

  const EmptyState({
    super.key,
    this.icon = Icons.fitness_center_rounded,
    required this.title,
    required this.message,
    this.action,
    this.iconColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(icon, color: iconColor, size: 40),
          ),
          const SizedBox(height: 20),
          Text(title, style: AppTextTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(message, style: AppTextTheme.bodySmall.copyWith(color: AppColors.textMuted), textAlign: TextAlign.center),
          if (action != null) ...[
            const SizedBox(height: 20),
            action!,
          ],
        ],
      ),
    );
  }
}

class ProgressRing extends StatelessWidget {
  final double progress;
  final double size;
  final Color color;
  final Widget? child;

  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 100,
    this.color = AppColors.primary,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            strokeWidth: 8,
            backgroundColor: AppColors.divider,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
          if (child != null) child!,
        ],
      ),
    );
  }
}

class PillSelector<T> extends StatelessWidget {
  final List<T> values;
  final T selected;
  final ValueChanged<T> onChanged;
  final String Function(T) labelBuilder;

  const PillSelector({
    super.key,
    required this.values,
    required this.selected,
    required this.onChanged,
    required this.labelBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: values.length,
        itemBuilder: (context, i) {
          final v = values[i];
          final isActive = v == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () => onChanged(v),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isActive ? AppColors.primary : AppColors.divider, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      labelBuilder(v),
                      style: TextStyle(
                        fontFamily: AppTextTheme.font,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isActive ? AppColors.textInverse : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool centerTitle;

  const GlassAppBar({
    super.key,
    required this.title,
    this.leading,
    this.actions,
    this.centerTitle = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: preferredSize.height,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: AppColors.background.withOpacity(0.4),
            child: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              centerTitle: centerTitle,
              leading: leading,
              title: Text(title, style: AppTextTheme.titleLarge),
              actions: actions,
            ),
          ),
        ),
      ),
    );
  }
}

class DividerLine extends StatelessWidget {
  final double height;
  final Color color;
  final EdgeInsetsGeometry margin;

  const DividerLine({super.key, this.height = 1, this.color = AppColors.divider, this.margin = EdgeInsets.zero});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      color: color,
      margin: margin,
    );
  }
}

class ShimmerLoader extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const ShimmerLoader({super.key, this.width = double.infinity, this.height = 16, this.borderRadius = const BorderRadius.all(Radius.circular(8))});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: borderRadius,
      ),
    );
  }
}

class HeroGradientCard extends StatelessWidget {
  final Widget child;
  final double height;
  final double borderRadius;
  final Gradient gradient;

  const HeroGradientCard({
    super.key,
    required this.child,
    this.height = 200,
    this.borderRadius = 24,
    this.gradient = AppGradients.surface,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: child,
      ),
    );
  }
}
