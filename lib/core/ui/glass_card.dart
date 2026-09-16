import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'glass_surface.dart';

/// 玻璃卡片。
///
/// 取代改造前散落在 5 个页面里的 15 处手写 `Container + BoxDecoration`
/// 卡片（圆角在 14/16/20 之间摇摆、阴影模糊在 8/10 之间摇摆、
/// 有 2 处还硬编码了 `Colors.black.withOpacity(0.04)`）。
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.cardPad),
    this.margin = EdgeInsets.zero,
    this.radius = AppRadius.lg,
    this.tone = GlassTone.regular,
    this.tint,
    this.edgeWidth = 1.0,
    this.onTap,
    this.onLongPress,
    this.blur = false,
    this.blurSigma = 12,
    this.shadows,
    this.animate = false,
    this.semanticLabel,
  });

  final Widget child;

  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  final double radius;
  final GlassTone tone;

  /// 强调色（计时进行中 = success）。非空时描边与阴影走该色的强调态。
  final Color? tint;

  /// 描边宽度，进行中传 2.0
  final double edgeWidth;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// 是否用真 `BackdropFilter`。**列表里的卡片保持 false**——
  /// 十几张卡同时高斯模糊会让中低端机掉帧，而视觉上几乎无差别。
  final bool blur;
  final double blurSigma;

  final List<BoxShadow>? shadows;

  /// 仅在值会变化的卡片上开（计时状态切换），静止卡片保持普通 Container
  final bool animate;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final bool interactive = onTap != null || onLongPress != null;

    Widget surface = GlassSurface(
      radius: radius,
      tone: tone,
      tint: tint,
      edgeWidth: edgeWidth,
      shadows: shadows,
      animate: animate,
      blurSigma: blur ? blurSigma : null,
      // 可点击时 padding 由 InkWell 内部承担，否则整卡只有内容区可点
      padding: interactive ? null : padding,
      child: interactive
          ? Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                onLongPress: onLongPress,
                // InkWell 自己裁水波，不需要给 Material 加 clip 层
                borderRadius: BorderRadius.circular(
                  (radius - edgeWidth).clamp(0.0, double.infinity),
                ),
                splashColor: (tint ?? AppColors.primary).withValues(alpha: 0.08),
                highlightColor:
                    (tint ?? AppColors.primary).withValues(alpha: 0.04),
                child: Padding(padding: padding, child: child),
              ),
            )
          : child,
    );

    if (semanticLabel != null) {
      surface = Semantics(label: semanticLabel, container: true, child: surface);
    }

    return margin == EdgeInsets.zero
        ? surface
        : Padding(padding: margin, child: surface);
  }
}