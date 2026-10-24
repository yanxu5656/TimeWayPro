import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'app_text.dart';

// 令牌层统一从这里再导出，页面只需 import 本文件即可拿到
// AppColors / AppRadius / AppSpacing / AppShadows / AppText。
export 'app_colors.dart';
export 'app_radius.dart';
export 'app_shadows.dart';
export 'app_spacing.dart';
export 'app_text.dart';

/// 主题装配层 —— 静白志。
///
/// 这里只做两件事：把令牌层组装成 `ThemeData`，以及配置那些
/// 「框架组件会自己去读」的主题入口（输入框、对话框、SnackBar 等）。
/// 页面不通过 `Theme.of(context)` 取样式——绝大多数样式走
/// 编译期常量，以保持 `const` 与低分配开销。
///
/// 颜色的分工约定：**墨是操作色**（主按钮、选中态的文字与底），
/// **朱砂是强调色**（焦点、选中的日期、进度、点缀）。框架组件
/// （datePicker / slider / switch）读 colorScheme.primary = 朱砂，
/// 显式样式的按钮走墨色。
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: AppColors.textOnPrimary,
        secondary: AppColors.accent,
        surface: AppColors.surface,
        error: AppColors.error,
        onSurface: AppColors.textPrimary,
        onSurfaceVariant: AppColors.textSecondary,
        surfaceContainerHighest: AppColors.surfaceVariant,
        outlineVariant: AppColors.divider,
      ),
      scaffoldBackgroundColor: AppColors.background,

      // 输入框：暖灰填充、无描边；聚焦时朱砂细描边（唯一的强调时刻）
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
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
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

      // 主按钮是墨色的（纸色文字）；朱砂留给强调不做操作底色
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.textPrimary,
          foregroundColor: AppColors.textOnInk,
          disabledBackgroundColor: AppColors.inkSubtle,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: 28,
            vertical: AppSpacing.md,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.brLg),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
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
          foregroundColor: AppColors.textPrimary,
          padding: const EdgeInsets.symmetric(
            horizontal: 28,
            vertical: AppSpacing.md,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.brLg),
          side: const BorderSide(color: AppColors.textPrimary, width: 1.2),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),

      // 发丝线是分层的第一工具：1px 暖灰
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 0,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brXl),
        titleTextStyle: AppText.titleSerif.copyWith(
          color: AppColors.textPrimary,
        ),
        contentTextStyle: AppText.body.copyWith(
          color: AppColors.textSecondary,
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: const TextStyle(
          color: AppColors.textOnInk,
          fontSize: 14,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brMd),
        insetPadding: const EdgeInsets.all(AppSpacing.md),
        elevation: 0,
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        linearTrackColor: AppColors.surfaceVariant,
        linearMinHeight: 4,
      ),

      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textSecondary,
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: AppColors.surfaceVariant,
        thumbColor: AppColors.primary,
        overlayColor: AppColors.primary.withValues(alpha: 0.15),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.textPrimary,
          borderRadius: AppRadius.brSm,
        ),
        textStyle: const TextStyle(
          color: AppColors.textOnInk,
          fontSize: 12,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
      ),

      // ══ 文字 ══════════════════════════════════════════════
      //
      // 由 AppText.asTextTheme() 生成：所有未显式给 style的
      // Text / ListTile / SnackBar / Tooltip 拿到正确字号。
      textTheme: AppText.asTextTheme(),

      // 底部弹窗全部走 showPaperSheet（自带白底板 + 顶角），
      // route 层保持透明。
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
