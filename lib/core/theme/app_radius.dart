import 'package:flutter/painting.dart';

/// 圆角 token —— 陶土暖笺。
///
/// 卡片回到主表面之后，圆角整体放宽：暖白卡用 [card] 16，控件跟着
/// 松一档。编辑风的直角只在卡内发丝线上保留。
///
/// ## 按控件角色分档（改圆角前先看这里）
///
/// | 角色 | 取值 | 用在哪 |
/// |---|---|---|
/// | 纯图标按钮 | 圆形 | 日期箭头、完成勾选、开始/停止 |
/// | 浮动主按钮 | [full] 胶囊 | FAB、主按钮 |
/// | 小控件 | [md] 10 | chip、小标签、热力图格子 |
/// | 浮起块 | [lg] 12 | 输入框、卡内嵌套块 |
/// | 对话框 | [xl] 14 | `app_theme.dart` 的 `dialogTheme` |
/// | 内容卡片 | [card] 16 | 账本行卡、分区卡、刊头色带 |
/// | 底部弹窗顶角 | [sheet] 16 | |
class AppRadius {
  AppRadius._();

  /// 进度条裁剪、把手细条
  static const double xs = 3;

  /// 标签、小徽标
  static const double sm = 6;

  /// chip、热力图格子
  static const double md = 10;

  /// 输入框、卡内嵌套块
  static const double lg = 12;

  /// 对话框（`app_theme.dart` 的 `dialogTheme`）
  static const double xl = 14;

  /// 底部弹窗顶角
  static const double sheet = 16;

  /// 内容卡片。与 [sheet] 同值但语义不同：一个是页面上的卡，
  /// 一个是弹层顶角，各自演进时不会互相牵动
  static const double card = 16;

  /// 胶囊 / 圆形
  static const double full = 999;

  // ── const BorderRadius 快捷方式 ──────────────────────────
  //
  // `BorderRadius.circular()` 不是 const 构造（见 Flutter
  // painting/border_radius.dart，官方注释建议改用 `BorderRadius.all`）。
  // 用下面这些能让整个 `const BoxDecoration` 保持编译期常量。

  static const BorderRadius brXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius brSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius brMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius brLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius brXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius brCard = BorderRadius.all(Radius.circular(card));
  static const BorderRadius brFull = BorderRadius.all(Radius.circular(full));

  /// 底部弹窗 / 底部导航的顶角
  static const BorderRadius brSheetTop = BorderRadius.vertical(
    top: Radius.circular(sheet),
  );
}
