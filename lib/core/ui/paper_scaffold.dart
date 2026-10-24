import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'paper_app_bar.dart';
import 'paper_nav_bar.dart';

/// 页面级纸面容器。
///
/// 两种形态：
/// - **传 [title]**：顶部一条平顶栏（衬线标题），用于 `Navigator.push`
///   推入的二级页（如新建任务）。
/// - **不传 [title]**：无顶栏，页面正文自己排刊头（kicker + 衬线大标题）。
///   这是六个 Tab 页的形态——编辑风的标题属于内容，不是 chrome。
///   此时正文会被包上顶部 SafeArea。
///
/// 底部导航的 FAB 避让逻辑（[NavBarInset]）与玻璃版一致。
class PaperScaffold extends StatelessWidget {
  const PaperScaffold({
    super.key,
    this.title,
    this.actions,
    required this.body,
    this.floatingActionButton,
    this.resizeToAvoidBottomInset = true,
  });

  final String? title;
  final List<Widget>? actions;
  final Widget body;
  final Widget? floatingActionButton;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    final Widget content = title == null
        ? SafeArea(top: true, bottom: false, child: body)
        : body;

    return Scaffold(
      // 自己铺纸底：二级页（push 路由）没有 MainScreen 的底可透；
      // Tab 页之下叠一层同色纸也无任何视觉差
      backgroundColor: AppColors.background,
      extendBody: title == null,
      appBar: title == null
          ? null
          : PaperAppBar(title: title, actions: actions),
      body: content,
      // 包一层底 padding 把 FAB 抬到纸面导航栏之上（原理见 NavBarInset）
      floatingActionButton: floatingActionButton == null
          ? null
          : _withNavBarInset(context, floatingActionButton!),
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
    );
  }

  Widget _withNavBarInset(BuildContext context, Widget fab) {
    final double inset = NavBarInset.of(context);
    if (inset <= 0) return fab;
    return Padding(padding: EdgeInsets.only(bottom: inset), child: fab);
  }
}
