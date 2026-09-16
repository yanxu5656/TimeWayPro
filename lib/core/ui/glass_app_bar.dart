import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// 玻璃顶栏。
///
/// 取代改造前 6 个页面各自手写的 `AppBar(title: Row(图标徽标 + 文字))`。
///
/// ## 为什么用真 `BackdropFilter`
///
/// 顶栏是固定表面（不在滚动流里），而且只会滚动内容从它下面经过——
/// 这种"内容从玻璃下滑过"的效果正是模糊最有价值的场景。
///
/// `IndexedStack` 只 paint 选中的那一页，所以同时最多只有 1 个实例在
/// 栅格化。sigma 取 16（上限 24）。
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GlassAppBar({
    super.key,
    this.title,
    this.titleIcon,
    this.actions,
    this.blurSigma = 16,
    this.automaticallyImplyLeading = true,
  });

  final String? title;

  /// 标题左侧的图标徽标。为 null 时只显示文字。
  final IconData? titleIcon;

  final List<Widget>? actions;
  final double blurSigma;
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
      child: RepaintBoundary(
        child: ClipRect(
          // ClipRect 比 ClipRRect 便宜，顶栏是直角
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.glassFillWeak,
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.glassEdgeBottom,
                    width: 0.5,
                  ),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: SizedBox(
                  height: kToolbarHeight,
                  child: Row(
                    children: <Widget>[
                      if (automaticallyImplyLeading) _buildLeading(context),
                      if (titleIcon != null) ...<Widget>[
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.glassTintPrimary,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Icon(
                            titleIcon,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      if (title != null)
                        Flexible(
                          child: Text(
                            title!,
                            style: AppText.h1.copyWith(
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      const Spacer(),
                      ...?actions,
                      const SizedBox(width: AppSpacing.xs),
                    ],
                  ),
                ),
              ),
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
