import 'package:flutter/material.dart';

/// 全局色板 —— 陶土暖笺（暖纸 · 陶土 · 橄榄）。
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
/// 体系只有三种「材料」：**暖纸**（[background]）、**暖白卡**
/// （[surface]）、**陶土**（[primary]，操作与强调色）。橄榄 [accent]
/// 只出现在图表与次级标记上，不参与操作底色。
///
/// 排版骨架沿用「静白志」：刊头 + 眉题 + 编号分区 + 衬线大数字。
/// 变的是材料——纸白换成带红调的暖纸，朱砂换成陶土，分层工具从
/// 「发丝线」换回「暖白卡 + 两层暖阴影」。这是一次明确的审美转向：
/// v1.5.0 让卡片退位，这一版让卡片回来承担体量。
///
/// 不用模糊、不用渐变——厚度靠实心色块与阴影表达。
class AppColors {
  AppColors._();

  // ─ 主色：陶土 ──────────────────────────────────────────
  static const Color primary = Color(0xFFA84E2B);
  static const Color primaryDark = Color(0xFF8A3F22);
  static const Color primaryLight = Color(0xFFE8B79E);
  static const Color primarySubtle = Color(0xFFF7E5DA);

  /// 第二强调色：橄榄。只用在图表与次级标记，不做操作底色
  static const Color accent = Color(0xFF6E7F45);

  // ── 背景 / 表面 ─────────────────────────────────────────
  /// 暖纸：全局唯一的底色
  static const Color background = Color(0xFFF6EDE3);

  /// 暖白：卡片表面。比底色亮一档，由阴影把它托起来
  static const Color surface = Color(0xFFFFFCF8);

  /// 暖沙填充：输入框底、按压态、次级块
  static const Color surfaceVariant = Color(0xFFEFE2D4);

  // ── 文字 ────────────────────────────────────────────────
  //
  // 暖纸对比度约定（重要，改色值前必读）：
  // 底色为 [background]（暖纸，亮度约 0.857）。在纸面上：
  //   textPrimary   ≈ 13.5:1  AAA
  //   textSecondary ≈  5.5:1  AA
  //   textHint      ≈  2.8:1  仅可用于 ≥18px 的文字或纯装饰性内容
  //   primary(陶土) ≈  4.8:1  AA，可作文字色；[textOnPrimary] 压在其上
  //
  // 卡片表面 [surface] 比底色更亮，同一组文字在卡面上对比只会更高，
  // 所以按底色校验通过即全局通过。
  static const Color textPrimary = Color(0xFF2E2119);
  static const Color textSecondary = Color(0xFF715B4C);
  static const Color textHint = Color(0xFFA08D7C);

  /// 陶土底上的文字用暖白（5.3:1），不用纯白——和暖纸体系一致
  static const Color textOnPrimary = Color(0xFFFFF8F1);

  /// 深底（选中 chip）上的文字同样用暖白
  static const Color textOnInk = Color(0xFFFFF8F1);

  // ── 刊头色带上的文字 ────────────────────────────────────
  //
  // 刊头是一整块实心陶土。上面的层级靠字号与字距拉开，不靠降透明度：
  // 奶油色一降到 80% 就跌破 4.5:1，眉题会读不清。下面两档都实测过
  // 压在 [primary] 上的对比度。
  /// 眉题 / 元信息：暖白 @92%（≈4.7:1）
  static const Color textOnPrimaryMuted = Color(0xEBFFF8F1);

  /// 元信息里被强调的数字：奶油（≈4.7:1），靠色相而非亮度跳出
  static const Color accentOnPrimary = Color(0xFFFFE8D2);

  /// 刊头水印描边：暖白 @26%。纯装饰，不参与可读性预算
  static const Color ghostOnPrimary = Color(0x42FFF8F1);

  // ── 线条 ────────────────────────────────────────────────
  /// 发丝线：卡内分隔、分组边界（1px）
  static const Color divider = Color(0xFFE6D8C8);

  /// 重线：编号分区下的规线。用暖褐而不是近黑——卡片体系里
  /// 一条黑线会把暖纸面切得太硬
  static const Color dividerStrong = Color(0xFFC9B29B);

  /// 弹窗遮罩：暖褐 @32%
  static const Color scrim = Color(0x522E2119);

  // ── 暖褐系填充 ──────────────────────────────────────────
  /// 暖褐 @8%：按压态、选中行的底色
  static const Color inkSubtle = Color(0x142E2119);

  /// 暖褐 @4%：更轻的悬停/静止底色
  static const Color inkFaint = Color(0x0A2E2119);

  // ── 功能色 ──────────────────────────────────────────────
  //
  // success 会被当小字号文字用（「已完成」标签、计时读数），所以它
  // 必须自己过 AA，不能直接复用装饰用的 [accent] 橄榄（3.8:1）。
  static const Color error = Color(0xFFB33A2B);
  static const Color success = Color(0xFF5C6B39);

  /// 进度条中段色。只作图形填充（≥3:1），不作文字色
  static const Color warning = Color(0xFFA8752A);
  static const Color info = Color(0xFF3E6E8E);

  // ── 阴影基色（暖陶棕，暖纸上用纯黑会显脏）──────────────
  static const Color shadow = Color(0x1A4A3424);
  static const Color shadowMedium = Color(0x2E4A3424);

  /// 热力图空格子的填充。必须比纸面深一档，否则空格子看不见
  static const Color heatEmpty = Color(0xFFEDE0D0);

  // ── 图表配色：陶土系矿物色板 ────────────────────────────
  //
  // 陶土领衔，其余为暖调矿物色（橄榄/铜金/石青/砖红/灰紫/陶棕/麻褐）。
  // 前两席给最重要的系列；每个颜色与纸面保持 ≥2.5:1 对比。
  static const List<Color> chartColors = [
    Color(0xFFA84E2B), // 陶土
    Color(0xFF6E7F45), // 橄榄
    Color(0xFFC08A3E), // 铜金
    Color(0xFF3E6E8E), // 石青
    Color(0xFFA8503F), // 砖红
    Color(0xFF8C6E9E), // 灰紫
    Color(0xFF715B4C), // 陶棕
    Color(0xFF9C8459), // 麻褐
  ];

  /// 热力图色阶，由浅到深 5 档。
  ///
  /// 单调递减亮度的**陶土阶**——热力图靠深浅表达大小，色相全程锁在
  /// 同一族，混入别的色相会读成分类。无数据的格子用 [heatEmpty]。
  static const List<Color> heatMapColors = [
    Color(0xFFF0E2D2), // 1 档 最浅
    Color(0xFFDFC3A6), // 2
    Color(0xFFCE9A72), // 3
    Color(0xFFBC7048), // 4
    Color(0xFF8E4526), // 5 档 最深
  ];
}
