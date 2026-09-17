import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'pressable_scale.dart';

class _NavItemData {
  const _NavItemData(this.icon, this.activeIcon, this.label);
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// 广播玻璃底部导航的**实测高度**。
///
/// 为什么需要它：各页的 FAB 挂在页面自己的 `GlassScaffold` 上，而底部导航
/// 挂在 `MainScreen` 的 Scaffold 上。`MainScreen` 开了 `extendBody: true`
/// 让内容（和导航栏的模糊）延伸到屏幕底部，于是**内层 Scaffold 的底边就是
/// 屏幕底边**——它的 FAB 会被摆到 `屏幕高 - 16 - FAB高`，也就是压在导航栏
/// 底下。实测过：导航栏顶边 y=840.5，FAB 占 y=828..884，被盖住 43.5px。
///
/// 内层拿不到这个高度（外层的 Scaffold 不会把它注入 MediaQuery），所以由
/// [MainScreen] 实测后经这个 InheritedWidget 往下传。
class NavBarInset extends InheritedWidget {
  const NavBarInset({super.key, required this.height, required super.child});

  /// 玻璃导航栏的总高度（含设备底部安全区）；未测量到之前为 0
  final double height;

  /// 读取高度。不在 [NavBarInset] 之下（独立路由）时返回 0。
  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NavBarInset>()?.height ?? 0;

  @override
  bool updateShouldNotify(NavBarInset oldWidget) =>
      (oldWidget.height - height).abs() > 0.5;
}

/// 玻璃底部导航。
///
/// 取代改造前 `main_screen.dart` 里 68 行手写实现。原实现有三个问题：
/// 1. 选中态只有背景色在变（没有位置连续性，看不出"从哪滑到哪"）
/// 2. 图标是 `isSelected ? activeIcon : icon` 硬切换，无过渡
/// 3. 每项固定 `SizedBox(width: 56)`，窄屏会挤
///
/// 这里分别用 `AnimatedPositioned` 滑动指示块、`AnimatedSwitcher`
/// 交叉淡入、等分 `Expanded` 解决。
class GlassNavBar extends StatelessWidget {
  const GlassNavBar({
    super.key,
    required this.index,
    required this.onChanged,
    this.blurSigma = 18,
  });

  final int index;
  final ValueChanged<int> onChanged;
  final double blurSigma;

  static const List<_NavItemData> _items = <_NavItemData>[
    _NavItemData(Icons.today_outlined, Icons.today_rounded, '待办'),
    _NavItemData(
      Icons.check_circle_outline_rounded,
      Icons.check_circle_rounded,
      '任务',
    ),
    _NavItemData(Icons.bar_chart_rounded, Icons.bar_chart_rounded, '统计'),
    _NavItemData(Icons.account_tree_outlined, Icons.account_tree_rounded, '规划'),
    _NavItemData(Icons.settings_outlined, Icons.settings_rounded, '设置'),
  ];

  /// 指示块尺寸。高度与 [_NavItem] 里图标区一致，滑动时不会上下跳。
  static const double pillWidth = 56;
  static const double pillHeight = 34;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.glassFillWeak,
              border: Border(
                top: BorderSide(color: AppColors.glassEdgeBottom, width: 0.5),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final double itemW = constraints.maxWidth / _items.length;

                    return Stack(
                      children: <Widget>[
                        // 滑动指示块
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                          left: index * itemW + (itemW - pillWidth) / 2,
                          top: 0,
                          width: pillWidth,
                          height: pillHeight,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.glassTintPrimary,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                          ),
                        ),
                        Row(
                          children: <Widget>[
                            for (int i = 0; i < _items.length; i++)
                              Expanded(
                                child: _NavItem(
                                  data: _items[i],
                                  selected: i == index,
                                  onTap: () => onChanged(i),
                                ),
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final _NavItemData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              height: GlassNavBar.pillHeight,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutCubic,
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: Tween<double>(
                              begin: 0.86,
                              end: 1.0,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                  child: Icon(
                    selected ? data.activeIcon : data.icon,
                    // key 必须随选中态变化，否则 AnimatedSwitcher
                    // 认不出是新 child，不会播过渡
                    key: ValueKey<bool>(selected),
                    size: 22,
                    color: selected ? AppColors.primary : AppColors.textHint,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              style: (selected ? AppText.navLabelActive : AppText.navLabel)
                  .copyWith(
                    color: selected ? AppColors.primary : AppColors.textHint,
                  ),
              child: Text(data.label),
            ),
          ],
        ),
      ),
    );
  }
}
