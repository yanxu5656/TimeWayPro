import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_way_pro/core/theme/app_theme.dart';

/// WCAG 对比度
double _contrast(Color a, Color b) {
  final double l1 = a.computeLuminance();
  final double l2 = b.computeLuminance();
  return l1 > l2 ? (l1 + 0.05) / (l2 + 0.05) : (l2 + 0.05) / (l1 + 0.05);
}

/// 令牌层的防回归护栏。
///
/// 这里的断言不是形式化的"检查常量等于常量"，而是守住几条**有实际后果的
/// 设计约束**——尤其是纸面上的文字对比度：它决定这套体系还能不能读。
void main() {
  group('AppRadius', () {
    test('圆角档位单调递增', () {
      expect(AppRadius.xs, lessThan(AppRadius.sm));
      expect(AppRadius.sm, lessThan(AppRadius.md));
      expect(AppRadius.md, lessThan(AppRadius.lg));
      expect(AppRadius.lg, lessThan(AppRadius.xl));
      expect(AppRadius.xl, lessThan(AppRadius.sheet));
    });

    test('sheet 是最大的实体圆角，full 只作胶囊哨兵', () {
      expect(AppRadius.sheet, 16);
      expect(AppRadius.full, greaterThan(AppRadius.sheet));
    });
  });

  group('纸面对比度护栏', () {
    // 底色恒为 background（纸白）。这里守住 AppColors 文档里写明的档位：
    //   textPrimary   ≈ 16.1:1  AAA
    //   textSecondary ≈  5.3:1  AA
    //   textHint      ≈  2.7:1  仅装饰（不得用于 <18px 的语义文字）
    //   primary(朱砂) ≈  4.8:1  可作文字色
    test('textPrimary 达到 AAA', () {
      expect(
        _contrast(AppColors.textPrimary, AppColors.background),
        greaterThanOrEqualTo(12),
      );
    });

    test('textSecondary 不跌破 AA', () {
      expect(
        _contrast(AppColors.textSecondary, AppColors.background),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('textHint 低于 AA——这条护栏保证没人会"顺手"拿它当正文色', () {
      expect(
        _contrast(AppColors.textHint, AppColors.background),
        lessThan(4.5),
      );
    });

    test('朱砂（primary）作文字色时不低于 AA', () {
      expect(
        _contrast(AppColors.primary, AppColors.background),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('朱砂底上的纸色文字（textOnPrimary）不低于 AA', () {
      expect(
        _contrast(AppColors.textOnPrimary, AppColors.primary),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('墨底上的纸色文字（textOnInk）达到 AAA', () {
      expect(
        _contrast(AppColors.textOnInk, AppColors.textPrimary),
        greaterThanOrEqualTo(12),
      );
    });

    test('热力图空格子比纸面深，否则看不见', () {
      expect(
        AppColors.heatEmpty.computeLuminance(),
        lessThan(AppColors.background.computeLuminance()),
      );
    });

    test('发丝线（divider）在纸面上可见但轻于文字', () {
      expect(
        _contrast(AppColors.divider, AppColors.background),
        greaterThan(1.05),
      );
      expect(
        AppColors.divider.computeLuminance(),
        greaterThan(AppColors.textSecondary.computeLuminance()),
      );
    });
  });

  group('AppShadows 护栏', () {
    // 阴影在这个体系里是稀缺品，模糊半径必须克制
    test('e1 的每层模糊半径不超过 12', () {
      for (final s in AppShadows.e1) {
        expect(s.blurRadius, lessThanOrEqualTo(12));
      }
    });

    test('e2 的模糊半径不超过 24', () {
      expect(AppShadows.e2, hasLength(1));
      expect(AppShadows.e2.single.blurRadius, lessThanOrEqualTo(24));
    });

    test('阴影用暖墨着色而非纯黑（纯黑在纸面上显脏）', () {
      expect(AppColors.shadow.r, greaterThan(0));
      expect(AppColors.shadow.g, greaterThan(0));
      expect(AppColors.shadow.b, greaterThan(0));
    });
  });

  group('图表配色', () {
    test('至少 6 色且无重复（饼图需要可区分的色相）', () {
      expect(AppColors.chartColors.length, greaterThanOrEqualTo(6));
      expect(
        AppColors.chartColors.toSet().length,
        AppColors.chartColors.length,
      );
    });

    test('热力图色阶亮度严格递减', () {
      final colors = AppColors.heatMapColors;
      expect(colors.length, greaterThanOrEqualTo(5));
      for (var i = 1; i < colors.length; i++) {
        expect(
          colors[i].computeLuminance(),
          lessThan(colors[i - 1].computeLuminance()),
          reason: '第 $i 档不比前一档暗，色阶会出现断层',
        );
      }
    });
  });

  group('AppText 衬线槽位', () {
    test('衬线槽位挂上了打包字体', () {
      expect(AppText.masthead.fontFamily, 'NotoSerifSC');
      expect(AppText.titleSerif.fontFamily, 'NotoSerifSC');
      expect(AppText.bodySerif.fontFamily, 'NotoSerifSC');
      expect(AppText.serifNum.fontFamily, 'Playfair');
      expect(AppText.numXl.fontFamily, 'Playfair');
      expect(AppText.numLg.fontFamily, 'Playfair');
    });

    test('kicker 的字距拉到了眉题档位（约 0.3em）', () {
      expect(AppText.kicker.letterSpacing, greaterThanOrEqualTo(2.5));
    });

    test('asTextTheme 覆盖 M3 的 15 个槽位', () {
      final t = AppText.asTextTheme();
      expect(t.displayLarge, isNotNull);
      expect(t.displayMedium, isNotNull);
      expect(t.displaySmall, isNotNull);
      expect(t.headlineLarge, isNotNull);
      expect(t.headlineMedium, isNotNull);
      expect(t.headlineSmall, isNotNull);
      expect(t.titleLarge, isNotNull);
      expect(t.titleMedium, isNotNull);
      expect(t.titleSmall, isNotNull);
      expect(t.bodyLarge, isNotNull);
      expect(t.bodyMedium, isNotNull);
      expect(t.bodySmall, isNotNull);
      expect(t.labelLarge, isNotNull);
      expect(t.labelMedium, isNotNull);
      expect(t.labelSmall, isNotNull);
    });

    test('标题字号随层级递减', () {
      expect(AppText.display.fontSize!, greaterThan(AppText.h1.fontSize!));
      expect(AppText.h1.fontSize!, greaterThan(AppText.h2.fontSize!));
      expect(AppText.h2.fontSize!, greaterThan(AppText.h3.fontSize!));
      expect(AppText.h3.fontSize!, greaterThan(AppText.body.fontSize!));
    });
  });

  group('AppSpacing', () {
    test('4pt 网格且单调递增', () {
      expect(AppSpacing.xxs, 4);
      expect(AppSpacing.xxs, lessThan(AppSpacing.xs));
      expect(AppSpacing.xs, lessThan(AppSpacing.sm));
      expect(AppSpacing.sm, lessThan(AppSpacing.md));
      expect(AppSpacing.md, lessThan(AppSpacing.lg));
      expect(AppSpacing.lg, lessThan(AppSpacing.xl));
      expect(AppSpacing.xl, lessThan(AppSpacing.xxl));
      expect(AppSpacing.xxl, lessThan(AppSpacing.huge));
    });

    test('navInset 足够容纳纸面底部导航', () {
      // 导航实测高度约 70 + SafeArea，留出余量
      expect(AppSpacing.navInset, greaterThanOrEqualTo(100));
    });
  });
}
