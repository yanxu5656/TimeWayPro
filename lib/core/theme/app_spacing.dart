/// 间距 token（4pt 网格）。
///
/// 收敛自原代码里约 90 处 `EdgeInsets` 字面量。原有的 12 种
/// `symmetric(horizontal:, vertical:)` 组合一律拆成两轴 token 组装，
/// 不再新增组合常量。
///
/// 注意：原代码中 `all(6)` / `all(10)` / `all(14)` 等奇数位会被归一到
/// [xs] / [sm] / [md]，在 `Row` 里可能轻微撑宽固定尺寸子项——迁移时
/// 需要按 Phase 5 的清单在 320dp 屏宽下逐页验证。
class AppSpacing {
  AppSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double huge = 40;

  // ── 语义常量（避免在页面里写魔法数）─────────────────────

  /// 列表页水平内边距
  static const double screenH = 20;

  /// 卡片内边距
  static const double cardPad = 16;

  /// 卡片之间的间距
  static const double cardGap = 12;

  /// 底部弹窗内边距
  static const double sheetPad = 24;

  /// 滚动内容的底部避让高度。
  ///
  /// `MainScreen` 使用 `extendBody: true` 后，玻璃底部导航会浮在内容
  /// 之上，列表必须留出这段空间，否则最后一项会被遮住。
  static const double navInset = 120;
}
