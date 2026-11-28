import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_atmosphere.dart';
import 'app_design.dart';
import 'app_spacing.dart';
import 'app_text.dart';

export 'app_atmosphere.dart';
export 'app_colors.dart';
export 'app_design.dart';
export 'app_radius.dart';
export 'app_shadows.dart';
export 'app_spacing.dart';
export 'app_text.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme =>
      forDesign(AppThemeCatalog.defaultOption.design);

  static ThemeData forDesign(AppDesign design) {
    final AppPalette c = design.palette;
    final AppTypography t = design.typography;
    final AppShape s = design.shape;
    final AppAtmosphere? atmosphere = design.atmosphere;
    final bool glass = atmosphere != null;
    final BorderRadius controlRadius = BorderRadius.all(
      Radius.circular(s.controlRadius),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: c.isDark ? Brightness.dark : Brightness.light,
      extensions: <ThemeExtension<dynamic>>[design],
      colorScheme: ColorScheme.fromSeed(
        seedColor: c.primary,
        brightness: c.isDark ? Brightness.dark : Brightness.light,
        primary: c.primary,
        onPrimary: c.textOnPrimary,
        secondary: c.accent,
        surface: c.surface,
        error: c.error,
        onSurface: c.textPrimary,
        onSurfaceVariant: c.textSecondary,
        surfaceContainerHighest: c.surfaceVariant,
        outlineVariant: c.divider,
      ),
      scaffoldBackgroundColor: c.background,
      canvasColor: glass ? Colors.transparent : c.background,
      appBarTheme: AppBarTheme(
        backgroundColor: glass ? Colors.transparent : c.background,
        scrolledUnderElevation: 0,
        foregroundColor: c.textPrimary,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: c.isDark
              ? Brightness.light
              : Brightness.dark,
          systemNavigationBarIconBrightness: c.isDark
              ? Brightness.light
              : Brightness.dark,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: glass
            ? atmosphere.glassFill.withValues(alpha: 0.72)
            : c.surfaceVariant,
        hintStyle: TextStyle(color: c.textHint, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: glass
              ? BorderSide(
                  color: atmosphere.glassBorder.withValues(alpha: 0.26),
                )
              : BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: glass
              ? BorderSide(
                  color: atmosphere.glassBorder.withValues(alpha: 0.26),
                )
              : BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: BorderSide(color: c.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: BorderSide(color: c.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: BorderSide(color: c.error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.textOnPrimary,
          disabledBackgroundColor: c.inkSubtle,
          elevation: 0,
          overlayColor: c.textOnPrimary.withValues(alpha: 0.18),
          padding: const EdgeInsets.symmetric(
            horizontal: 28,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(borderRadius: controlRadius),
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.primary,
          overlayColor: c.primary.withValues(alpha: 0.10),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          shape: RoundedRectangleBorder(borderRadius: controlRadius),
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.primary,
          overlayColor: c.primary.withValues(alpha: 0.10),
          padding: const EdgeInsets.symmetric(
            horizontal: 28,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(borderRadius: controlRadius),
          side: BorderSide(color: c.primary, width: 1.2),
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: glass ? Colors.white.withValues(alpha: 0.12) : c.divider,
        thickness: 1,
        space: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: glass
            ? atmosphere.dialogFill.withValues(alpha: 0.96)
            : c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: glass ? 24 : 0,
        shadowColor: glass ? Colors.black.withValues(alpha: 0.55) : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(glass ? 30 : s.cardRadius),
        ),
        titleTextStyle: t.titleSerif.copyWith(color: c.textPrimary),
        contentTextStyle: AppText.body.copyWith(color: c.textSecondary),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: glass ? c.surface : c.textPrimary,
        contentTextStyle: TextStyle(
          color: glass ? c.textPrimary : c.textOnInk,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: controlRadius),
        insetPadding: const EdgeInsets.all(AppSpacing.md),
        elevation: 0,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.primary,
        linearTrackColor: glass
            ? Colors.white.withValues(alpha: 0.1)
            : c.surfaceVariant,
        linearMinHeight: 4,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.textSecondary,
        textColor: c.textPrimary,
        subtitleTextStyle: AppText.caption.copyWith(color: c.textSecondary),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: c.primary,
        inactiveTrackColor: c.surfaceVariant,
        thumbColor: c.primary,
        overlayColor: c.primary.withValues(alpha: 0.15),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: glass ? c.surface : c.textPrimary,
          borderRadius: BorderRadius.circular(s.controlRadius),
        ),
        textStyle: TextStyle(
          color: glass ? c.textPrimary : c.textOnInk,
          fontSize: 12,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? c.textOnPrimary
              : c.textHint,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? c.primary
              : c.surfaceVariant,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? c.primary
              : Colors.transparent,
        ),
        checkColor: WidgetStateProperty.all(c.textOnPrimary),
        side: BorderSide(color: c.dividerStrong),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? c.primary
              : c.dividerStrong,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surfaceVariant,
        selectedColor: c.primary,
        secondarySelectedColor: c.primary,
        labelStyle: AppText.label.copyWith(color: c.textPrimary),
        secondaryLabelStyle: AppText.label.copyWith(color: c.textOnPrimary),
        side: BorderSide(color: c.divider),
        shape: RoundedRectangleBorder(borderRadius: controlRadius),
      ),
      textTheme: AppText.asTextTheme().apply(
        bodyColor: c.textPrimary,
        displayColor: c.textPrimary,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(s.sheetRadius),
          ),
        ),
      ),
    );
  }
}
