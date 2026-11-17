import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_haptics.dart';
import 'pressable_scale.dart';
import 'ui_effects.dart';

/// 完成勾选圆钮（墨圈 · 陶土）。
///
/// 静止是一个 1.4px 墨圈（账本行的「待办空位」），勾选后翻成
/// 陶土实心——完成是这个应用里最值得用强调色的一刻。
///
/// v1.9.0 的「完成时刻」：从空圈翻到实心的**那一瞬**，对勾带
/// easeOutBack 弹出来，圈外荡开一圈陶土涟漪，手上一次中等触觉。
/// 只在 false→true 的切换时庆祝——初始就已完成的数据（种子、
/// 翻回历史日期）安静渲染，不反复放礼花。
class InkCheckCircle extends StatefulWidget {
  const InkCheckCircle({
    super.key,
    required this.isChecked,
    required this.onTap,
    this.size = 28,
    this.color = AppColors.primary,
    this.semanticLabel,
  });

  final bool isChecked;
  final VoidCallback onTap;

  final double size;

  /// 选中时填充的强调色
  final Color color;

  final String? semanticLabel;

  @override
  State<InkCheckCircle> createState() => _InkCheckCircleState();
}

class _InkCheckCircleState extends State<InkCheckCircle> {
  bool _celebrate = false;

  @override
  void didUpdateWidget(InkCheckCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isChecked && widget.isChecked) {
      final bool reduced =
          MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      if (!reduced && UiEffects.tier.value != UiEffectTier.minimal) {
        setState(() => _celebrate = true);
      }
    }
  }

  void _handleTap() {
    // 完成用中等触觉、取消用轻触觉——手感分得出「做成了」和「改回去」。
    // PressableScale 的默认轻触觉在这里关掉，避免一次点击震两下。
    if (!widget.isChecked) {
      AppHaptics.success();
    } else {
      AppHaptics.tap();
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final bool reduced =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return PressableScale(
      haptic: false,
      child: GestureDetector(
        onTap: _handleTap,
        behavior: HitTestBehavior.opaque,
        child: Semantics(
          checked: widget.isChecked,
          label: widget.semanticLabel,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: <Widget>[
              AnimatedContainer(
                duration: reduced
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.isChecked
                        ? widget.color
                        // 空圈用 45% 墨，比文字轻、但仍在纸面上可见
                        : AppColors.textPrimary.withValues(alpha: 0.45),
                    width: 1.4,
                  ),
                  color: widget.isChecked ? widget.color : Colors.transparent,
                ),
                child: widget.isChecked
                    ? TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: 1),
                        duration: reduced
                            ? Duration.zero
                            : const Duration(milliseconds: 240),
                        curve: Curves.easeOutBack,
                        builder:
                            (BuildContext context, double t, Widget? child) =>
                                Transform.scale(scale: t, child: child),
                        child: Icon(
                          Icons.check,
                          size: widget.size * 0.57,
                          color: AppColors.textOnPrimary,
                        ),
                      )
                    : null,
              ),
              if (_celebrate)
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOut,
                  onEnd: () {
                    if (mounted) setState(() => _celebrate = false);
                  },
                  builder: (BuildContext context, double t, Widget? child) {
                    if (t >= 1) return const SizedBox.shrink();
                    return Transform.scale(
                      scale: 1 + 0.9 * t,
                      child: Opacity(opacity: 0.5 * (1 - t), child: child),
                    );
                  },
                  // 涟漪用普通 Container：测试以 AnimatedContainer 定位
                  // 圆钮本体，多一个动画容器会让尺寸断言产生歧义
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: widget.color, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}