import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 页面刊头：眉题（kicker）+ 衬线大标题 + 底部铅线。
///
/// 编辑风里标题属于**内容**而不是 chrome，所以六个 Tab 页不用顶栏，
/// 正文从刊头开始读。眉题是页面的「栏目名」（DAILY LIST / WEEKLY
/// LEDGER…），与标题形成大小两极，这是排版层级的主要来源。
///
/// [trailing] 放右侧的期号/日期等元信息，与标题基线对齐。
class Masthead extends StatelessWidget {
  const Masthead({
    super.key,
    required this.kicker,
    required this.title,
    this.trailing,
  });

  final String kicker;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
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
        const SizedBox(height: AppSpacing.sm),
        // 铅线：刊头下的重规线，报头的下边界
        Container(height: 1.5, color: AppColors.dividerStrong),
      ],
    );
  }
}
