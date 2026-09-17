import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_way_pro/core/ui/glass.dart';

import '../support/app_harness.dart';

void main() {
  setUp(UiEffects.resetForTesting);

  testWidgets('FAB 不被玻璃底部导航遮挡', (WidgetTester tester) async {
    // 守一个实测出来的回归：MainScreen 开了 extendBody: true 之后，
    // 各页自己 Scaffold 的底边也变成了屏幕底边，FAB 被摆到
    // `屏幕高 - 16 - FAB高`，实测压进导航栏 43.5px。
    await pumpSeededApp(tester);

    final Rect nav = tester.getRect(find.byType(GlassNavBar));
    final Rect fab = tester.getRect(find.byType(GlassFab));

    expect(
      fab.bottom,
      lessThanOrEqualTo(nav.top - 8),
      reason: 'FAB 底边 ${fab.bottom} 应完全落在导航栏顶边 ${nav.top} 之上',
    );
  });

  testWidgets('导航栏高度被实测并广播给页面', (WidgetTester tester) async {
    await pumpSeededApp(tester);

    final BuildContext fabContext = tester.element(find.byType(GlassFab));
    expect(
      NavBarInset.of(fabContext),
      greaterThan(0),
      reason: '页面应能读到导航栏高度，否则 FAB 无法避让',
    );
    expect(
      NavBarInset.of(fabContext),
      moreOrLessEquals(
        tester.getRect(find.byType(GlassNavBar)).height,
        epsilon: 0.5,
      ),
    );
  });

  testWidgets('5 个 Tab 都能切换并渲染各自的标题', (WidgetTester tester) async {
    await pumpSeededApp(tester);

    expect(find.text('每日待办'), findsOneWidget);

    for (final (String label, String title) in const <(String, String)>[
      ('任务', '时途'),
      ('统计', '统计'),
      ('规划', '人生规划'),
      ('设置', '设置'),
    ]) {
      await switchToTab(tester, label);
      expect(find.text(title), findsWidgets, reason: '切到「$label」后应渲染标题');
    }
  });

  testWidgets('每个 Tab 的滚动列表都避让了玻璃导航栏', (WidgetTester tester) async {
    // 与 FAB 那条同类：MainScreen 开了 extendBody 之后，页面内容的底边
    // 也变成了屏幕底边，列表底部 padding 不够就会被导航栏压住。
    // 统计页就漏过一次（仍是 EdgeInsets.all(20)）。
    await pumpSeededApp(tester);

    for (final String label in const <String>['待办', '任务', '统计', '规划', '设置']) {
      if (label != '待办') {
        await switchToTab(tester, label);
      }

      final Finder lists = find.byType(ListView);
      expect(lists, findsWidgets, reason: '「$label」应有可滚动列表');

      for (final Element element in lists.evaluate()) {
        final EdgeInsetsGeometry? padding = (element.widget as ListView).padding;
        expect(padding, isNotNull, reason: '「$label」的列表应显式设置 padding');
        final EdgeInsets? resolved =
            padding!.resolve(TextDirection.ltr) as EdgeInsets?;
        expect(
          resolved!.bottom,
          greaterThanOrEqualTo(AppSpacing.navInset),
          reason: '「$label」的列表底部 padding 未避让导航栏',
        );
      }
    }
  });

  testWidgets('窄屏（320dp）下导航栏 5 项不溢出', (WidgetTester tester) async {
    await pumpSeededApp(tester, size: const Size(320, 640));

    expect(tester.takeException(), isNull);
    for (final String label in const <String>['待办', '任务', '统计', '规划', '设置']) {
      expect(find.text(label), findsOneWidget);
    }
  });
}