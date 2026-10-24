import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 36×4 的墨色拖拽把手
class PaperSheetHandle extends StatelessWidget {
  const PaperSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(
          top: AppSpacing.sm,
          bottom: AppSpacing.xxs,
        ),
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.inkSubtle,
          borderRadius: AppRadius.brXs,
        ),
      ),
    );
  }
}

/// 纸面底部弹窗。
///
/// 白底（真正浮起于纸面之上的表面）+ 16 顶圆角 + 墨色把手。
/// 键盘避让 / SafeArea / 滚动与玻璃版一致，由这里统一提供，
/// 调用点只写表单内容。
class PaperSheet extends StatelessWidget {
  const PaperSheet({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.sheetPad,
      AppSpacing.xxs,
      AppSpacing.sheetPad,
      AppSpacing.sheetPad,
    ),
    this.showHandle = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool showHandle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 键盘弹起时把内容顶上去
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.brSheetTop,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (showHandle) const PaperSheetHandle(),
              Flexible(
                child: SingleChildScrollView(padding: padding, child: child),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 打开纸面底部弹窗。
///
/// 遮罩是墨色半透明；route 层保持透明，底板由 [PaperSheet] 自己画。
Future<T?> showPaperSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool showHandle = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.scrim,
    builder: (BuildContext ctx) => PaperSheet(
      showHandle: showHandle,
      child: builder(ctx),
    ),
  );
}
