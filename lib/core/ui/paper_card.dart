import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 表面档位。
///
/// 静白志的分层工具是**细线**而不是底色：长在纸面上的内容用 [flat]/
/// [ruled]，只有真正浮起的东西（弹窗内块、状态卡）用 [raised] 白底。
enum PaperTone {
  /// 透明、无线——页面里的裸容器。分隔线由页面统一画
  flat,

  /// 透明底 + 上下发丝线。独立分区（表格式的块）
  ruled,

  /// 账本行：透明底 + **仅下缘**发丝线（相邻行不会出现双线），
  /// [tint] 非空时左缘加着重线
  row,

  /// 纯白底 + 微影 + 圆角。浮起表面：弹窗内块、同步状态卡
  raised,
}

/// 纸面卡片。
///
/// 三种表面档位见 [PaperTone]。与玻璃版的对应关系：
/// subtle → flat、regular → ruled、strong → raised。
///
/// [tint] 是强调态（计时进行中）：raised 档换该色细描边 + 极浅填充；
/// ruled / flat 档在左缘加一条 2.5px 该色竖线（账本行的「着重线」）。
class PaperCard extends StatelessWidget {
  const PaperCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.cardPad),
    this.margin = EdgeInsets.zero,
    this.radius = AppRadius.lg,
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

  /// 仅 [PaperTone.raised] 生效
  final double radius;

  final PaperTone tone;

  /// 直接指定填充色，覆盖 [tone] 派生的值
  final Color? fill;

  /// 强调色（计时进行中 = success）
  final Color? tint;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// 覆盖默认阴影（仅 raised 档）
  final List<BoxShadow>? shadows;

  /// 仅在值会变化的卡片上开（计时状态切换），静止卡片保持普通 Container
  final bool animate;

  final String? semanticLabel;

  BorderSide get _hairSide => const BorderSide(color: AppColors.divider);

  BoxDecoration _decoration() {
    final BorderSide accent = BorderSide(
      color: tint ?? Colors.transparent,
      // 无 tint 时宽度归零：透明边也占布局空间
      width: tint == null ? 0 : 2.5,
    );
    switch (tone) {
      case PaperTone.flat:
        return BoxDecoration(
          color: tint?.withValues(alpha: 0.04),
        );
      case PaperTone.row:
        return BoxDecoration(
          color: fill,
          border: Border(
            bottom: _hairSide,
            left: accent,
          ),
        );
      case PaperTone.ruled:
        // 无圆角，非均匀 Border 合法（与 borderRadius 同用才会断言失败）
        return BoxDecoration(
          color: fill,
          border: Border(
            top: _hairSide,
            bottom: _hairSide,
            left: accent,
          ),
        );
      case PaperTone.raised:
        return BoxDecoration(
          color: fill ?? AppColors.surface,
          borderRadius: BorderRadius.circular(radius),
          border: tint != null
              ? Border.all(color: tint!.withValues(alpha: 0.55), width: 1.2)
              : null,
          boxShadow: shadows ?? AppShadows.e1,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool interactive = onTap != null || onLongPress != null;

    Widget surface = animate
        ? AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            padding: padding,
            decoration: _decoration(),
            child: child,
          )
        : Container(padding: padding, decoration: _decoration(), child: child);

    if (interactive) {
      surface = Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(radius),
          splashColor: AppColors.inkSubtle,
          highlightColor: AppColors.inkFaint,
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
