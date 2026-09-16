import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'glass_surface.dart';

/// 40×4 的拖拽把手。取代改造前 7 处手写的 Container 把手。
class GlassSheetHandle extends StatelessWidget {
  const GlassSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xxs),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.divider,
          borderRadius: BorderRadius.circular(AppRadius.xs / 2),
        ),
      ),
    );
  }
}

/// 玻璃底部弹窗。
///
/// 取代改造前 7 处 `showModalBottomSheet`——它们各自带着不同的顶角
/// （4 处 20、3 处 24）和不同的把手、有的还依赖默认背景色。
/// 统一为 [AppRadius.sheet]（28）与真模糊。
class GlassSheet extends StatelessWidget {
  const GlassSheet({
    super.key,
    required this.child,
    this.blurSigma = 24,
    this.useBlur = true,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.sheetPad,
      AppSpacing.xxs,
      AppSpacing.sheetPad,
      AppSpacing.sheetPad,
    ),
    this.showHandle = true,
  });

  final Widget child;
  final double blurSigma;
  final bool useBlur;
  final EdgeInsetsGeometry padding;
  final bool showHandle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 键盘弹起时把内容顶上去
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: GlassSurface(
        topRadius: AppRadius.sheet,
        tone: GlassTone.strong,
        edge: GlassEdge.top,
        blurSigma: useBlur ? blurSigma : null,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (showHandle) const GlassSheetHandle(),
              Flexible(
                child: SingleChildScrollView(
                  padding: padding,
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 打开玻璃底部弹窗。
///
/// 与原 `showModalBottomSheet` 的差异：背景交给 [GlassSheet] 自己画，
/// route 层保持透明，因此调用点不要再传 `backgroundColor` / `shape`。
Future<T?> showGlassSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  double blurSigma = 24,
  bool useBlur = true,
  bool showHandle = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.glassScrim,
    builder: (BuildContext ctx) => GlassSheet(
      blurSigma: blurSigma,
      useBlur: useBlur,
      showHandle: showHandle,
      child: builder(ctx),
    ),
  );
}