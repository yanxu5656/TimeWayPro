import 'package:flutter/painting.dart';

/// 圆角 token —— 静白志。
///
/// 编辑风的圆角整体收紧：层次靠细线，不靠大圆角。只有「浮起」的
/// 东西（弹窗、输入框、按钮）保有明显圆角，长在纸面上的内容
/// （账本行、分区）是直角的。
///
/// ## 按控件角色分档（改圆角前先看这里）
///
/// | 角色 | 取值 | 用在哪 |
/// |---|---|---|
/// | 纯图标按钮 | 圆形 | 日期箭头、完成勾选、开始/停止 |
/// | 浮动主按钮 | [full] 胶囊 | FAB、主按钮 |
/// | 小控件 | [md] 8 | chip、小标签、热力图格子 |
/// | 浮起块 | [lg] 12 | 输入框、白底浮起卡 |
/// | 对话框 | [xl] 14 | `app_theme.dart` 的 `dialogTheme` |
/// | 底部弹窗顶角 | [sheet] 16 | |
class AppRadius {
  AppRadius._();

  /// 进度条裁剪、把手细条
  static const double xs = 2;

  /// 标签、小徽标
  static const double sm = 4;

  /// chip、热力图格子
  static const double md = 8;

  /// 输入框、白底浮起卡
  static const double lg = 12;

  /// 对话框（`app_theme.dart` 的 `dialogTheme`）
  static const double xl = 14;

  /// 底部弹窗顶角
  static const double sheet = 16;

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
  static const BorderRadius brFull = BorderRadius.all(Radius.circular(full));

  /// 底部弹窗 / 底部导航的顶角
  static const BorderRadius brSheetTop = BorderRadius.vertical(
    top: Radius.circular(sheet),
  );
}
