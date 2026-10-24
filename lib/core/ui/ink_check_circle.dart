import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'pressable_scale.dart';

/// 完成勾选圆钮（墨圈 · 朱砂）。
///
/// 静止是一个 1.4px 墨圈（账本行的「待办空位」），勾选后翻成
/// 朱砂实心——完成是这个应用里最值得用强调色的一刻。
class InkCheckCircle extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return PressableScale(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Semantics(
          checked: isChecked,
          label: semanticLabel,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isChecked
                    ? color
                    // 空圈用 45% 墨，比文字轻、但仍在纸面上可见
                    : AppColors.textPrimary.withValues(alpha: 0.45),
                width: 1.4,
              ),
              color: isChecked ? color : Colors.transparent,
            ),
            child: isChecked
                ? Icon(
                    Icons.check,
                    size: size * 0.57,
                    color: AppColors.textOnPrimary,
                  )
                : null,
          ),
        ),
      ),
    );
  }
}
