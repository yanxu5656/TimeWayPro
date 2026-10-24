import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

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
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.divider),
          ),
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
                      style: AppText.titleSerif.copyWith(
                        color: AppColors.textPrimary,
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
      child: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        color: AppColors.textPrimary,
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    );
  }
}
