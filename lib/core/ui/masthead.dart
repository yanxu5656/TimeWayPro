import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'glass_surface.dart';

/// 页面刊头：一条**单行**实心陶土色带（衬线标题 + 行内眉题），
/// 元信息行落在色带下方的纸面上作脚注。
///
/// 编辑风里标题属于**内容**而不是 chrome，所以 Tab 页不用顶栏，
/// 正文从刊头开始读。眉题是页面的「栏目名」（DAILY LIST / WEEKLY
/// LEDGER…），v1.10.0 起与标题同行基线对齐——大小两极仍在，
/// 但不再各占一行。
///
/// v1.10.0 瘦身：色带只留标题行（约 47dp），[meta] 移出色带。
/// 日期 / 周号 / 计数这些信息在日期行与进度行里本来就有第二份，
/// 脚注行用 12px 纸面次级色承载，整块刊头从 ~124dp 降到 ~76dp，
/// 把空间还给列表。色带上的文字一律用 [context.colors.textOnPrimary] /
/// [context.colors.textOnPrimaryMuted] 这两个实测过对比度的档位。
///
/// - [meta]：色带下方的一行脚注（`第 44 周 · 10/19 – 10/25 · VOL.359`）。
///   页面按纸面语义配色（次级文字 + 陶土数字），这里原样保留。
/// - [ghost]：右上角描边水印（当周/当日数字），缩小到 56px 并被色块
///   裁切——像印刷品被裁切一样，是刻意的。
class Masthead extends StatelessWidget {
  const Masthead({
    super.key,
    required this.kicker,
    required this.title,
    this.trailing,
    this.meta,
    this.ghost,
  });

  final String kicker;
  final String title;

  /// 标题右侧的补充（基线对齐），如统计页的刷新按钮
  final Widget? trailing;

  /// 色带下方的一行脚注（间隔号分节）
  final Widget? meta;

  /// 右上角描边水印（通常两位数字：当周 ISO 周号 / 当日日期）
  final String? ghost;

  static const TextStyle _ghostStyle = TextStyle(
    fontFamily: 'Playfair',
    fontSize: 56,
    fontWeight: FontWeight.w500,
    height: 0.85,
    letterSpacing: 0.01,
  );

  @override
  Widget build(BuildContext context) {
    if (context.isGlass) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(2, AppSpacing.xs, 2, AppSpacing.md),
        child: Stack(
          children: <Widget>[
            if (ghost != null)
              Positioned(
                top: -34,
                right: -8,
                child: ExcludeSemantics(
                  child: ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (Rect bounds) => LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        context.atmosphere.highlight.withValues(alpha: 0.17),
                        context.colors.primary.withValues(alpha: 0.025),
                      ],
                    ).createShader(bounds),
                    child: Text(
                      ghost!,
                      style: _ghostStyle.copyWith(
                        fontSize: 104,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: GlassSurface(
                        blur: false,
                        shadow: false,
                        interactiveLight: false,
                        borderRadius: BorderRadius.circular(999),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.auto_awesome_rounded,
                              size: 13,
                              color: context.colors.accent,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                kicker,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.text.kicker.copyWith(
                                  fontSize: 9,
                                  letterSpacing: 1.6,
                                  color: context.colors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    ?trailing,
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (Rect bounds) => LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      context.atmosphere.highlight,
                      context.atmosphere.highlight,
                      context.colors.primary.withValues(alpha: 0.88),
                    ],
                    stops: const <double>[0, 0.62, 1],
                  ).createShader(bounds),
                  child: Text(
                    title,
                    style: context.text.masthead.copyWith(
                      fontSize: 36,
                      height: 1.1,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -1.4,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (meta != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: context.colors.accent,
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: context.colors.accent.withValues(
                                alpha: 0.65,
                              ),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DefaultTextStyle.merge(
                          style: AppText.caption.copyWith(
                            color: context.colors.textSecondary,
                            letterSpacing: 0.2,
                          ),
                          child: meta!,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      );
    }

    final Paint ghostStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = context.colors.ghostOnPrimary;
    final Widget titleRow = Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        Text(
          title,
          style: context.text.masthead.copyWith(
            color: context.colors.textOnPrimary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        // 320dp 窄屏下眉题可截断，标题永远完整
        Flexible(
          child: Text(
            kicker,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.kicker.copyWith(
              color: context.colors.textOnPrimaryMuted,
            ),
          ),
        ),
        if (trailing != null) ...[
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.sm),
            child: trailing!,
          ),
        ],
      ],
    );

    final Widget band = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.cardPad,
        AppSpacing.xs,
        AppSpacing.cardPad,
        AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: context.colors.primary,
        borderRadius: BorderRadius.circular(context.shape.cardRadius),
      ),
      clipBehavior: Clip.hardEdge,
      child: ghost == null || !context.shape.showMastheadGhost
          ? titleRow
          : Stack(
              clipBehavior: Clip.hardEdge,
              children: <Widget>[
                Positioned(
                  top: -20,
                  right: -4,
                  child: ExcludeSemantics(
                    child: Text(
                      ghost!,
                      style: _ghostStyle.copyWith(foreground: ghostStroke),
                    ),
                  ),
                ),
                titleRow,
              ],
            ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          band,
          if (meta != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              child: DefaultTextStyle.merge(
                style: AppText.caption.copyWith(
                  fontSize: 12,
                  height: 1.4,
                  color: context.colors.textSecondary,
                  letterSpacing: 0.4,
                ),
                child: meta!,
              ),
            ),
        ],
      ),
    );
  }
}
