import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'pressable_scale.dart';

/// 墨色胶囊悬浮按钮。
///
/// 编辑风里唯一的「重」元素：整块墨色压在纸面上，天然是页面上
/// 对比度最高的东西，正好配「当前页的主操作」。
/// 放在 `Scaffold.floatingActionButton` 槽位即可。
class PaperFab extends StatelessWidget {
  const PaperFab({
    super.key,
    required this.onPressed,
    this.icon = Icons.add_rounded,
    this.label,
    this.heroTag,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String? label;

  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final bool extended = label != null;

    Widget fab = Container(
      decoration: const BoxDecoration(
        color: AppColors.textPrimary,
        borderRadius: AppRadius.brFull,
        boxShadow: AppShadows.e2,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: extended ? AppSpacing.lg : AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: AppColors.textOnInk, size: 21),
          if (extended) ...<Widget>[
            const SizedBox(width: AppSpacing.xs),
            Text(
              label!,
              style: AppText.labelLg.copyWith(color: AppColors.textOnInk),
            ),
          ],
        ],
      ),
    );

    fab = PressableScale(
      enabled: onPressed != null,
      child: GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: Semantics(button: true, label: label, child: fab),
      ),
    );

    if (heroTag != null) {
      fab = Hero(tag: heroTag!, child: fab);
    }

    return fab;
  }
}
