import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/ui/aurora_background.dart';
import '../features/daily/presentation/screens/daily_screen.dart';
import '../features/task/presentation/screens/task_screen.dart';
import '../features/statistics/presentation/screens/statistics_screen.dart';
import '../features/planning/presentation/screens/planning_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DailyScreen(),
    TaskScreen(),
    StatisticsScreen(),
    PlanningScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 极光的实底由 AuroraBackground 自己画；这里再兜一层纯色，
      // 避免首帧极光尚未光栅化时闪一下白。
      backgroundColor: AppColors.background,
      // 内容延伸到玻璃底部导航之下——Phase 4 的 BackdropFilter 依赖这一条，
      // 否则它模糊的是 Scaffold 底色，视觉上毫无意义。
      extendBody: true,
      body: Stack(
        children: [
          // 全应用唯一一份。不能每屏自带：IndexedStack 会保活 5 屏，
          // 5 个相位不同的控制器会让背景在切 Tab 时跳变。
          const Positioned.fill(child: AuroraBackground()),
          Positioned.fill(
            // 双向隔离：列表滚动不触发极光层重栅格化，极光漂移也不重绘列表
            child: RepaintBoundary(
              child: IndexedStack(
                index: _currentIndex,
                children: _screens,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(
              color: AppColors.divider.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.today_outlined, Icons.today_rounded, '待办'),
                _buildNavItem(1, Icons.check_circle_outline_rounded, Icons.check_circle_rounded, '任务'),
                _buildNavItem(2, Icons.bar_chart_rounded, Icons.bar_chart_rounded, '统计'),
                _buildNavItem(3, Icons.account_tree_outlined, Icons.account_tree_rounded, '规划'),
                _buildNavItem(4, Icons.settings_outlined, Icons.settings_rounded, '设置'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primarySubtle : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isSelected ? activeIcon : icon,
                color: isSelected ? AppColors.primary : AppColors.textHint,
                size: 22,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textHint,
                letterSpacing: 0.2,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
