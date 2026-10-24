import 'package:flutter/material.dart';

/// 文字样式 token —— 静白志。
///
/// 分三组：
/// - **M3 槽位组**（[display] ~ [labelSm]）：装配回 `ThemeData.textTheme`，
///   让未显式给 style 的 `Text`/`ListTile`/`AlertDialog` 拿到正确字号。
/// - **衬线组**（[masthead] ~ [serifNum]）：编辑风的灵魂。数字用 Playfair
///   （assets 里打包的拉丁衬线），中文标题与账本行用思源宋
///   （NotoSerifSC 子集）。衬线只承担「主角」——大数字、刊头、账本行；
///   按钮 / 输入框 / 导航等 UI 元件仍用无衬线，保证操作性。
/// - **补充组**（[taskTitle] ~ [navLabelActive]）：页面实际在用但
///   M3 槽位里没有对应档位的样式。
///
/// 字体文件由 `tool/subset_fonts.py` 生成（改字符集重跑脚本）。
class AppText {
  AppText._();

  // ═ M3 槽位组 ═════════════════════════════════════════════

  /// → displayLarge
  static const TextStyle display = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.2,
  );

  /// → displayMedium
  static const TextStyle displayMd = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.2,
  );

  /// → displaySmall
  static const TextStyle displaySm = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.3,
  );

  /// → headlineLarge。顶栏标题
  static const TextStyle h1 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.1,
    height: 1.3,
  );

  /// → headlineMedium。弹窗标题
  static const TextStyle h2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1.4,
  );

  /// → headlineSmall
  static const TextStyle h3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.4,
  );

  /// → titleLarge。卡片标题
  static const TextStyle title = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.15,
    height: 1.5,
  );

  /// → titleMedium
  static const TextStyle titleMd = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.15,
    height: 1.5,
  );

  /// → titleSmall
  static const TextStyle titleSm = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.5,
  );

  /// → bodyLarge
  static const TextStyle bodyLg = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.15,
    height: 1.6,
  );

  /// → bodyMedium。正文
  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.15,
    height: 1.6,
  );

  /// → bodySmall
  static const TextStyle bodySm = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.15,
    height: 1.6,
  );

  /// → labelLarge
  static const TextStyle labelLg = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    height: 1.4,
  );

  /// → labelMedium
  static const TextStyle label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    height: 1.4,
  );

  /// → labelSmall
  static const TextStyle labelSm = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    height: 1.4,
  );

  // ══ 衬线组（编辑风的主角）════════════════════════════════

  /// 刊头大标题（思源宋 SemiBold）。每页顶部的主标题
  static const TextStyle masthead = TextStyle(
    fontFamily: 'NotoSerifSC',
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.02,
    height: 1.3,
  );

  /// 衬线区块标题（思源宋 SemiBold）。弹窗标题、账本分组标题
  static const TextStyle titleSerif = TextStyle(
    fontFamily: 'NotoSerifSC',
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.02,
    height: 1.4,
  );

  /// 账本行正文（思源宋 Regular）。待办 / 每周目标的条目文字
  static const TextStyle bodySerif = TextStyle(
    fontFamily: 'NotoSerifSC',
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.02,
    height: 1.5,
  );

  /// 衬线数字基座（Playfair Medium）。页面按需 copyWith(fontSize)
  /// 拼分数、时长等；只含拉丁与数字字形，混排中文会回退无衬线
  static const TextStyle serifNum = TextStyle(
    fontFamily: 'Playfair',
    fontWeight: FontWeight.w500,
    letterSpacing: 0.01,
    height: 1.1,
  );

  /// 刊头上方的英文小标（DAILY / WEEKLY / STATISTICS…）。
  /// 字距放到 0.3em，这是编辑风的「眉题」
  static const TextStyle kicker = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 3,
    height: 1.4,
  );

  // ══ 补充组（页面实际在用，M3 槽位无对应）════════════════════

  /// 任务 / 待办标题（w600，比 titleMd 轻）
  static const TextStyle taskTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.5,
  );

  /// 13px 描述文字
  static const TextStyle caption = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.6,
  );

  /// 统计页大数字（衬线。数字是这个设计的主角）
  static const TextStyle numXl = TextStyle(
    fontFamily: 'Playfair',
    fontSize: 26,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.01,
  );

  /// 任务页统计卡数字（衬线）
  static const TextStyle numLg = TextStyle(
    fontFamily: 'Playfair',
    fontSize: 22,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.01,
  );

  /// 计时显示（等宽，避免数字跳动）
  static const TextStyle mono = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    fontFamily: 'monospace',
    letterSpacing: 1,
  );

  /// 底部导航 label — 未选中
  static const TextStyle navLabel = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
  );

  /// 底部导航 label — 选中
  static const TextStyle navLabelActive = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );

  /// 装配回 `ThemeData.textTheme`。
  static TextTheme asTextTheme() => const TextTheme(
    displayLarge: display,
    displayMedium: displayMd,
    displaySmall: displaySm,
    headlineLarge: h1,
    headlineMedium: h2,
    headlineSmall: h3,
    titleLarge: title,
    titleMedium: titleMd,
    titleSmall: titleSm,
    bodyLarge: bodyLg,
    bodyMedium: body,
    bodySmall: bodySm,
    labelLarge: labelLg,
    labelMedium: label,
    labelSmall: labelSm,
  );
}
