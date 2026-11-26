import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'paper_icon_button.dart';

/// 平顶栏（二级页用）。
///
/// 纸面体系里顶栏是「纸的一部分」：无底色、无模糊，只有一条下缘
/// 发丝线与衬线标题。六个 Tab 页不用顶栏（刊头在正文里，见
/// [PaperScaffold] 的文档），这里只服务 push 出来的二级页。
class PaperAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PaperAppBar({
    super.key,
    this.title,
    this.actions,
    this.automaticallyImplyLeading = true,
  });

  final String? title;
  final List<Widget>? actions;
  final bool automaticallyImplyLeading;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    // route 切换时 DatePickerDialog 等会改写状态栏样式，
    // 这里每个顶栏都重申一遍，保证深色图标不被覆盖掉。
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: context.colors.isDark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.colors.divider)),
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: kToolbarHeight,
            child: Row(
              children: <Widget>[
                if (automaticallyImplyLeading) _buildLeading(context),
                if (title != null) ...<Widget>[
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      title!,
                      style: context.text.titleSerif.copyWith(
                        color: context.colors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const Spacer(),
                ...?actions,
                const SizedBox(width: AppSpacing.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeading(BuildContext context) {
    final bool canPop = Navigator.maybeOf(context)?.canPop() ?? false;
    if (!canPop) return const SizedBox(width: AppSpacing.xs);
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xxs),
      child: PaperIconButton(
        icon: Icons.arrow_back_ios_new_rounded,
        iconSize: 20,
        size: PaperIconButton.sizeChrome,
        onTap: () => Navigator.of(context).maybePop(),
        tooltip: '返回',
      ),
    );
  }
}
