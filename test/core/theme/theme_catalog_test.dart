import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_way_pro/core/theme/app_theme.dart';

double _contrast(Color a, Color b) {
  final double l1 = a.computeLuminance();
  final double l2 = b.computeLuminance();
  return l1 > l2 ? (l1 + 0.05) / (l2 + 0.05) : (l2 + 0.05) / (l1 + 0.05);
}

void main() {
  test('目录包含五种风格且 ID 唯一', () {
    expect(AppThemeCatalog.options, hasLength(11));
    expect(
      AppThemeCatalog.options.map((AppThemeOption option) => option.id).toSet(),
      hasLength(11),
    );
    for (final ThemeFamily family in ThemeFamily.values) {
      expect(
        AppThemeCatalog.byFamily(family).length,
        family == ThemeFamily.warm || family == ThemeFamily.aurora ? 1 : 3,
      );
    }
    expect(AppThemeCatalog.defaultOption.id, 'warm_paper');
  });

  test('未知 ID 回退默认主题，null 也回退默认主题', () {
    expect(AppThemeCatalog.byId('removed_theme').id, 'warm_paper');
    expect(AppThemeCatalog.byId(null).id, 'warm_paper');
    expect(AppThemeCatalog.byId('tech_matrix').name, '矩阵夜航');
  });

  test('默认主题保留暖笺色板、衬线字体与双层行阴影', () {
    final AppDesign design = AppThemeCatalog.defaultOption.design;
    expect(design.palette.primary, AppColors.primary);
    expect(design.palette.primaryDark, AppColors.primaryDark);
    expect(design.palette.primaryLight, AppColors.primaryLight);
    expect(design.palette.primarySubtle, AppColors.primarySubtle);
    expect(design.typography.masthead.fontFamily, 'NotoSerifSC');
    expect(design.shape.rowShadows, hasLength(2));
    expect(AppTheme.lightTheme.scaffoldBackgroundColor, AppColors.background);
  });

  for (final AppThemeOption option in AppThemeCatalog.options) {
    test('${option.name} 的正文与主色对比度达到 AA', () {
      final AppPalette c = option.design.palette;
      expect(
        _contrast(c.textPrimary, c.background),
        greaterThanOrEqualTo(12),
        reason: '正文应达到 AAA',
      );
      expect(
        _contrast(c.textSecondary, c.background),
        greaterThanOrEqualTo(4.5),
      );
      expect(_contrast(c.textPrimary, c.surface), greaterThanOrEqualTo(12));
      expect(_contrast(c.textSecondary, c.surface), greaterThanOrEqualTo(4.5));
      expect(_contrast(c.primary, c.background), greaterThanOrEqualTo(4.5));
      expect(_contrast(c.primary, c.surface), greaterThanOrEqualTo(4.5));
      expect(_contrast(c.textOnPrimary, c.primary), greaterThanOrEqualTo(4.5));
      final Color muted = Color.alphaBlend(c.textOnPrimaryMuted, c.primary);
      expect(_contrast(muted, c.primary), greaterThanOrEqualTo(4.5));
    });

    test('${option.name} 的 ThemeData 与设计令牌一致', () {
      final ThemeData theme = AppTheme.forDesign(option.design);
      final AppPalette c = option.design.palette;
      expect(theme.extension<AppDesign>(), same(option.design));
      expect(theme.scaffoldBackgroundColor, c.background);
      expect(theme.colorScheme.primary, c.primary);
      expect(theme.colorScheme.onPrimary, c.textOnPrimary);
      expect(theme.brightness, c.isDark ? Brightness.dark : Brightness.light);
      expect(
        theme.appBarTheme.systemOverlayStyle?.statusBarIconBrightness,
        c.isDark ? Brightness.light : Brightness.dark,
      );
    });
  }

  test('简洁、可爱、科技分别采用对应字体与圆角策略', () {
    for (final AppThemeOption option in AppThemeCatalog.options) {
      final AppDesign design = option.design;
      switch (design.style) {
        case ThemeVisualStyle.editorial:
          expect(design.shape.showMastheadGhost, isTrue);
          expect(design.shape.cardRadius, 16);
        case ThemeVisualStyle.clean:
          expect(design.typography.masthead.fontFamily, 'Roboto');
          expect(design.shape.rowShadows, isEmpty);
          expect(design.shape.cardRadius, 10);
        case ThemeVisualStyle.playful:
          expect(design.typography.masthead.fontWeight, FontWeight.w700);
          expect(design.shape.rowShadows, isNotEmpty);
          expect(design.shape.cardRadius, 22);
        case ThemeVisualStyle.technical:
          expect(design.typography.masthead.fontFamily, 'monospace');
          expect(design.palette.isDark, isTrue);
          expect(design.shape.cardRadius, 8);
        case ThemeVisualStyle.fluid:
          expect(design.atmosphere, isNotNull);
          expect(design.shape.cardRadius, 30);
          expect(design.shape.sheetRadius, 40);
          expect(design.shape.controlRadius, 24);
      }
    }
  });
}
