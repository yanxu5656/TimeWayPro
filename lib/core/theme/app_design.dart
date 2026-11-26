import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_shadows.dart';
import 'app_text.dart';

enum ThemeFamily { warm, minimal, cute, tech }

enum ThemeVisualStyle { editorial, clean, playful, technical }

class AppPalette {
  const AppPalette({
    required this.primary,
    required this.accent,
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.textPrimary,
    required this.textSecondary,
    required this.textHint,
    required this.textOnPrimary,
    required this.textOnInk,
    required this.textOnPrimaryMuted,
    required this.accentOnPrimary,
    required this.ghostOnPrimary,
    required this.divider,
    required this.dividerStrong,
    required this.scrim,
    required this.inkSubtle,
    required this.inkFaint,
    required this.error,
    required this.success,
    required this.warning,
    required this.info,
    required this.shadow,
    required this.shadowMedium,
    required this.heatEmpty,
    required this.chartColors,
    required this.heatMapColors,
    required this.isDark,
    this.primaryDarkValue,
    this.primaryLightValue,
    this.primarySubtleValue,
  });

  final Color primary;
  final Color accent;
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color textPrimary;
  final Color textSecondary;
  final Color textHint;
  final Color textOnPrimary;
  final Color textOnInk;
  final Color textOnPrimaryMuted;
  final Color accentOnPrimary;
  final Color ghostOnPrimary;
  final Color divider;
  final Color dividerStrong;
  final Color scrim;
  final Color inkSubtle;
  final Color inkFaint;
  final Color error;
  final Color success;
  final Color warning;
  final Color info;
  final Color shadow;
  final Color shadowMedium;
  final Color heatEmpty;
  final List<Color> chartColors;
  final List<Color> heatMapColors;
  final bool isDark;
  final Color? primaryDarkValue;
  final Color? primaryLightValue;
  final Color? primarySubtleValue;

  Color get primaryDark =>
      primaryDarkValue ??
      Color.alphaBlend(Colors.black.withValues(alpha: 0.18), primary);

  Color get primaryLight =>
      primaryLightValue ??
      Color.alphaBlend(primary.withValues(alpha: 0.20), surface);

  Color get primarySubtle =>
      primarySubtleValue ??
      Color.alphaBlend(primary.withValues(alpha: 0.10), surface);

  static const AppPalette warm = AppPalette(
    primary: AppColors.primary,
    accent: AppColors.accent,
    background: AppColors.background,
    surface: AppColors.surface,
    surfaceVariant: AppColors.surfaceVariant,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    textHint: AppColors.textHint,
    textOnPrimary: AppColors.textOnPrimary,
    textOnInk: AppColors.textOnInk,
    textOnPrimaryMuted: AppColors.textOnPrimaryMuted,
    accentOnPrimary: AppColors.accentOnPrimary,
    ghostOnPrimary: AppColors.ghostOnPrimary,
    divider: AppColors.divider,
    dividerStrong: AppColors.dividerStrong,
    scrim: AppColors.scrim,
    inkSubtle: AppColors.inkSubtle,
    inkFaint: AppColors.inkFaint,
    error: AppColors.error,
    success: AppColors.success,
    warning: AppColors.warning,
    info: AppColors.info,
    shadow: AppColors.shadow,
    shadowMedium: AppColors.shadowMedium,
    heatEmpty: AppColors.heatEmpty,
    chartColors: AppColors.chartColors,
    heatMapColors: AppColors.heatMapColors,
    isDark: false,
    primaryDarkValue: AppColors.primaryDark,
    primaryLightValue: AppColors.primaryLight,
    primarySubtleValue: AppColors.primarySubtle,
  );
}

class AppTypography {
  const AppTypography({
    required this.masthead,
    required this.titleSerif,
    required this.bodySerif,
    required this.serifNum,
    required this.numXl,
    required this.numLg,
    required this.kicker,
    required this.mono,
  });

