import 'package:flutter/painting.dart';

/// 圆角 token。
///
/// 收敛自原代码里散落的 153 处 `BorderRadius.circular(...)` 字面量，
/// 原取值集合为 {2,4,6,8,10,12,14,16,20,24}，其中同一角色用值不一致
/// （卡片圆角在 14/16/20 间摇摆）。映射关系：
///
/// | 原值 | 场景 | → token |
/// |---|---|---|
/// | 2, 4 | 拖拽把手条、进度条裁剪 | [xs] |
/// | 6, 8 | 标签、热力图格子、徽标 | [sm] |
/// | 10, 12 | chip、小按钮、日期胶囊 | [md] |
/// | 14, 16 | 标准卡片、输入框 | [lg] |
/// | 20 | 主视觉卡片、FAB | [xl] |
/// | 20, 24 | 底部弹窗顶角（原为 20/24 两种） | [sheet] |
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

  /// 主视觉卡片（概览 / 饼图 / 热力图）
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
  static const BorderRadius brSheetTop =
      BorderRadius.vertical(top: Radius.circular(sheet));
}