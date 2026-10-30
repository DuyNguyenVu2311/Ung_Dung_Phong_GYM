import 'package:flutter/material.dart';

import '../services/app_localization.dart';

import '../theme/app_theme.dart';
import '../widgets/modern_components.dart';
import 'exercise_library_screen.dart';
import 'home_screen.dart';
import 'membership_screen.dart';
import 'profile_screen.dart';
import 'schedule_screen.dart';

/// Khung điều hướng chính của ứng dụng.
///
/// IndexedStack giữ nguyên trạng thái cuộn và dữ liệu tạm của từng tab khi
/// người dùng chuyển qua lại giữa các màn hình.
class MainAppShell extends StatefulWidget {
  final int initialIndex;

  const MainAppShell({super.key, this.initialIndex = 0});

  @override
  State<MainAppShell> createState() => _MainAppShellState();
}

class _MainAppShellState extends State<MainAppShell> {
  late int _currentIndex;
  final List<Widget?> _pages = List<Widget?>.filled(5, null);

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, 4);
    _pages[_currentIndex] = _createPage(_currentIndex);
  }

  Widget _createPage(int index) => switch (index) {
    0 => HomeScreen(onTabSelected: _selectTab),
    1 => const ScheduleScreen(),
    2 => const ExerciseLibraryScreen(),
    3 => const MembershipScreen(),
    _ => const ProfileScreen(),
  };

  void _selectTab(int index) {
    if (index == _currentIndex) return;
    setState(() {
      _pages[index] ??= _createPage(index);
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    AppSettingsScope.watch(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 600;
        final pages = IndexedStack(
          index: _currentIndex,
          children: _pages
              .map((page) => page ?? const SizedBox.shrink())
              .toList(),
        );
        if (useRail) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: SafeArea(
              child: Row(
                children: [
                  NavigationRail(
                    selectedIndex: _currentIndex,
                    onDestinationSelected: _selectTab,
                    extended: constraints.maxWidth >= 1000,
                    backgroundColor: AppColors.surface,
                    indicatorColor: AppColors.primary.withValues(alpha: .18),
                    labelType: constraints.maxWidth >= 1000
                        ? NavigationRailLabelType.none
                        : NavigationRailLabelType.all,
                    destinations: [
                      NavigationRailDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home_rounded),
                        label: LocalizedText('Trang chủ'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.calendar_today_outlined),
                        selectedIcon: Icon(Icons.calendar_today_rounded),
                        label: LocalizedText('Lịch tập'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.fitness_center_outlined),
                        selectedIcon: Icon(Icons.fitness_center_rounded),
                        label: LocalizedText('Bài tập'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.card_membership_outlined),
                        selectedIcon: Icon(Icons.card_membership_rounded),
                        label: LocalizedText('Hội viên'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.person_outline_rounded),
                        selectedIcon: Icon(Icons.person_rounded),
                        label: LocalizedText('Cá nhân'),
                      ),
                    ],
                  ),
                  VerticalDivider(width: 1, thickness: 1),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: 1120),
                        child: pages,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return Scaffold(
          backgroundColor: AppColors.background,
          body: pages,
          bottomNavigationBar: SafeArea(
            top: false,
            child: ModernBottomNav(
              currentIndex: _currentIndex,
              onTap: _selectTab,
            ),
          ),
        );
      },
    );
  }
}