  final TextStyle masthead;
  final TextStyle titleSerif;
  final TextStyle bodySerif;
  final TextStyle serifNum;
  final TextStyle numXl;
  final TextStyle numLg;
  final TextStyle kicker;
  final TextStyle mono;

  static AppTypography forStyle(ThemeVisualStyle style) {
    final String displayFamily = switch (style) {
      ThemeVisualStyle.editorial => 'NotoSerifSC',
      ThemeVisualStyle.clean => 'Roboto',
      ThemeVisualStyle.playful => 'Roboto',
      ThemeVisualStyle.technical => 'monospace',
    };
    final String numberFamily = style == ThemeVisualStyle.editorial
        ? 'Playfair'
        : style == ThemeVisualStyle.technical
        ? 'monospace'
        : 'Roboto';
    final FontWeight titleWeight = style == ThemeVisualStyle.playful
        ? FontWeight.w700
        : FontWeight.w600;

    return AppTypography(
      masthead: AppText.masthead.copyWith(
        fontFamily: displayFamily,
        fontWeight: titleWeight,
        letterSpacing: style == ThemeVisualStyle.clean ? -0.2 : 0.2,
      ),
      titleSerif: AppText.titleSerif.copyWith(
        fontFamily: displayFamily,
        fontWeight: titleWeight,
      ),
      bodySerif: AppText.bodySerif.copyWith(fontFamily: displayFamily),
      serifNum: AppText.serifNum.copyWith(fontFamily: numberFamily),
      numXl: AppText.numXl.copyWith(fontFamily: numberFamily),
      numLg: AppText.numLg.copyWith(fontFamily: numberFamily),
      kicker: AppText.kicker.copyWith(
        letterSpacing: style == ThemeVisualStyle.technical ? 1.4 : 2,
      ),
      mono: AppText.mono.copyWith(
        fontFamily: style == ThemeVisualStyle.technical
            ? 'monospace'
            : AppText.mono.fontFamily,
      ),
    );
  }
}

class AppShape {
  const AppShape({
    required this.cardRadius,
    required this.controlRadius,
    required this.sheetRadius,
    required this.rowShadows,
    required this.floatShadows,
    required this.showMastheadGhost,
  });

  final double cardRadius;
  final double controlRadius;
  final double sheetRadius;
  final List<BoxShadow> rowShadows;
  final List<BoxShadow> floatShadows;
  final bool showMastheadGhost;

  static AppShape forDesign(AppPalette palette, ThemeVisualStyle style) {
    final double radius = switch (style) {
      ThemeVisualStyle.editorial => 16,
      ThemeVisualStyle.clean => 10,
      ThemeVisualStyle.playful => 22,
      ThemeVisualStyle.technical => 8,
    };
    final bool shadows = style != ThemeVisualStyle.clean;
    return AppShape(
      cardRadius: radius,
      controlRadius: style == ThemeVisualStyle.playful ? 16 : radius - 4,
      sheetRadius: style == ThemeVisualStyle.playful ? 26 : radius,
      rowShadows: shadows
          ? <BoxShadow>[
              BoxShadow(
                color: palette.shadow,
                blurRadius: style == ThemeVisualStyle.technical ? 16 : 12,
                offset: const Offset(0, 4),
              ),
            ]
          : const <BoxShadow>[],
      floatShadows: <BoxShadow>[
        BoxShadow(
          color: palette.shadowMedium,
          blurRadius: style == ThemeVisualStyle.technical ? 28 : 24,
          offset: const Offset(0, 10),
        ),
      ],
      showMastheadGhost: style == ThemeVisualStyle.editorial,
    );
  }
}

class AppDesign extends ThemeExtension<AppDesign> {
  const AppDesign({
    required this.palette,
    required this.typography,
    required this.shape,
    required this.style,
  });

  final AppPalette palette;
  final AppTypography typography;
  final AppShape shape;
  final ThemeVisualStyle style;

