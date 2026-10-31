import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 页面刊头：眉题（kicker）+ 衬线大标题 + 可选元信息行 + 底部铅线。
///
/// 编辑风里标题属于**内容**而不是 chrome，所以六个 Tab 页不用顶栏，
/// 正文从刊头开始读。眉题是页面的「栏目名」（DAILY LIST / WEEKLY
/// LEDGER…），与标题形成大小两极，这是排版层级的主要来源。
///
/// v1.6.0（编排精修）新增两件排版武器：
/// - [meta]：标题下的一行元信息（`第 44 周 · 10/19 – 10/25 · VOL.359`），
///   把原先散在各处的期号/日期/计数收拢成一行，用间隔号分节；
///   [meta] 用 RichText 时可以把关键数字标成朱砂。
/// - [ghost]：右上角的当周/当日巨号数字水印（描边空心，如 `44`），
///   给素纸面一个体量锚点。水印被铅线以下的内容区裁切——像印刷品
///   被裁切一样，是刻意的。
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

  /// 水印描边画笔。墨色 13% 的空心描边——足够存在又不抢正文
  static final Paint _ghostStroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2
    ..color = const Color(0x221D1A14);

  static const TextStyle _ghostStyle = TextStyle(
    fontFamily: 'Playfair',
    fontSize: 132,
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
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: AppText.masthead.copyWith(
                      color: AppColors.textPrimary,
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
                    color: AppColors.textSecondary,
                  ),
                  child: trailing!,
                ),
              ),
          ],
        ),
        if (meta != null)
          Padding(padding: const EdgeInsets.only(top: 8), child: meta!),
        const SizedBox(height: AppSpacing.sm),
        // 铅线：刊头下的重规线，报头的下边界
        Container(height: 1.5, color: AppColors.dividerStrong),
      ],
    );

    if (ghost == null) return content;

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: <Widget>[
        Positioned(
          top: -8,
          right: 2,
          child: ExcludeSemantics(
            child: Text(
              ghost!,
              style: _ghostStyle.copyWith(foreground: _ghostStroke),
            ),
          ),
        ),
        content,
      ],
    );
  }
}
