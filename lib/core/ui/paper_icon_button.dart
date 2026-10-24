import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'pressable_scale.dart';

/// 圆形墨色图标按钮。
///
/// 静止时无底（图标直接长在纸上），按压由 [PressableScale] 提供反馈。
/// 需要可见的「可点区域」时由调用方传浅底（如日期箭头传 inkFaint）。
class PaperIconButton extends StatelessWidget {
  const PaperIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.color = AppColors.textPrimary,
    this.size = sizeAction,
    this.iconSize = 24,
    this.tooltip,
    this.enabled = true,
  });

  /// 顶栏 action、日期箭头。受顶栏高度（kToolbarHeight = 56）约束。
  static const double sizeChrome = 40;

  /// 列表内的动作按钮（开始 / 停止）。留够 44 的触摸目标。
  static const double sizeAction = 44;

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

    Widget button = SizedBox(
      width: size,
      height: size,
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