  @override
  AppDesign copyWith({
    AppPalette? palette,
    AppTypography? typography,
    AppShape? shape,
    ThemeVisualStyle? style,
  }) {
    return AppDesign(
      palette: palette ?? this.palette,
      typography: typography ?? this.typography,
      shape: shape ?? this.shape,
      style: style ?? this.style,
    );
  }

  @override
  AppDesign lerp(covariant AppDesign? other, double t) => this;
}

extension AppDesignContext on BuildContext {
  AppDesign get design =>
      Theme.of(this).extension<AppDesign>() ??
      AppThemeCatalog.defaultOption.design;

  AppPalette get colors => design.palette;
  AppTypography get text => design.typography;
  AppShape get shape => design.shape;
}

class AppThemeOption {
  const AppThemeOption({
    required this.id,
    required this.name,
    required this.tagline,
    required this.family,
    required this.design,
  });

  final String id;
  final String name;
  final String tagline;
  final ThemeFamily family;
  final AppDesign design;
}

AppPalette _palette({
  required Color primary,
  required Color accent,
  required Color background,
  required Color surface,
  required Color surfaceVariant,
  required bool isDark,
  List<Color>? chartColors,
  List<Color>? heatMapColors,
}) {
  final Color textPrimary = isDark
      ? const Color(0xFFF2F5F7)
      : const Color(0xFF202A2E);
  final Color textSecondary = Color.alphaBlend(
    textPrimary.withValues(alpha: isDark ? 0.74 : 0.68),
    background,
  );
  final Color textHint = Color.alphaBlend(
    textPrimary.withValues(alpha: 0.42),
    background,
  );
  final Color onPrimary = primary.computeLuminance() > 0.45
      ? const Color(0xFF172126)
      : Colors.white;
  final Color shadow = isDark
      ? Colors.black.withValues(alpha: 0.32)
      : primary.withValues(alpha: 0.10);
  final List<Color> charts =
      chartColors ??
      <Color>[
        primary,
        accent,
        const Color(0xFFD09A43),
        const Color(0xFF4E86A0),
        const Color(0xFFC76B63),
        const Color(0xFF8B78AD),
        textSecondary,
        const Color(0xFF8C9A78),
      ];
  final List<Color> heat =
      heatMapColors ??
      <Color>[
        Color.alphaBlend(primary.withValues(alpha: 0.12), surface),
        Color.alphaBlend(primary.withValues(alpha: 0.28), surface),
        Color.alphaBlend(primary.withValues(alpha: 0.48), surface),
        Color.alphaBlend(primary.withValues(alpha: 0.72), surface),
        primary,
      ];

  return AppPalette(
    primary: primary,
    accent: accent,
    background: background,
    surface: surface,
    surfaceVariant: surfaceVariant,
    textPrimary: textPrimary,
    textSecondary: textSecondary,
    textHint: textHint,
    textOnPrimary: onPrimary,
    textOnInk: onPrimary,
    textOnPrimaryMuted: onPrimary.withValues(alpha: 0.92),
    accentOnPrimary: onPrimary,
    ghostOnPrimary: onPrimary.withValues(alpha: 0.16),
    divider: Color.alphaBlend(
      textPrimary.withValues(alpha: isDark ? 0.12 : 0.10),
      background,
    ),
    dividerStrong: Color.alphaBlend(
      textPrimary.withValues(alpha: 0.22),
      background,
    ),
    scrim: (isDark ? Colors.black : textPrimary).withValues(alpha: 0.42),
    inkSubtle: textPrimary.withValues(alpha: isDark ? 0.12 : 0.08),
    inkFaint: textPrimary.withValues(alpha: isDark ? 0.06 : 0.04),
    error: isDark ? const Color(0xFFFF8F86) : const Color(0xFFB33A3A),
    success: isDark ? const Color(0xFF79D6A3) : const Color(0xFF287A55),
    warning: isDark ? const Color(0xFFF1C46B) : const Color(0xFF946316),
    info: isDark ? const Color(0xFF7FC7ED) : const Color(0xFF2D6F93),
    shadow: shadow,
    shadowMedium: shadow.withValues(alpha: isDark ? 0.48 : 0.20),
    heatEmpty: Color.alphaBlend(textPrimary.withValues(alpha: 0.06), surface),
    chartColors: List<Color>.unmodifiable(charts),
    heatMapColors: List<Color>.unmodifiable(heat),
    isDark: isDark,
  );
}

