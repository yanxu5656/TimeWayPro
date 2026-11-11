import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'pressable_scale.dart';

/// 陶土胶囊悬浮按钮。
///
/// 页面上唯一的「重」元素：整块陶土压在暖纸上，天然是对比度最高的
/// 东西，正好配「当前页的主操作」。与刊头色带同色，前后呼应。
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
        color: AppColors.primary,
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
          Icon(icon, color: AppColors.textOnPrimary, size: 21),
          if (extended) ...<Widget>[
            const SizedBox(width: AppSpacing.xs),
            Text(
              label!,
              style: AppText.labelLg.copyWith(color: AppColors.textOnPrimary),
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
