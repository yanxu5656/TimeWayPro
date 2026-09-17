import 'package:flutter/material.dart';
import '../core/ui/glass.dart';
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

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  /// 当前 Tab 序号。位置与 [_screens] 的顺序一一对应，
  /// 页面侧的 `StaggerScope(slotIndex:)` 依赖这个顺序。
  int _currentIndex = 0;

  /// 用来实测玻璃导航栏的高度，供页面侧的 FAB 避让。
  /// 详见 [NavBarInset] 的文档。
  final GlobalKey _navBarKey = GlobalKey();
  double _navBarHeight = 0;

  final List<Widget> _screens = const [
    DailyScreen(), // 0 待办
    TaskScreen(), // 1 任务
    StatisticsScreen(), // 2 统计
    PlanningScreen(), // 3 规划
    SettingsScreen(), // 4 设置
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
    // "我这一页现在是不是可见"。IndexedStack 会保活全部 5 页，
    // 只看"有没有被 build"的话，非首屏的入场动画会在启动瞬间播完，
    // 用户切过去时什么也看不到。
    return TabVisibility(
      index: _currentIndex,
      child: NavBarInset(
        height: _navBarHeight,
        child: Scaffold(
          // 极光的实底由 AuroraBackground 自己画；这里再兜一层纯色，
          // 避免首帧极光尚未光栅化时闪一下白。
          backgroundColor: AppColors.background,
          // 内容延伸到玻璃底部导航之下——GlassNavBar 的 BackdropFilter
          // 依赖这一条，否则它模糊的是 Scaffold 底色，视觉上毫无意义。
          //
          // 代价是各页自己的 Scaffold 底边也变成了屏幕底边，它们的 FAB
          // 会压到导航栏下面，所以要用 NavBarInset 把高度传下去让页面避让。
          extendBody: true,
          body: Stack(
            children: [
              // 全应用唯一一份极光。不能每屏自带：IndexedStack 保活 5 屏，
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
          bottomNavigationBar: GlassNavBar(
            key: _navBarKey,
            index: _currentIndex,
            onChanged: (index) => setState(() => _currentIndex = index),
          ),
        ),
      ),
    );
  }
}