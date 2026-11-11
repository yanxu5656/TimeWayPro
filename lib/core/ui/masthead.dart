import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 页面刊头：一整块实心陶土色带，里面是眉题（kicker）+ 衬线大标题 +
/// 可选元信息行。
///
/// 编辑风里标题属于**内容**而不是 chrome，所以六个 Tab 页不用顶栏，
/// 正文从刊头开始读。眉题是页面的「栏目名」（DAILY LIST / WEEKLY
/// LEDGER…），与标题形成大小两极，这是排版层级的主要来源。
///
/// 陶土暖笺把刊头从「纸上的铅线」改成**实心色块**：它是页面上最大的
/// 一块彩色，一眼就定了调，也把暖白卡衬得更亮。色块自身的边就是
/// 边界，所以不再画铅线。
///
/// 色带上的文字一律用 [AppColors.textOnPrimary] / [AppColors.textOnPrimaryMuted]
/// 这两个实测过对比度的档位，层级靠字号字距拉开——**不要**在这里
/// 用半透明的暖纸色，降到 80% 就跌破 AA 了。
///
/// - [meta]：标题下的一行元信息（`第 44 周 · 10/19 – 10/25 · VOL.359`），
///   把原先散在各处的期号/日期/计数收拢成一行，用间隔号分节。
///   色带会把 meta 里的强调数字统一改成奶油色，页面不需要自己配色。
/// - [ghost]：右上角的当周/当日巨号数字水印（描边空心，如 `44`），
///   给色带一个体量锚点。水印被色块裁切——像印刷品被裁切一样，是刻意的。
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

  /// 标题右侧的补充（基线对齐），如旧版期号。传了 [meta] 后一般不再用
  final Widget? trailing;

  /// 标题下方的一行元信息（间隔号分节）
  final Widget? meta;

  /// 右上角描边水印（通常两位数字：当周 ISO 周号 / 当日日期）
  final String? ghost;

  /// 水印描边画笔。暖白 26% 的空心描边——足够存在又不抢正文
  static final Paint _ghostStroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4
    ..color = AppColors.ghostOnPrimary;

  static const TextStyle _ghostStyle = TextStyle(
    fontFamily: 'Playfair',
    fontSize: 104,
    fontWeight: FontWeight.w500,
    height: 0.85,
    letterSpacing: 0.01,
  );

  @override
  Widget build(BuildContext context) {
    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    kicker,
                    style: AppText.kicker.copyWith(
                      color: AppColors.textOnPrimaryMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: AppText.masthead.copyWith(
                      color: AppColors.textOnPrimary,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: DefaultTextStyle(
                  style: AppText.caption.copyWith(
                    color: AppColors.textOnPrimaryMuted,
                  ),
                  child: trailing!,
                ),
              ),
          ],
        ),
        if (meta != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            // 页面传进来的 meta 是按纸面配色的（次级文字 + 陶土数字）。
            // 色带上这套颜色会看不见，所以在这里统一接管：底字换暖白，
            // 被强调的数字换奶油。页面不需要知道刊头是什么材料。
            child: DefaultTextStyle.merge(
              style: AppText.caption.copyWith(
                color: AppColors.textOnPrimaryMuted,
                letterSpacing: 0.4,
              ),
              child: _RecolorMeta(child: meta!),
            ),
          ),
      ],
    );

    final Widget band = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.cardPad,
        AppSpacing.md,
        AppSpacing.cardPad,
        AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: AppRadius.brCard,
      ),
      clipBehavior: Clip.hardEdge,
      child: ghost == null
          ? content
          : Stack(
              clipBehavior: Clip.hardEdge,
              children: <Widget>[
                Positioned(
                  // 底边停在标题行内：再低就会压到 meta 那行小字上
                  top: -34,
                  right: -6,
                  child: ExcludeSemantics(
                    child: Text(
                      ghost!,
                      style: _ghostStyle.copyWith(foreground: _ghostStroke),
                    ),
                  ),
                ),
                content,
              ],
            ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: band,
    );
  }
}

/// 把 meta 里页面写死的纸面配色改写成色带配色。
///
/// 页面的 meta 是 `Text.rich`，底字用 [AppColors.textSecondary]、强调
/// 数字用 [AppColors.primary]——两者压在陶土上都读不清。这里只替换
/// 这两个已知色值，其余（字重、字号、字体）原样保留，页面继续按
/// 纸面语义写 meta 即可。
class _RecolorMeta extends StatelessWidget {
  const _RecolorMeta({required this.child});

  final Widget child;

  static TextStyle? _map(TextStyle? style) {
    if (style == null) return null;
    final Color? c = style.color;
    if (c == AppColors.primary || c == AppColors.primaryDark) {
      return style.copyWith(color: AppColors.accentOnPrimary);
    }
    if (c == AppColors.textSecondary ||
        c == AppColors.textPrimary ||
        c == AppColors.textHint) {
      return style.copyWith(color: AppColors.textOnPrimaryMuted);
    }
    return null;
  }

  static InlineSpan _span(InlineSpan span) {
    if (span is TextSpan) {
      return TextSpan(
        text: span.text,
        style: _map(span.style) ?? span.style,
        recognizer: span.recognizer,
        mouseCursor: span.mouseCursor,
        onEnter: span.onEnter,
        onExit: span.onExit,
        semanticsLabel: span.semanticsLabel,
        locale: span.locale,
        spellOut: span.spellOut,
        children: span.children?.map(_span).toList(),
      );
    }
    if (span is WidgetSpan) {
      return WidgetSpan(
        alignment: span.alignment,
        baseline: span.baseline,
        style: _map(span.style) ?? span.style,
        child: _RecolorMeta(child: span.child),
      );
    }
    return span;
  }

  @override
  Widget build(BuildContext context) {
    final Widget c = child;
    if (c is Text) {
      final InlineSpan? s = c.textSpan;
      if (s != null) {
        return Text.rich(
          _span(s),
          textAlign: c.textAlign ?? TextAlign.start,
          maxLines: c.maxLines,
          overflow: c.overflow ?? TextOverflow.clip,
        );
      }
      return Text(
        c.data ?? '',
        style: _map(c.style) ?? c.style,
        textAlign: c.textAlign,
        maxLines: c.maxLines,
      );
    }
    return c;
  }
}
