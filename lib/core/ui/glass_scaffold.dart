import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'aurora_background.dart';
import 'glass_app_bar.dart';

/// 页面级玻璃容器。
///
/// ## 两种用法
///
/// - **MainScreen 里的 5 个 Tab 页**：`standalone` 保持 false。Scaffold
///   透明，让 `MainScreen` 那一层的极光透出来（全应用只有一份极光，
///   否则 5 个相位不同的控制器会让背景在切 Tab 时跳变）。
/// - **`Navigator.push` 推入的全屏页**（如新建任务）：`standalone: true`，
///   自己带一层极光，否则透明 Scaffold 背后没有任何东西可看。
class GlassScaffold extends StatelessWidget {
  const GlassScaffold({
    super.key,
    this.title,
    this.titleIcon,
    this.actions,
    required this.body,
    this.floatingActionButton,
    this.resizeToAvoidBottomInset = true,
    this.standalone = false,
    this.blurSigma = 16,
  });

  final String? title;
  final IconData? titleIcon;
  final List<Widget>? actions;
  final Widget body;
  final Widget? floatingActionButton;
  final bool resizeToAvoidBottomInset;

  /// 是否为独立路由（自带极光背景）
  final bool standalone;

  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          standalone ? AppColors.background : Colors.transparent,
      extendBody: standalone,
      appBar: GlassAppBar(
        title: title,
        titleIcon: titleIcon,
        actions: actions,
        blurSigma: blurSigma,
      ),
      body: standalone
          ? Stack(
              children: <Widget>[
                const Positioned.fill(child: AuroraBackground()),
                Positioned.fill(
                  child: RepaintBoundary(child: body),
                ),
              ],
            )
          : body,
      floatingActionButton: floatingActionButton,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
    );
  }
}