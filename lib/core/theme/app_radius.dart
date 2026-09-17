import 'package:flutter/painting.dart';

/// 圆角 token。
///
/// 收敛自原代码里散落的 153 处 `BorderRadius.circular(...)` 字面量。
///
/// ## 按控件角色分档（改圆角前先看这里）
///
/// | 角色 | 取值 | 用在哪 |
/// |---|---|---|
/// | 纯图标按钮 | 圆形 | 日期箭头、完成勾选、开始/停止 |
/// | 浮动主按钮 | [full] 胶囊 | 只有 FAB |
/// | 小控件 | [md] 12 | chip、分段控件、滑动指示块、日期胶囊、小标签 |
/// | 大块 | [lg] 16 | **所有内容卡**、输入框、主按钮 |
/// | 底部弹窗顶角 | [sheet] 28 | |
/// | 对话框 | [xl] 20 | 只剩这一处用途 |
///
/// 两条容易踩的规则：
/// - **页面内的卡片一律 [lg]**，不要用 [xl]。原先任务卡与统计概览卡用了
///   xl(20)，而同类的待办/规划卡是 lg(16)，是同一类东西两个圆角。
/// - **[xl] 不要用在页面里**，它现在的语义只剩「对话框」（`app_theme.dart`
///   的 `dialogTheme`）。[xl] 与 [lg] 的差别在卡片上完全看不出来，
///   只会制造不一致。
class AppRadius {
  AppRadius._();

  /// 进度条裁剪、把手细条
  static const double xs = 4;

  /// 标签、热力图格子、小徽标
  static const double sm = 8;

  /// chip、小按钮、日期胶囊
  static const double md = 12;

  /// 标准卡片、输入框
  static const double lg = 16;

  /// 对话框（`app_theme.dart` 的 `dialogTheme`）。
  /// **页面内的卡片不要用它**，用 [lg]。
  static const double xl = 20;

  /// 底部弹窗顶角。统一为 28，终结原先 20/24 并存的分裂
  static const double sheet = 28;

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
