import 'package:flutter/material.dart';

/// 广播 `MainScreen` 当前选中的 Tab 序号。
///
/// ## 为什么需要它
///
/// `IndexedStack` 会**保活**全部 5 个页面——它们在 app 启动时就全部 build
/// 完毕。如果入场动画只看"我有没有被 build"，那么非首屏的动画会在启动瞬间
/// 偷偷播完，用户切过去时什么也看不到。
///
/// 所以入场动画必须知道"我这一页现在是不是可见"，并且只在**首次可见**时
/// 才播放。这个 InheritedWidget 就是那个广播源。
///
/// `MainScreen` 的 `setState` 只会让依赖它的 `StaggerScope` 重跑
/// `didChangeDependencies`（依赖者极少），不会重建整棵列表。
class TabVisibility extends InheritedWidget {
  const TabVisibility({super.key, required this.index, required super.child});

  final int index;

  /// 读取当前 Tab 序号。不在 [TabVisibility] 之下时返回 -1
  /// （表示"不受 Tab 切换管理"，独立路由属于这种情况）。
  static int maybeOf(BuildContext context) {
    final TabVisibility? widget = context
        .dependOnInheritedWidgetOfExactType<TabVisibility>();
    return widget?.index ?? -1;
  }

  @override
  bool updateShouldNotify(TabVisibility oldWidget) => oldWidget.index != index;
}
