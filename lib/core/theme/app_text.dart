import 'package:flutter/material.dart';

/// 文字样式 token。
///
/// 收敛自原代码里 93 处硬写的 `TextStyle`（页面侧 `Theme.of(context).textTheme`
/// 引用次数为 0）。
///
/// 分两组：
/// - **M3 槽位组**（[display] ~ [labelSm]）：与 `app_theme.dart` 里原有的
///   15 档 `TextTheme` 逐字一致，由 [asTextTheme] 装配回 `ThemeData`，
///   让未显式给 style 的 `Text`/`ListTile`/`SnackBar`/`AlertDialog` 拿到
///   正确字号——`textTheme` 从"零消费"变成隐式全覆盖，且**渲染结果不变**。
/// - **补充组**（[taskTitle] ~ [navLabelActive]）：页面实际在用但 M3 槽位
///   里没有对应档位的样式。
class AppText {
  AppText._();

  // ═ M3 槽位组（与原有 textTheme 逐字一致）══════════════════

  /// → displayLarge
  static const TextStyle display = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    height: 1.2,
  );

  /// → displayMedium
  static const TextStyle displayMd = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
    height: 1.2,
  );

  /// → displaySmall
  static const TextStyle displaySm = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
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
    fontWeight: FontWeight.w700,
    letterSpacing: 0.1,
    height: 1.4,
  );

  /// → titleLarge。卡片标题
  static const TextStyle title = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.15,
    height: 1.5,
  );

  /// → titleMedium
  static const TextStyle titleMd = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.15,
    height: 1.5,
  );

  /// → titleSmall
  static const TextStyle titleSm = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
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
    fontWeight: FontWeight.w700,
    letterSpacing: 0.3,
    height: 1.4,
  );

  /// → labelMedium
  static const TextStyle label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.3,
    height: 1.4,
  );

  /// → labelSmall
  static const TextStyle labelSm = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.3,
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

  /// 统计页大数字
  static const TextStyle numXl = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
  );

  /// 任务页统计卡数字
  static const TextStyle numLg = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
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
  ///
  /// 输出与改造前 `app_theme.dart` 里的 15 档定义**逐字一致**——
  /// Phase 1 不改变任何文字的渲染结果。
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