import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 编号区块标题：`01 · 本周记事 ····· 3 条`。
///
/// 编排精修（v1.6.0）的核心组件——给每个内容区块一个衬线序号
/// （朱砂）、一个拉开字距的小标、一个右对齐的计数，以及可选的
/// 下方重规线（账本区的「起笔线」，与发丝行线形成粗细节奏）。
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.index,
    required this.title,
    this.trailing,
    this.rule = true,
    this.topGap = true,
  });

  final int index;

  final String title;

  /// 右对齐的计数或补充说明（`3 条` / `10/24`）
  final String? trailing;

  /// 是否在标题下方画重规线。列表/账本区传 true；
  /// 已有边框的容器内（设置页分组卡）或非列表区传 false
  final bool rule;

  /// 是否自带顶部留白。同一列里连续区块由外层控制间距时传 false
  final bool topGap;

  String get _no => index.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.only(
            top: topGap ? AppSpacing.lg : 0,
            bottom: 6,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                _no,
                style: AppText.serifNum.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: AppText.label.copyWith(
                  fontSize: 13,
                  letterSpacing: 2.4,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              if (trailing != null)
                Text(
                  trailing!,
                  style: AppText.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
        if (rule) Container(height: 1.2, color: AppColors.dividerStrong),
      ],
    );
  }
}
