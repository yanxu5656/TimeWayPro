import 'package:flutter/material.dart';

import 'tab_visibility.dart';
import 'ui_effects.dart';

/// 把错峰入场所需的控制器传给 [StaggeredEntrance]。
class _StaggerData extends InheritedWidget {
  const _StaggerData({
    required this.controller,
    required this.itemDelayMs,
    required this.itemDurationMs,
    required this.totalMs,
    required this.maxItems,
    required super.child,
  });

  final AnimationController controller;
  final double itemDelayMs;
  final double itemDurationMs;
  final double totalMs;
  final int maxItems;

  static _StaggerData? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_StaggerData>();

  @override
  bool updateShouldNotify(_StaggerData oldWidget) =>
      oldWidget.controller != controller;
}

/// 列表错峰入场的控制器与作用域。
///
/// 放在列表的父层，[StaggeredEntrance] 从 context 里取。
///
/// ## 播放时机
///
/// [slotIndex] 是本页在 `MainScreen` 里的 Tab 序号。`StaggerScope` 会在
/// `didChangeDependencies` 里判断"本页是否首次可见"，只有首次可见才
/// `forward(from: 0)`——否则 `IndexedStack` 保活的页面会在启动时把动画
/// 偷偷播完。传 -1 表示不受 Tab 管理（独立路由），立即播放。
class StaggerScope extends StatefulWidget {
  const StaggerScope({
    super.key,
    required this.child,
    this.slotIndex = -1,
    this.itemDelay = const Duration(milliseconds: 45),
    this.maxItems = 8,
    this.itemDuration = const Duration(milliseconds: 320),
  });

  final Widget child;
  final int slotIndex;
  final Duration itemDelay;
  final int maxItems;
  final Duration itemDuration;

  @override
  State<StaggerScope> createState() => _StaggerScopeState();
}

class _StaggerScopeState extends State<StaggerScope>
    with SingleTickerProviderStateMixin {
  late final Duration _total = widget.itemDelay * widget.maxItems +
      widget.itemDuration;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _total,
    value: 0,
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;

    if (!UiEffects.stagger) {
      _controller.value = 1.0;
      _started = true;
      return;
    }

    if (widget.slotIndex < 0) {
      // 独立路由，直接播
      _started = true;
      _controller.forward(from: 0);
      return;
    }

    // 只有本页成为当前 Tab 时才播
    if (TabVisibility.maybeOf(context) == widget.slotIndex) {
      _started = true;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _StaggerData(
      controller: _controller,
      itemDelayMs: widget.itemDelay.inMilliseconds.toDouble(),
      itemDurationMs: widget.itemDuration.inMilliseconds.toDouble(),
      totalMs: _total.inMilliseconds.toDouble(),
      maxItems: widget.maxItems,
      child: widget.child,
    );
  }
}

/// 单个入场项。
///
/// `index >= maxItems` 时**直接返回 child**，零动画对象——所以
/// `ListView.builder` 里第 9 项起完全静态，不会产生 8 个以上的动画。
///
/// 位移固定 8px 用 `Transform.translate` 而非 `SlideTransition`：
/// 后者是子项高度的百分比，卡片高度不同会导致位移量不一致。
class StaggeredEntrance extends StatelessWidget {
  const StaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final _StaggerData? data = _StaggerData.maybeOf(context);
    if (data == null ||
        index >= data.maxItems ||
        !UiEffects.stagger ||
        data.totalMs <= 0) {
      return child;
    }

    final double start = ((index * data.itemDelayMs) / data.totalMs).clamp(0, 1);
    // 单项动画跨度占整条时间轴的比例。总时长 = maxItems*delay + duration，
    // 所以最后一项的区间末尾是 (maxItems-1)*delay+duration < total，不会越界。
    final double span = (data.itemDurationMs / data.totalMs).clamp(0.05, 1.0);

    final Animation<double> animation = CurvedAnimation(
      parent: data.controller,
      curve: Interval(start, (start + span).clamp(0, 1), curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: animation,
      child: AnimatedBuilder(
        animation: animation,
        builder: (BuildContext context, Widget? c) => Transform.translate(
          offset: Offset(0, 8 * (1 - animation.value)),
          child: c,
        ),
        child: child,
      ),
    );
  }
}