import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'app_text.dart';

// 令牌层统一从这里再导出，页面只需 import 本文件即可拿到
// AppColors / AppRadius / AppSpacing / AppShadows / AppText。
//
// Dart 的 export 是传递性的，因此改造前就存在的 10 处
// `import '.../core/theme/app_theme.dart'` 一行都不用改。
export 'app_colors.dart';
export 'app_radius.dart';
export 'app_shadows.dart';
export 'app_spacing.dart';
export 'app_text.dart';

/// 主题装配层。
///
/// 这里只做两件事：把令牌层组装成 `ThemeData`，以及配置那些
/// 「框架组件会自己去读」的主题入口（输入框、对话框、SnackBar 等）。
/// 页面不通过 `Theme.of(context)` 取样式——绝大多数样式走
/// 编译期常量，以保持 `const` 与低分配开销。
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.surface,
        error: AppColors.error,
        // 补齐下面几项：只覆盖 4 个字段时，Switch / datePicker /
        // 未显式着色的框架组件会取到 seed 派生色，与设计系统不一致。
        onSurface: AppColors.textPrimary,
        onSurfaceVariant: AppColors.textSecondary,
        surfaceContainerHighest: AppColors.surfaceVariant,
        outlineVariant: AppColors.divider,
      ),
      scaffoldBackgroundColor: AppColors.background,

      // 现已删除 appBarTheme 与 floatingActionButtonTheme：
      // Phase 4 迁移到 GlassAppBar / GlassFab 后，全仓使用
      // AppBar / FloatingActionButton 的地方已归零。

      // 圆角数值与改造前一致（16/12/16），本阶段无视觉变化
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariant,
        hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
        border: const OutlineInputBorder(
          borderRadius: AppRadius.brLg,
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadius.brLg,
          borderSide: BorderSide.none,
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppRadius.brLg,
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: AppRadius.brLg,
          borderSide: BorderSide(color: AppColors.error, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: 28,
            vertical: AppSpacing.md,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.brLg),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.brMd),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(
            horizontal: 28,
            vertical: AppSpacing.md,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.brLg),
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 0.5,
        space: 0,
      ),

      // ═ 新增：一次性消掉大量重复的内联样式 ═════════════════
      //
      // 这些主题项让 Phase 4 可以直接删掉调用点上重复的
      // `shape:` / `behavior:` / `margin:` 参数。
      // 调用点仍传内联值时以内联为准，因此本阶段不产生回归。
      dialogTheme: DialogThemeData(
        // 对话框是文字最密的表面，走 91% 白强填充而非真模糊：
        // AlertDialog 不是可替换 builder 的容器，注入 BackdropFilter
        // 需自写 dialog 路由，而背后模糊对可读性零贡献、还多一次 saveLayer。
        backgroundColor: AppColors.glassFillStrong,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brXl),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brMd),
        insetPadding: const EdgeInsets.all(AppSpacing.md),
        elevation: 0,
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        linearTrackColor: AppColors.surfaceVariant,
        linearMinHeight: 6,
      ),

      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textSecondary,
      ),

      // 与 planning_screen 里原有的内联 SliderTheme 逐值一致
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: AppColors.background,
        thumbColor: AppColors.primary,
        overlayColor: AppColors.primary.withValues(alpha: 0.2),
        trackHeight: 6,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.textPrimary.withValues(alpha: 0.92),
          borderRadius: AppRadius.brSm,
        ),
        textStyle: const TextStyle(
          color: AppColors.textOnPrimary,
          fontSize: 12,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
      ),

      // ══ 文字 ══════════════════════════════════════════════
      //
      // 由 AppText.asTextTheme() 生成，输出与改造前逐字一致。
      // 意义在于：所有未显式给 style 的 Text / ListTile / SnackBar /
      // AlertDialog / Tooltip 都能拿到正确字号，textTheme 从
      // 「零消费」变成隐式全覆盖。
      textTheme: AppText.asTextTheme(),

      // ══ 已删除（核实过零使用）═══════════════════════════════
      //
      // cardTheme                  → 真 `Card(` 0 处，改由 GlassCard 承担
      // chipTheme                  → 真 `Chip(` 家族 0 处，改由 GlassChip 承担
      // bottomNavigationBarTheme   → 真 `BottomNavigationBar(` 0 处，
      //                              底部导航是自绘 Container+Row，
      //                              改由 GlassNavBar 承担
      //
      // 7 处底部弹窗现已全部走 showGlassSheet（自带玻璃底板 + 顶角 28），
      // 不再有任何一处依赖 route 的默认背景色，因此这里可以安全地设成透明。
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.brSheetTop),
      ),
    );
  }
}
