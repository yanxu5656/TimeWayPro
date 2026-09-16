import 'package:flutter_test/flutter_test.dart';
import 'package:time_way_pro/core/theme/app_theme.dart';

/// 令牌层的防回归护栏。
///
/// 这里的断言不是形式化的"检查常量等于常量"，而是守住几条**有实际后果的
/// 设计约束**——尤其是玻璃层的 alpha：它决定了浅色玻璃方案还能不能读。
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
      expect(AppRadius.sheet, 28);
      expect(AppRadius.full, greaterThan(AppRadius.sheet));
    });
  });

  group('AppColors 玻璃层对比度护栏', () {
    // 卡片填充叠在极光背景上，alpha 越低文字越糊。
    // 这几个下限对应 AppColors 文档里算过的对比度：
    //   glassFill 0.78 → textSecondary ≈ 4.7:1（AA，余量很窄）
    //   一旦有人把它调到 0.70 以下，正文会跌破 AA。
    test('glassFill 不低于 70%', () {
      expect(AppColors.glassFill.a, greaterThanOrEqualTo(0.70));
    });

    test('glassFillStrong 不低于 88%（文字密集卡 / 对话框 / sheet）', () {
      expect(AppColors.glassFillStrong.a, greaterThanOrEqualTo(0.88));
    });

    test('glassFillWeak 不低于 55%（小表面 / chip / 顶栏 / 导航）', () {
      expect(AppColors.glassFillWeak.a, greaterThanOrEqualTo(0.55));
    });

    test('三档填充的不透明度依次递增', () {
      expect(AppColors.glassFillWeak.a, lessThan(AppColors.glassFill.a));
      expect(AppColors.glassFill.a, lessThan(AppColors.glassFillStrong.a));
    });

    test('内高光描边的起点比终点亮（光从左上打来）', () {
      expect(
        AppColors.glassEdgeTop.a,
        greaterThan(AppColors.glassEdgeBottom.a),
      );
    });

    test('热力图空格子比玻璃填充深，否则在玻璃卡上完全看不见', () {
      expect(
        AppColors.heatEmpty.computeLuminance(),
        lessThan(AppColors.glassFill.computeLuminance()),
      );
    });
  });

  group('AppShadows 性能护栏', () {
    // BoxShadow.blur 是每张卡片一次独立的模糊 pass，
    // 列表卡片一律走 e1，blur 必须封顶在 12。
    test('e1 的模糊半径不超过 12', () {
      expect(AppShadows.e1, hasLength(1));
      expect(AppShadows.e1.single.blurRadius, lessThanOrEqualTo(12));
    });

    test('e2 的模糊半径不超过 24', () {
      expect(AppShadows.e2, hasLength(1));
      expect(AppShadows.e2.single.blurRadius, lessThanOrEqualTo(24));
    });

    test('阴影用 slate 着色而非纯黑', () {
      expect(AppColors.glassShadow.r, greaterThan(0));
      expect(AppColors.glassShadow.g, greaterThan(0));
      expect(AppColors.glassShadow.b, greaterThan(0));
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

  group('AppText', () {
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

    test('navInset 足够容纳玻璃底部导航', () {
      // 导航实测高度约 63 + SafeArea，留出余量
      expect(AppSpacing.navInset, greaterThanOrEqualTo(100));
    });
  });
}