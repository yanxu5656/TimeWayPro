import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'pressable_scale.dart';

/// 圆形玻璃按钮。
///
/// 取代改造前散落在 task_card / daily_screen / 各页导航箭头上的手写
/// `Container(shape: circle, gradient: LinearGradient(...)) + GestureDetector`。
///
/// 与 [GlassCard] 不同，这里不叠 `InkWell`（圆形按钮不需要水波），
/// 因此可以安全地套 [PressableScale] 做按下回弹。
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.color = AppColors.primary,
    this.size = 44,
    this.iconSize = 24,
    this.tooltip,
    this.enabled = true,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color color;
  final double size;
  final double iconSize;
  final String? tooltip;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final Color effective = enabled ? color : AppColors.textHint;

    Widget button = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppGradients.softFill(effective),
      ),
      child: Icon(icon, color: effective, size: iconSize),
    );

    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }

    if (!enabled) return button;

    return PressableScale(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        // 保证语义树里仍然是可点击的按钮
        child: Semantics(button: true, label: tooltip, child: button),
      ),
    );
  }
}