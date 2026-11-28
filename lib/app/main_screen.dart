import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/ui/paper.dart';
import '../features/daily/presentation/screens/daily_screen.dart';
import '../features/focus/presentation/screens/focus_timer_screen.dart';
import '../features/focus/presentation/widgets/focus_alarm_banner.dart';
import '../features/focus/presentation/widgets/focus_timer_fab.dart';
import '../features/focus/providers/focus_timer_provider.dart';
import '../features/weekly/presentation/screens/weekly_screen.dart';
import '../features/task/presentation/screens/task_screen.dart';
import '../features/statistics/presentation/screens/statistics_screen.dart';
import '../features/planning/presentation/screens/planning_screen.dart';
import '../features/leisure/presentation/screens/leisure_screen.dart';
import '../features/calendar/presentation/screens/calendar_screen.dart';
import '../features/rewards/providers/reward_provider.dart';
import '../features/rewards/presentation/screens/reward_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  /// 当前 Tab 序号。位置与 [_screens] 的顺序一一对应，
  /// 页面侧的 `StaggerScope(slotIndex:)` 依赖这个顺序。
  int _currentIndex = 0;

  /// 用来实测底部导航栏的高度，供页面侧的 FAB 避让。
  /// 详见 [NavBarInset] 的文档。
  final GlobalKey _navBarKey = GlobalKey();
  double _navBarHeight = 0;
  Offset _focusFabShift = Offset.zero;

  final List<Widget> _screens = const [
    DailyScreen(), // 0 待办
    WeeklyScreen(), // 1 每周
    TaskScreen(), // 2 任务
    StatisticsScreen(), // 3 统计
    PlanningScreen(), // 4 规划
    LeisureScreen(), // 5 闲时
    CalendarScreen(), // 6 月历
    RewardScreen(), // 7 商店
    SettingsScreen(), // 8 设置
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 导航栏高度要等布局完成才知道（它含设备的底部安全区），
    // 量到之后回填一次。
    WidgetsBinding.instance.addPostFrameCallback(_measureNavBar);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 旋转 / 折叠屏等改变安全区时重新实测
  @override
  void didChangeMetrics() => _measureNavBar(const Duration());

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<FocusTimerProvider>().syncWithClock();
    }
  }

  void _openFocusTimer() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const FocusTimerScreen()));
  }

  void _measureNavBar(Duration _) {
    final RenderBox? box =
        _navBarKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !mounted) return;
    final double height = box.size.height;
    if ((height - _navBarHeight).abs() > 0.5) {
      setState(() => _navBarHeight = height);
    }
  }

  @override
  Widget build(BuildContext context) {
    // TabVisibility 必须包在 IndexedStack 之外：入场动画要能知道
    // "我这一页现在是不是可见"。IndexedStack 会保活全部页面，
    // 只看"有没有被 build"的话，非首屏的入场动画会在启动瞬间播完，
    // 用户切过去时什么也看不到。
    return TabVisibility(
      index: _currentIndex,
      child: NavBarInset(
        height: _navBarHeight,
        child: Scaffold(
          backgroundColor: context.isGlass
              ? Colors.transparent
              : Theme.of(context).scaffoldBackgroundColor,
          // 内容延伸到纸面底部导航之下，FAB 靠 NavBarInset 避让
          extendBody: true,
          body: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double baseBottom =
                  (_navBarHeight > 0 ? _navBarHeight : 76) + 16;
              final double minBottom = baseBottom - 8;
              final double maxBottom = math.max(
                minBottom,
                constraints.maxHeight - 104,
              );
              final double maxLeft = math.max(
                AppSpacing.xs,
                constraints.maxWidth - 132,
              );
              final double left = (AppSpacing.screenH + _focusFabShift.dx)
                  .clamp(AppSpacing.xs, maxLeft);
              final double bottom = (baseBottom - _focusFabShift.dy).clamp(
                minBottom,
                maxBottom,
              );

              return Stack(
                children: <Widget>[
                  RepaintBoundary(
                    child: IndexedStack(
                      index: _currentIndex,
                      children: _screens,
                    ),
                  ),
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + AppSpacing.xs,
                    left: AppSpacing.screenH,
                    right: AppSpacing.screenH,
                    child: FocusAlarmBanner(onOpenTimer: _openFocusTimer),
                  ),
                  Positioned(
                    left: left,
                    bottom: bottom,
                    child: FocusTimerFab(
                      onTap: _openFocusTimer,
                      onDragDelta: (Offset delta) {
                        setState(() {
                          final double nextLeft =
                              (AppSpacing.screenH +
                                      _focusFabShift.dx +
                                      delta.dx)
                                  .clamp(AppSpacing.xs, maxLeft);
                          final double nextBottom =
                              (baseBottom - _focusFabShift.dy - delta.dy).clamp(
                                minBottom,
                                maxBottom,
                              );
                          _focusFabShift = Offset(
                            nextLeft - AppSpacing.screenH,
                            baseBottom - nextBottom,
                          );
                        });
                      },
                    ),
                  ),
                ],
              );
            },
          ),
          bottomNavigationBar: PaperNavBar(
            key: _navBarKey,
            index: _currentIndex,
            onChanged: (int index) {
              setState(() => _currentIndex = index);
              if (index == 7) context.read<RewardProvider>().load();
            },
          ),
        ),
      ),
    );
  }
}
