import 'package:flutter/material.dart';

import 'ui_effects.dart';

/// 数字滚动文本。
///
/// ## 为什么不解析字符串
///
/// 统计页展示的是 `_formatDuration` 的结果（`3h 20m` / `45m` / `12s`），
/// 不是纯数字。与其去解析字符串里的数字部分，不如把**数值和格式化函数**
/// 一起传进来——动画只作用在整数秒上，渲染时才格式化。这样
/// `3h 20m` 和 `3小时20分钟` 两种格式都能工作。
///
/// 用 Flutter 内置的 `IntTween` + `TweenAnimationBuilder`，零自定义 State、
/// 零新依赖。值变化时它从**当前值**动画到新值（而不是从 0 重来），
/// 正好是"切换日期时数字滚动"的期望行为。
class CountUpText extends StatelessWidget {
  const CountUpText({
    super.key,
    required this.value,
    required this.format,
    this.style,
    this.duration = const Duration(milliseconds: 650),
    this.curve = Curves.easeOutCubic,
    this.textAlign,
  });

  final int value;

  /// 把动画中的整数秒渲染成展示文本
  final String Function(int value) format;

  final TextStyle? style;
  final Duration duration;
  final Curve curve;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: TweenAnimationBuilder<int>(
        tween: IntTween(begin: 0, end: value),
        duration: UiEffects.countUp ? duration : Duration.zero,
        curve: curve,
        builder: (BuildContext context, int v, Widget? _) =>
            Text(format(v), style: style, textAlign: textAlign),
      ),
    );
  }
}
