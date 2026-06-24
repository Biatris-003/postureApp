import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';

import 'home_tab.dart';
import 'monitoring_tab.dart';
import 'assistant_tab.dart';
import 'statistics_tab.dart';
import 'exercises_tab.dart';
import 'spine_view_tab.dart';
import 'profile_tab.dart';

class MemberDashboardScreen extends ConsumerStatefulWidget {
  const MemberDashboardScreen({super.key});

  @override
  ConsumerState<MemberDashboardScreen> createState() =>
      _MemberDashboardScreenState();
}

class _MemberDashboardScreenState
    extends ConsumerState<MemberDashboardScreen> {
  int _currentIndex = 0;
  int _progressSubIndex = 0;

  void _switchToProgress({int subIndex = 0}) {
    setState(() {
      _currentIndex = 3;
      _progressSubIndex = subIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;

    final tabs = [
      HomeTab(
        onGoToExercises: () => _switchToProgress(subIndex: 1),
        onGoToSpine: () => _switchToProgress(subIndex: 2),
      ),
      const MonitoringTab(),
      const AssistantTab(),
      _ProgressTab(
        key: ValueKey('progress_$_progressSubIndex'),
        initialSubIndex: _progressSubIndex,
      ),
      const ProfileTab(),
    ];

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,

      // ───────────── BOTTOM NAV (UNCHANGED) ─────────────
      bottomNavigationBar: isTablet
          ? null
          : Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(
                        icon: Icons.home_outlined, label: "Home", index: 0),
                    _buildNavItem(
                        icon: Icons.monitor_heart_outlined,
                        label: "Monitor",
                        index: 1),
                    _buildNavItem(
                        icon: Icons.assistant_outlined,
                        label: "Assistant",
                        index: 2),
                    _buildNavItem(
                        icon: Icons.trending_up_outlined,
                        label: "Progress",
                        index: 3),
                    _buildNavItem(
                        icon: Icons.person_outline,
                        label: "Profile",
                        index: 4),
                  ],
                ),
              ),
            ),

      body: isTablet
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (i) =>
                      setState(() => _currentIndex = i),
                  backgroundColor: Colors.white,
                  useIndicator: true,
                  indicatorColor:
                      AppColors.primaryDeep.withValues(alpha: 0.12),
                  selectedIconTheme:
                      const IconThemeData(color: AppColors.primaryDeep),
                  unselectedIconTheme:
                      IconThemeData(color: AppColors.textSecondaryLight),
                  selectedLabelTextStyle: const TextStyle(
                    color: AppColors.primaryDeep,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                  unselectedLabelTextStyle: TextStyle(
                    color: AppColors.textSecondaryLight,
                    fontSize: 12,
                  ),
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home),
                        label: Text('Home')),
                    NavigationRailDestination(
                        icon: Icon(Icons.sensors_outlined),
                        selectedIcon: Icon(Icons.sensors),
                        label: Text('Monitor')),
                    NavigationRailDestination(
                        icon: Icon(Icons.chat_bubble_outline),
                        selectedIcon: Icon(Icons.chat_bubble),
                        label: Text('Assistant')),
                    NavigationRailDestination(
                        icon: Icon(Icons.bar_chart_outlined),
                        selectedIcon: Icon(Icons.bar_chart),
                        label: Text('Progress')),
                    NavigationRailDestination(
                        icon: Icon(Icons.person_outline),
                        selectedIcon: Icon(Icons.person),
                        label: Text('Profile')),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    child: KeyedSubtree(
                      key: ValueKey<int>(_currentIndex),
                      child: tabs[_currentIndex],
                    ),
                  ),
                ),
              ],
            )
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.04, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                        parent: animation, curve: Curves.easeOut),
                  ),
                  child: child,
                ),
              ),
              child: KeyedSubtree(
                key: ValueKey<int>(_currentIndex),
                child: tabs[_currentIndex],
              ),
            ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 14 : 10,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryMid : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color:
                  isSelected ? Colors.white : AppColors.textSecondaryLight,
            ),
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────── PROGRESS TAB (NEW HEADER VERSION) ─────────────────────

class _ProgressTab extends StatefulWidget {
  final int initialSubIndex;

  const _ProgressTab({super.key, this.initialSubIndex = 0});

  @override
  State<_ProgressTab> createState() => _ProgressTabState();
}

class _ProgressTabState extends State<_ProgressTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _labels = ['Statistics', 'Exercises', 'Spine'];
  static const _icons = [
    Icons.bar_chart_rounded,
    Icons.self_improvement_outlined,
    Icons.accessibility_new,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialSubIndex,
    );
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(_ProgressTab old) {
    super.didUpdateWidget(old);
    if (old.initialSubIndex != widget.initialSubIndex) {
      _tabController.animateTo(widget.initialSubIndex);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ───────── HEADER ─────────
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryDeep,
                AppColors.primaryMid,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'My Progress',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Track posture trends, exercises and spine health',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // segmented switcher
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: List.generate(3, (i) {
                        final isSelected = _tabController.index == i;

                        return Expanded(
                          child: GestureDetector(
                            onTap: () => _tabController.animateTo(i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _icons[i],
                                    size: 18,
                                    color: isSelected
                                        ? AppColors.primaryDeep
                                        : Colors.white70,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _labels[i],
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? AppColors.primaryDeep
                                          : Colors.white70,
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
                ],
              ),
            ),
          ),
        ),

        // ───────── CONTENT ─────────
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              StatisticsTab(),
              ExercisesTab(),
              SpineViewTab(),
            ],
          ),
        ),
      ],
    );
  }
}