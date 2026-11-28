import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'pressable_scale.dart';

/// 陶土胶囊悬浮按钮。
///
/// 页面上唯一的「重」元素：整块陶土压在暖纸上，天然是对比度最高的
/// 东西，正好配「当前页的主操作」。与刊头色带同色，前后呼应。
/// 放在 `Scaffold.floatingActionButton` 槽位即可。
///
/// v1.9.0：按下时不只是缩放——投影同步压缩（e2 → 贴近纸面）+
/// 整体下沉 1.5px，读起来像「按进纸里」而不是「缩小一圈」。
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

    Widget fab = PressableScale(
      enabled: onPressed != null,
      pressOffset: 1.5,
      builder: (BuildContext context, double press, Widget? child) {
        return Container(
          decoration: BoxDecoration(
            color: context.isGlass ? null : context.colors.primary,
            gradient: context.isGlass
                ? LinearGradient(
                    colors: <Color>[
                      context.colors.primary,
                      Color.lerp(
                        context.colors.primary,
                        context.colors.accent,
                        0.72,
                      )!,
                    ],
                  )
                : null,
            border: context.isGlass
                ? Border.all(color: Colors.white.withValues(alpha: 0.5))
                : null,
            borderRadius: AppRadius.brFull,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: context.isGlass
                    ? context.atmosphere.glow.withValues(alpha: 0.7)
                    : Color.lerp(
                        context.colors.shadowMedium,
                        context.colors.shadow,
                        press,
                      )!,
                blurRadius: lerpDouble(
                  context.shape.floatShadows.first.blurRadius,
                  6,
                  press,
                )!,
                offset: Offset(0, lerpDouble(10, 2, press)!),
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(
            horizontal: extended ? AppSpacing.lg : AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: child,
        );
      },
      child: GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: Semantics(
          button: true,
          label: label,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, color: context.colors.textOnPrimary, size: 21),
              if (extended) ...<Widget>[
                const SizedBox(width: AppSpacing.xs),
                Text(
                  label!,
                  style: AppText.labelLg.copyWith(
                    color: context.colors.textOnPrimary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (heroTag != null) {
      fab = Hero(tag: heroTag!, child: fab);
    }

    return fab;
  }
}
