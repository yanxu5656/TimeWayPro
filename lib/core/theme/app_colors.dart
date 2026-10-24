import 'package:flutter/material.dart';

/// 全局色板 —— 静白志（纸白 · 墨 · 朱砂）。
///
/// 用法约定（整个设计系统遵循这一套）：
/// - 颜色 → `AppColors.*`（const）
/// - 圆角 → [AppRadius]
/// - 间距 → [AppSpacing]
/// - 阴影 → [AppShadows]
/// - 文字 → [AppText]
///
/// `Theme.of(context)` 只用于框架内部会读的主题入口
/// （inputDecorationTheme / dialogTheme / snackBarTheme 等），
/// 页面不通过 context 取色——这样绝大多数样式能保持 `const`。
///
/// 体系只有三种「材料」：**纸**（[background]）、**墨**（[textPrimary]、
/// [ink] 系填充）、**朱砂**（[primary]，全应用唯一的强调色）。
/// 其余颜色都是这三种材料的衍生。不用模糊、不用渐变——层次靠
/// 发丝线（[divider] / [dividerStrong]）与字重字号表达。
class AppColors {
  AppColors._();

  // ─ 主色：朱砂 ──────────────────────────────────────────
  static const Color primary = Color(0xFFC5402C);
  static const Color primaryDark = Color(0xFF9E3423);
  static const Color primaryLight = Color(0xFFE5BFB7);
  static const Color primarySubtle = Color(0xFFF7E9E5);

  /// 第二强调色就是墨本身——编辑风的层级靠字重，不靠第二彩色
  static const Color accent = Color(0xFF1D1A14);

  // ── 背景 / 表面 ─────────────────────────────────────────
  /// 纸白：全局唯一的底色
  static const Color background = Color(0xFFFAF7F1);

  /// 纯白：浮起表面（弹窗、同步状态卡）专用，页面内容直接长在纸上
  static const Color surface = Color(0xFFFFFFFF);

  /// 暖灰填充：输入框底、按压态、次级块
  static const Color surfaceVariant = Color(0xFFF1EDE3);

  // ── 文字 ────────────────────────────────────────────────
  //
  // 纸面对比度约定（重要，改色值前必读）：
  // 底色为 [background]（纸白，亮度约 0.94）。在纸面上：
  //   textPrimary   ≈ 16.1:1  AAA
  //   textSecondary ≈  5.3:1  AA
  //   textHint      ≈  2.7:1  仅可用于 ≥18px 的文字或纯装饰性内容
  //   primary(朱砂) ≈  4.8:1  AA，可作文字色；[textOnPrimary] 压在其上
  static const Color textPrimary = Color(0xFF1D1A14);
  static const Color textSecondary = Color(0xFF6B655A);
  static const Color textHint = Color(0xFFA49B8B);

  /// 朱砂底上的文字用纸色（4.8:1），不用纯白——和纸面体系一致
  static const Color textOnPrimary = Color(0xFFFAF7F1);

  /// 墨底（FAB、选中 chip）上的文字同样用纸色
  static const Color textOnInk = Color(0xFFFAF7F1);

  // ── 线条：层次的第一工具 ────────────────────────────────
  /// 发丝线：列表分隔、分组边界（1px）
  static const Color divider = Color(0xFFE3DDD0);

  /// 重线：刊头下的粗规线、表格上下边（1.5~2px，编辑风的「铅线」）
  static const Color dividerStrong = Color(0xFF1D1A14);

  /// 弹窗遮罩：墨 @32%
  static const Color scrim = Color(0x521D1A14);

  // ── 墨系填充 ────────────────────────────────────────────
  /// 墨 @8%：按压态、选中行的底色
  static const Color inkSubtle = Color(0x141D1A14);

  /// 墨 @4%：更轻的悬停/静止底色
  static const Color inkFaint = Color(0x0A1D1A14);

  // ── 功能色 ──────────────────────────────────────────────
  static const Color error = Color(0xFFB3261E);
  static const Color success = Color(0xFF47603F);
  static const Color warning = Color(0xFFB07C2E);
  static const Color info = Color(0xFF3D5A80);

  // ── 阴影基色（暖墨，纸面上用纯黑会显脏）────────────────
  static const Color shadow = Color(0x0A241F14);
  static const Color shadowMedium = Color(0x14241F14);

  /// 热力图空格子的填充。必须比纸面深一档，否则空格子看不见
  static const Color heatEmpty = Color(0xFFF0EBE0);

  // ── 图表配色：墨色系编辑色板 ────────────────────────────
  //
  // 墨与朱砂领衔，其余为低饱和的「矿物色」（灰绿/赭/石蓝/栗/灰紫）。
  // 前两席给最重要的系列；每个颜色与纸面保持 ≥2.5:1 对比。
  static const List<Color> chartColors = [
    Color(0xFF1D1A14), // 墨
    Color(0xFFC5402C), // 朱砂
    Color(0xFF8A8375), // 暖灰
    Color(0xFF47603F), // 墨绿
    Color(0xFFB07C2E), // 赭石
    Color(0xFF3D5A80), // 石蓝
    Color(0xFF6E4A2E), // 栗棕
    Color(0xFF9C8AA5), // 灰紫
  ];

  /// 热力图色阶，由浅到深 5 档。
  ///
  /// 单调递减亮度的**墨阶**——热力图靠深浅表达大小，混入色相会读成
  /// 分类。无数据的格子用 [heatEmpty]。
  static const List<Color> heatMapColors = [
    Color(0xFFEFE9DC), // 1 档 最浅
    Color(0xFFD8D0BE), // 2
    Color(0xFFB0A68D), // 3
    Color(0xFF776D57), // 4
    Color(0xFF1D1A14), // 5 档 最深（满墨）
  ];
}
