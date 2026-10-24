import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'pressable_scale.dart';

/// 完成勾选圆钮。
///
/// 抽出来之前在两个地方各写了一遍，结构完全相同，只是尺寸（28 vs 26）
/// 和选中色（primary vs success）不同——是用户看到的一处明显不一致。
/// 现在统一为 28px + `success` 绿：这个 app 里「完成」一直是绿的
/// （待办卡边框、「已完成」徽标、任务页「完成任务」统计卡都是 success）。
class GlassCheckCircle extends StatelessWidget {
  const GlassCheckCircle({
    super.key,
    required this.isChecked,
    required this.onTap,
    this.size = 28,
    this.color = AppColors.success,
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
                    : AppColors.textHint.withValues(alpha: 0.5),
                width: 2,
              ),
              color: isChecked ? color : Colors.transparent,
            ),
            child: isChecked
                // 保持与原来 28/16 的比例
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
