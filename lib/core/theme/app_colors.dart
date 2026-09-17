import 'package:flutter/material.dart';

/// 全局色板。
///
/// 用法约定（整个 v1.3.0 设计系统遵循这一套）：
/// - 颜色 → `AppColors.*`（const）
/// - 圆角 → [AppRadius]
/// - 间距 → [AppSpacing]
/// - 阴影 → [AppShadows]
/// - 文字 → [AppText]
///
/// `Theme.of(context)` 只用于框架内部会读的主题入口
/// （inputDecorationTheme / dialogTheme / snackBarTheme 等），
/// 页面不通过 context 取色——这样绝大多数样式能保持 `const`。
class AppColors {
  AppColors._();

  // ─ 主色调 ──────────────────────────────────────────────
  static const Color primary = Color(0xFF00BFA5);
  static const Color primaryDark = Color(0xFF00897B);
  static const Color primaryLight = Color(0xFFB2DFDB);
  static const Color primarySubtle = Color(0xFFE0F2F1);
  static const Color accent = Color(0xFF64FFDA);

  // ── 背景 / 表面 ─────────────────────────────────────────
  static const Color background = Color(0xFFF8FAFB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F5F9);

  // ── 文字 ────────────────────────────────────────────────
  //
  // 玻璃层对比度约定（重要，改 alpha 前必读）：
  // 卡片填充为 [glassFill]（78% 白）叠在 background + 极光光斑之上，
  // 合成底亮度约 0.96。在此底色上：
  //   textPrimary   ≈ 16.8:1  AAA
  //   textSecondary ≈  4.7:1  AA（余量很窄，不要再调低 glassFill 的 alpha）
  //   textHint      ≈  3.1:1  仅可用于 ≥18px 的文字或纯装饰性内容
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textHint = Color(0xFF94A3B8);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // ── 功能色 ──────────────────────────────────────────────
  static const Color divider = Color(0xFFE2E8F0);
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // ── 阴影基色（旧，Phase 4 起逐步由 AppShadows 取代）────────
  static const Color shadow = Color(0x08000000);
  static const Color shadowMedium = Color(0x12000000);

  // ══ v1.3.0 新增：极光层 ═══════════════════════════════════
  //
  // 三个缓慢漂移的光斑。注意 blob 的 alpha 上限为 0.45
  // （见 AuroraBackground）——超过后 textSecondary 会跌破 4.5:1。
  static const Color auroraBlobPrimary = Color(0xFF00BFA5); // 青绿
  static const Color auroraBlobMint = Color(0xFF7BE3C8); // 薄荷
  static const Color auroraBlobSky = Color(0xFF8FD8F0); // 极淡天青

  // ══ v1.3.0 新增：玻璃层 ══════════════════════════════════
  //
  // alpha 写成十六进制字节而非 withValues()，以保证这些是编译期常量。
  static const Color glassFill = Color(0xC7FFFFFF); // 78% 普通卡片
  static const Color glassFillStrong = Color(
    0xE8FFFFFF,
  ); // 91% 文字密集卡 / 对话框 / sheet
  static const Color glassFillWeak = Color(
    0x9EFFFFFF,
  ); // 62% 小表面 / chip / appbar / nav

  /// 1px 内高光描边的起点（左上，被照亮的一侧）
  static const Color glassEdgeTop = Color(0xF2FFFFFF);

  /// 1px 内高光描边的终点（右下），也用作 0.5px 发丝分割线
  static const Color glassEdgeBottom = Color(0x4DFFFFFF);

  static const Color glassTintPrimary = Color(0x2600BFA5); // primary @15%
  static const Color glassTintSuccess = Color(0x2E10B981); // success @18%
  static const Color glassTintError = Color(0x2EEF4444); // error   @18%

  /// 弹窗背后的遮罩（slate @36%）
  static const Color glassScrim = Color(0x5C0F172A);

  /// 静置卡片的阴影（slate @6%，用纯黑会在青绿背景上显脏）
  static const Color glassShadow = Color(0x0F0F172A);

  /// 浮起表面的阴影（slate @14%）
  static const Color glassShadowStrong = Color(0x240F172A);

  /// 热力图空格子的填充。
  /// 必须比 [glassFill] 深，否则空格子在玻璃卡上完全看不见。
  static const Color heatEmpty = Color(0xFFE9EFF2);

  // ── 图表配色 ────────────────────────────────────────────
  //
  // 色相分离优先，而不是同色系渐阶。原因：改造前那套 10 档青绿渐阶里
  // 最浅的几档（#B2DFDB、#A7FFEB）叠在 78% 白玻璃上几乎不可见，
  // 饼图切片彼此也分不开。当前这套每个颜色都与 glassFill 合成底保持
  // 至少 2.5:1 的对比。
  static const List<Color> chartColors = [
    Color(0xFF00897B), // teal 600
    Color(0xFF3B82F6), // blue 500
    Color(0xFF6366F1), // indigo 500
    Color(0xFF8B5CF6), // violet 500
    Color(0xFF10B981), // emerald 500
    Color(0xFFF59E0B), // amber 500
    Color(0xFFEF4444), // red 500
    Color(0xFF0EA5E9), // sky 500
  ];

  /// 热力图色阶，由浅到深 5 档。
  ///
  /// 与 [chartColors] 不同，这里**必须**是单调递减亮度的同一色相——
  /// 热力图靠深浅表达大小。无数据的格子用 [heatEmpty]，它比
  /// [glassFill] 深，否则空格子在玻璃卡上完全看不见。
  static const List<Color> heatMapColors = [
    Color(0xFFDFF2EE), // 1 档 最浅
    Color(0xFF9FD9CE), // 2
    Color(0xFF4FBFAE), // 3
    Color(0xFF1E9E8C), // 4
    Color(0xFF0B6B5E), // 5 档 最深
  ];
}
