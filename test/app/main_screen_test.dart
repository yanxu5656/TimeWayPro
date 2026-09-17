import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_way_pro/app/app.dart';
import 'package:time_way_pro/core/ui/glass.dart';

/// 把 App 泵到稳定状态。
///
/// 需要两次 pump：第一帧布局完成后 `MainScreen` 的 post-frame 回调才量到
/// 导航栏高度，回填触发的重建在第二帧生效。
Future<void> _pumpApp(WidgetTester tester, {Size size = const Size(390, 900)}) async {
  UiEffects.resetForTesting();
  // reduced 而不是 minimal：保留真模糊，让布局与真机一致
  UiEffects.tier.value = UiEffectTier.reduced;

  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(const TimeWayProApp());
  await tester.pump();
  await tester.pump();
}

void main() {
  setUp(UiEffects.resetForTesting);

  testWidgets('FAB 不被玻璃底部导航遮挡', (WidgetTester tester) async {
    // 这条守的是一个实测出来的回归：MainScreen 开了 extendBody: true 之后，
    // 各页自己 Scaffold 的底边也变成了屏幕底边，FAB 被摆到
    // `屏幕高 - 16 - FAB高`，实测压进导航栏 43.5px。
    await _pumpApp(tester);

    final Rect nav = tester.getRect(find.byType(GlassNavBar));
    final Rect fab = tester.getRect(find.byType(GlassFab));

    expect(
      fab.bottom,
      lessThanOrEqualTo(nav.top - 8),
      reason: 'FAB 底边 ${fab.bottom} 应完全落在导航栏顶边 ${nav.top} 之上',
    );
  });

  testWidgets('导航栏高度被实测并广播给页面', (WidgetTester tester) async {
    await _pumpApp(tester);

    final BuildContext fabContext = tester.element(find.byType(GlassFab));
    expect(
      NavBarInset.of(fabContext),
      greaterThan(0),
      reason: '页面应能读到导航栏高度，否则 FAB 无法避让',
    );
    expect(
      NavBarInset.of(fabContext),
      moreOrLessEquals(tester.getRect(find.byType(GlassNavBar)).height, epsilon: 0.5),
    );
  });

  testWidgets('5 个 Tab 都能切换并渲染各自的 chrome', (WidgetTester tester) async {
    await _pumpApp(tester);

    // 初始在「待办」
    expect(find.text('每日待办'), findsOneWidget);

    for (final (String label, String title) in const <(String, String)>[
      ('任务', '时途'),
      ('统计', '统计'),
      ('规划', '人生规划'),
      ('设置', '设置'),
    ]) {
      await tester.tap(find.text(label));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(title), findsWidgets, reason: '切到「$label」后应渲染标题');
    }
  });

  testWidgets('窄屏（320dp）下导航栏 5 项不溢出', (WidgetTester tester) async {
    await _pumpApp(tester, size: const Size(320, 640));

    expect(tester.takeException(), isNull);
    for (final String label in const <String>['待办', '任务', '统计', '规划', '设置']) {
      expect(find.text(label), findsOneWidget);
    }
  });
}