import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'glass_surface.dart';
import 'pressable_scale.dart';

/// 玻璃悬浮按钮（胶囊形）。
///
/// 取代改造前 3 处 `FloatingActionButton` / `FloatingActionButton.extended`。
/// 放在 `Scaffold.floatingActionButton` 槽位即可——Scaffold 的定位与
/// 入场动画对任意 Widget 都生效。
class GlassFab extends StatelessWidget {
  const GlassFab({
    super.key,
    required this.onPressed,
    this.icon = Icons.add_rounded,
    this.label,
    this.blurSigma = 16,
    this.blur = true,
    this.heroTag,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String? label;
  final double blurSigma;

  /// 低端机降级开关：Android 7–9 上 `BackdropFilter` 有已知渲染瑕疵时
  /// 翻成 false，退化为着色玻璃。
  final bool blur;

  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final bool extended = label != null;

    Widget fab = GlassSurface(
      radius: AppRadius.full,
      tone: GlassTone.subtle,
      fill: AppColors.glassTintPrimary,
      tint: AppColors.primary,
      blurSigma: blur ? blurSigma : null,
      padding: EdgeInsets.symmetric(
        horizontal: extended ? AppSpacing.lg : AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: AppColors.primary, size: 22),
          if (extended) ...<Widget>[
            const SizedBox(width: AppSpacing.xs),
            Text(
              label!,
              style: AppText.labelLg.copyWith(color: AppColors.primary),
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
