import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'glass_surface.dart';

/// 表面档位。
///
/// 陶土暖笺把分层工具从「细线」换回**卡片**，但不是所有卡都浮起来：
/// 同屏阴影数量要克制，所以只有列表项带阴影，大容器用描边卡。
enum PaperTone {
  /// 透明、无线——卡内的裸容器（新建页的时段/类型选择行）
  flat,

  /// 分区卡：暖白底 + 发丝描边 + 圆角，**不带阴影**。
  /// 统计页的图表块、设置页的分组这类大容器用它——安静地圈出范围，
  /// 不与里面的列表项抢体量
  ruled,

  /// 列表项卡：暖白底 + 圆角 + 两层暖阴影。账本行（待办 / 每周目标 /
  /// 任务）用它，是页面上真正「浮起」的东西。相邻项之间的间距由
  /// 调用方用 `margin` 给出
  row,

  /// 卡内嵌套块：暖沙底 + 发丝描边 + 小一档圆角，不带阴影。
  /// 嵌在分区卡里的状态卡用它——再叠一层阴影会糊
  raised,
}

/// 暖白卡片。
///
/// 四种表面档位见 [PaperTone]。与「静白志」的对应关系：flat 不变、
/// ruled 从「上下发丝线」变成描边卡、row 从「下缘发丝线」变成浮起卡、
/// raised 从纯白浮起块变成卡内嵌套块。
///
/// [tint] 是强调态（已完成 / 计时进行中）：所有卡片档位统一换成该色
/// 细描边 + 极浅填充。**不用左缘竖线**——BoxDecoration 的 borderRadius
/// 不能与非均匀 Border 同用，圆角卡上的着重线只能靠整圈描边表达。
class PaperCard extends StatelessWidget {
  const PaperCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.cardPad),
    this.margin = EdgeInsets.zero,
    this.radius,
    this.tone = PaperTone.ruled,
    this.fill,
    this.tint,
    this.onTap,
    this.onLongPress,
    this.shadows,
    this.animate = false,
    this.semanticLabel,
  });

  final Widget child;

  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  /// 除 [PaperTone.flat] 外都生效
  final double? radius;

  final PaperTone tone;

  /// 直接指定填充色，覆盖 [tone] 派生的值
  final Color? fill;

  /// 强调色（已完成 / 计时进行中 = success）
  final Color? tint;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// 覆盖默认阴影（仅 row 档有默认阴影）
  final List<BoxShadow>? shadows;

  /// 仅在值会变化的卡片上开（计时状态切换），静止卡片保持普通 Container
  final bool animate;

  final String? semanticLabel;

  BoxDecoration _decoration(BuildContext context) {
    if (tone == PaperTone.flat) {
      return BoxDecoration(color: tint?.withValues(alpha: 0.05));
    }

    final bool nested = tone == PaperTone.raised;
    final double effectiveRadius = radius ?? context.shape.cardRadius;
    final double nestedRadius = context.shape.controlRadius;
    final Color base =
        fill ??
        (nested ? context.colors.surfaceVariant : context.colors.surface);
    final Border border = tint != null
        ? Border.all(color: tint!.withValues(alpha: 0.55), width: 1.4)
        : Border.all(color: context.colors.divider);

    return BoxDecoration(
      color: tint == null
          ? base
          : Color.alphaBlend(tint!.withValues(alpha: 0.05), base),
      borderRadius: BorderRadius.circular(
        nested ? nestedRadius : effectiveRadius,
      ),
      border: border,
      boxShadow: tone == PaperTone.row
          ? (shadows ?? context.shape.rowShadows)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (context.isGlass && tone != PaperTone.flat) {
      final Color? fill =
          this.fill ??
          (tint == null
              ? null
              : Color.alphaBlend(
                  tint!.withValues(alpha: 0.12),
                  context.atmosphere.glassFill,
                ));
      Widget glass = GlassSurface(
        borderRadius: BorderRadius.circular(
          tone == PaperTone.raised
              ? context.shape.controlRadius
              : radius ?? context.shape.cardRadius,
        ),
        padding: padding,
        margin: margin,
        fill: fill,
        blur: tone == PaperTone.row,
        shadow: tone == PaperTone.row,
        child: child,
      );
      if (onTap != null || onLongPress != null) {
        glass = Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(context.shape.cardRadius),
            child: glass,
          ),
        );
      }
      return semanticLabel == null
          ? glass
          : Semantics(label: semanticLabel, container: true, child: glass);
    }

    final bool interactive = onTap != null || onLongPress != null;
    final double effectiveRadius = radius ?? context.shape.cardRadius;

    Widget surface = animate
        ? AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            padding: padding,
            decoration: _decoration(context),
            child: child,
          )
        : Container(
            padding: padding,
            decoration: _decoration(context),
            child: child,
          );

    if (interactive) {
      surface = Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(
            tone == PaperTone.raised
                ? context.shape.controlRadius
                : effectiveRadius,
          ),
          splashColor: context.colors.inkSubtle,
          highlightColor: context.colors.inkFaint,
          child: surface,
        ),
      );
    }

    if (semanticLabel != null) {
      surface = Semantics(
        label: semanticLabel,
        container: true,
        child: surface,
      );
    }

    return margin == EdgeInsets.zero
        ? surface
        : Padding(padding: margin, child: surface);
  }
}
