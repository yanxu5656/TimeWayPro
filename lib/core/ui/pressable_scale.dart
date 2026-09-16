import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 按下回弹。
///
/// ## 为什么用 `Listener` 而不是 `GestureDetector`
///
/// 嵌套 `GestureDetector` 时，内层 `InkWell` 会赢下手势竞技场，外层的
/// `onTapDown` 根本不触发。`Listener` 走原始指针事件，无论谁最终赢得
/// 手势竞争都能收到按下/抬起。
///
/// ## 为什么不用 `AnimatedScale`
///
/// `AnimatedScale` 双向同曲线、无 overshoot，"回弹"手感做不出来。
/// 这里用 `AnimationController` 的**不对称曲线**：压下 `easeOut`
/// （quick 响应），释放 `easeOutBack`（回弹时缩过按下值约 0.2%）。
///
/// ## 一个必须知道的边界：快按快放不回弹
///
/// `CurvedAnimation` 的 `reverseCurve` **只在正向动画已经 completed 之后
/// 才生效**（见 Flutter animation/animations.dart 里的 `_useForwardCurve`
/// 与 `_curveDirection`：若反向开始时正向仍在跑，`_curveDirection` 还是
/// `forward`，于是继续用正向曲线）。
///
/// 结果是：
/// - 按住 ≥ [pressDuration]（默认 110ms）再松手 → 走 `reverseCurve`，有回弹
/// - 快速点击（< 110ms）→ 走正向曲线，干净利落地弹回，无回弹
///
/// 这个差异观感上可以接受（快点击本来就该更干脆），因此没有为它引入
/// 两段式弹簧动画。两条分支都有测试钉住，见
/// test/core/ui/pressable_scale_test.dart。
///
/// ## 8px 移动阈值
///
/// 解决"在列表里按下后开始滚动，卡片一直保持缩小"的粘滞感：
/// 指针移动超过 8px 即取消压下态。
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.scale = 0.965,
    this.pressDuration = const Duration(milliseconds: 110),
    this.releaseDuration = const Duration(milliseconds: 220),
    this.haptic = true,
    this.enabled = true,
  });

  final Widget child;

  /// 按下时缩到的比例
  final double scale;

  final Duration pressDuration;
  final Duration releaseDuration;

  /// 是否触发轻触觉反馈
  final bool haptic;

  final bool enabled;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale>
    with SingleTickerProviderStateMixin {
  static const double _cancelThreshold = 8.0;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.pressDuration,
    reverseDuration: widget.releaseDuration,
  );

  late final Animation<double> _scale = Tween<double>(
    begin: 1.0,
    end: widget.scale,
  ).animate(CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
    reverseCurve: Curves.easeOutBack,
  ));

  final Set<int> _pointers = <int>{};
  Offset? _origin;
  bool _moved = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDown(PointerDownEvent event) {
    if (!widget.enabled) return;
    _pointers.add(event.pointer);
    if (_pointers.length == 1) {
      _origin = event.position;
      _moved = false;
      _controller.forward();
      if (widget.haptic) HapticFeedback.selectionClick();
    }
  }

  void _onMove(PointerMoveEvent event) {
    if (_moved || _origin == null) return;
    if ((event.position - _origin!).distance > _cancelThreshold) {
      _moved = true;
      _release();
    }
  }

  void _onUp(PointerUpEvent event) {
    _pointers.remove(event.pointer);
    if (_pointers.isEmpty) _release();
  }

  void _release() {
    _pointers.clear();
    _origin = null;
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onDown,
      onPointerMove: _onMove,
      onPointerUp: _onUp,
      onPointerCancel: (_) => _release(),
      // 必须是 opaque 而不是 deferToChild：
      // deferToChild 只在**子节点自己可命中**时才挂上监听，于是有内边距的
      // 按钮、或被 Transform 包裹的圆形按钮（子节点无实心可命中区域）会出现
      // "按边缘区域没反应"。opaque 让整个盒子都可命中，且因为
      // hitTestChildren 先于 hitTestSelf，子节点的手势仍然优先——
      // Listener 不参与手势竞技场，只旁听原始指针事件。
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: widget.child,
      ),
    );
  }
}