AppDesign _design(AppPalette palette, ThemeVisualStyle style) => AppDesign(
  palette: palette,
  typography: AppTypography.forStyle(style),
  shape: AppShape.forDesign(palette, style),
  style: style,
);

class AppThemeCatalog {
  AppThemeCatalog._();

  static final List<AppThemeOption> options = <AppThemeOption>[
    const AppThemeOption(
      id: 'warm_paper',
      name: '陶土暖笺',
      tagline: '暖纸、陶土与衬线账本',
      family: ThemeFamily.warm,
      design: AppDesign(
        palette: AppPalette.warm,
        typography: AppTypography(
          masthead: AppText.masthead,
          titleSerif: AppText.titleSerif,
          bodySerif: AppText.bodySerif,
          serifNum: AppText.serifNum,
          numXl: AppText.numXl,
          numLg: AppText.numLg,
          kicker: AppText.kicker,
          mono: AppText.mono,
        ),
        shape: AppShape(
          cardRadius: 16,
          controlRadius: 12,
          sheetRadius: 16,
          rowShadows: AppShadows.e1,
          floatShadows: <BoxShadow>[
            BoxShadow(
              color: AppColors.shadowMedium,
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
          showMastheadGhost: true,
        ),
        style: ThemeVisualStyle.editorial,
      ),
    ),
    for (final AppThemeOption option in <AppThemeOption>[
      AppThemeOption(
        id: 'minimal_cloud',
        name: '云白',
        tagline: '克制留白，雾蓝点睛',
        family: ThemeFamily.minimal,
        design: _design(
          _palette(
            primary: const Color(0xFF42677A),
            accent: const Color(0xFF708B7A),
            background: const Color(0xFFF4F6F5),
            surface: const Color(0xFFFFFFFF),
            surfaceVariant: const Color(0xFFE9EEEC),
            isDark: false,
          ),
          ThemeVisualStyle.clean,
        ),
      ),
      AppThemeOption(
        id: 'minimal_forest',
        name: '青野',
        tagline: '低饱和绿，清爽呼吸感',
        family: ThemeFamily.minimal,
        design: _design(
          _palette(
            primary: const Color(0xFF356B59),
            accent: const Color(0xFF80916B),
            background: const Color(0xFFF3F5EF),
            surface: const Color(0xFFFDFEFB),
            surfaceVariant: const Color(0xFFE5EBE1),
            isDark: false,
          ),
          ThemeVisualStyle.clean,
        ),
      ),
      AppThemeOption(
        id: 'minimal_graphite',
        name: '石墨',
        tagline: '中性灰阶，专注内容本身',
        family: ThemeFamily.minimal,
        design: _design(
          _palette(
            primary: const Color(0xFF414A50),
            accent: const Color(0xFF7A858A),
            background: const Color(0xFFF2F3F3),
            surface: const Color(0xFFFFFFFF),
            surfaceVariant: const Color(0xFFE7E9E9),
            isDark: false,
          ),
          ThemeVisualStyle.clean,
        ),
      ),
    ])
      option,
    for (final AppThemeOption option in <AppThemeOption>[
      AppThemeOption(
        id: 'cute_peach',
        name: '蜜桃汽水',
        tagline: '软蜜桃与奶油白，轻快圆润',
        family: ThemeFamily.cute,
        design: _design(
          _palette(
            primary: const Color(0xFFB44D60),
            accent: const Color(0xFFE29A55),
            background: const Color(0xFFFFF5F1),
            surface: const Color(0xFFFFFCF8),
            surfaceVariant: const Color(0xFFFFE7DF),
            isDark: false,
            chartColors: const <Color>[
              Color(0xFFB44D60),
              Color(0xFFE29A55),
              Color(0xFFD5A32F),
              Color(0xFF6B9B8D),
              Color(0xFF9A7BB5),
              Color(0xFFD98498),
              Color(0xFF8D7667),
              Color(0xFF86A85D),
            ],
          ),
          ThemeVisualStyle.playful,
        ),
      ),
      AppThemeOption(
        id: 'cute_mint',
        name: '薄荷糖',
        tagline: '清透薄荷，柔和果冻质感',
        family: ThemeFamily.cute,
        design: _design(
          _palette(
            primary: const Color(0xFF247561),
            accent: const Color(0xFFE2A84F),
            background: const Color(0xFFF0FAF5),
            surface: const Color(0xFFFCFEFD),
            surfaceVariant: const Color(0xFFDDF2E9),
            isDark: false,
          ),
          ThemeVisualStyle.playful,
        ),
      ),
      AppThemeOption(
        id: 'cute_lavender',
        name: '莓莓云朵',
        tagline: '柔紫与莓果，甜美不刺眼',
        family: ThemeFamily.cute,
        design: _design(
          _palette(
            primary: const Color(0xFF785292),
            accent: const Color(0xFFD17C9C),
            background: const Color(0xFFF8F2FC),
            surface: const Color(0xFFFFFCFF),
            surfaceVariant: const Color(0xFFEDE2F5),
            isDark: false,
          ),
          ThemeVisualStyle.playful,
        ),
      ),
    ])
      option,
    for (final AppThemeOption option in <AppThemeOption>[
      AppThemeOption(
        id: 'tech_deepspace',
        name: '深空蓝',
        tagline: '深夜蓝底，冷静冰蓝高光',
        family: ThemeFamily.tech,
        design: _design(
          _palette(
            primary: const Color(0xFF62D7E8),
            accent: const Color(0xFF8EA2FF),
            background: const Color(0xFF09131E),
            surface: const Color(0xFF101F2D),
            surfaceVariant: const Color(0xFF172B3D),
            isDark: true,
          ),
          ThemeVisualStyle.technical,
        ),
      ),
      AppThemeOption(
        id: 'tech_neon',
        name: '霓虹脉冲',
        tagline: '黑紫底色，电光青与荧光绿',
        family: ThemeFamily.tech,
        design: _design(
          _palette(
            primary: const Color(0xFF62E6B6),
            accent: const Color(0xFFDD83FF),
            background: const Color(0xFF100D19),
            surface: const Color(0xFF1A1528),
            surfaceVariant: const Color(0xFF272039),
            isDark: true,
            chartColors: const <Color>[
              Color(0xFF62E6B6),
              Color(0xFFDD83FF),
              Color(0xFFF0CA68),
              Color(0xFF67C7F2),
              Color(0xFFFF789D),
              Color(0xFF9E8CFF),
              Color(0xFFB8C5D1),
              Color(0xFFB4DD67),
            ],
          ),
          ThemeVisualStyle.technical,
        ),
      ),
      AppThemeOption(
        id: 'tech_matrix',
        name: '矩阵夜航',
        tagline: '碳黑与荧光绿，极客仪表盘',
        family: ThemeFamily.tech,
        design: _design(
          _palette(
            primary: const Color(0xFF9BE564),
            accent: const Color(0xFF56C9C1),
            background: const Color(0xFF0C110D),
            surface: const Color(0xFF141D17),
            surfaceVariant: const Color(0xFF1E2D23),
            isDark: true,
          ),
          ThemeVisualStyle.technical,
        ),
      ),
    ])
      option,
  ];

  static AppThemeOption get defaultOption => options.first;

  static AppThemeOption byId(String? id) => options.firstWhere(
    (AppThemeOption option) => option.id == id,
    orElse: () => defaultOption,
  );

  static List<AppThemeOption> byFamily(ThemeFamily family) => <AppThemeOption>[
    for (final AppThemeOption option in options)
      if (option.family == family) option,
  ];
}
