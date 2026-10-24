import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:time_way_pro/core/ui/paper.dart';
import 'package:time_way_pro/core/utils/week.dart';
import 'package:time_way_pro/features/weekly/providers/weekly_provider.dart';

import '../../support/app_harness.dart';

/// 每周目标页的端到端测试。
///
/// 守的是 v1.4.0 的改动：每周目标从待办页顶部的卡片（只能看本周）升级
/// 为独立 Tab，支持翻周到任意周、提前列下周计划、快捷挪周。
///
/// 种子数据（`test/support/app_harness.dart`）里：
/// - 本周 3 条目标（w0 已完成，w1 / w2 未完成）
/// - 上周 1 条（w-old，翻到上周才可见）
void main() {
  Future<void> openWeeklyTab(WidgetTester tester) async {
    await pumpSeededApp(tester);
    await switchToTab(tester, '每周');
  }

  /// 让翻周后的重新加载跑完
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  WeeklyProvider providerOf(WidgetTester tester) =>
      Provider.of<WeeklyProvider>(
        tester.element(find.text('每周目标')),
        listen: false,
      );

  testWidgets('默认显示本周目标，不显示其它周的', (tester) async {
    await openWeeklyTab(tester);

    expect(find.text('本周目标 0'), findsOneWidget);
    expect(find.text('本周目标 1'), findsOneWidget);
    expect(find.text('本周目标 2'), findsOneWidget);
    expect(find.text('上周的目标（翻周后可见）'), findsNothing);
    expect(find.text('回到本周'), findsNothing, reason: '正在本周时不需要归位入口');
  });

  testWidgets('左箭头翻到上周能看到旧目标，「回到本周」能归位', (tester) async {
    await openWeeklyTab(tester);

    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await settle(tester);

    // 上周的目标可见、本周的不在了
    expect(find.text('上周的目标（翻周后可见）'), findsOneWidget);
    expect(find.text('本周目标 0'), findsNothing);
    // 中间卡从「本周」变成日期区间
    expect(
      find.text(weekRangeLabel(DateTime.now().subtract(const Duration(days: 7)))),
      findsOneWidget,
      reason: '非当前周的中间卡应显示周一到周日的日期区间',
    );
    expect(find.text('回到本周'), findsOneWidget);

    await tapAndFlush(tester, find.text('回到本周'));
    expect(find.text('本周目标 0'), findsOneWidget);
    expect(find.text('上周的目标（翻周后可见）'), findsNothing);
  });

  testWidgets('翻到下周添加，目标落在下周而不是本周', (tester) async {
    await openWeeklyTab(tester);

    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await settle(tester);

    await tester.tap(find.byType(PaperFab));
    // 先泵一帧让路由的入场动画开始计时，再给足时长——只泵一帧 600ms
    // 会让动画停在 0%（ticker 首帧 elapsed=0），弹窗仍在屏幕外
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.enterText(find.byType(TextField), '下周的新目标');
    await tapAndFlush(tester, find.text('添加'));

    expect(
      find.text('下周的新目标'),
      findsOneWidget,
      reason: '添加后应该留在下周的视图里，立即看到新目标',
    );
    expect(
      providerOf(tester).selectedWeekKey,
      weekKeyOf(DateTime.now().add(const Duration(days: 7))),
    );

    // 翻回本周：新目标不该跟过来
    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await settle(tester);
    expect(find.text('下周的新目标'), findsNothing);
    expect(find.text('本周目标 0'), findsOneWidget);
  });

  testWidgets('快捷面板点「下周」：目标离开本周、出现在下周队尾', (tester) async {
    await openWeeklyTab(tester);

    // 「本周目标 1」行尾的挪周按钮（列表里第 2 个）
    await tester.tap(find.byIcon(Icons.event_repeat_outlined).at(1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('挪到其他周'), findsOneWidget);
    expect(find.text('「本周目标 1」'), findsOneWidget);
    expect(find.text('当前'), findsOneWidget, reason: '目标所在周应标「当前」');

    await tapAndFlush(tester, find.text('下周'));

    expect(find.text('挪到其他周'), findsNothing, reason: '挪完应关闭面板');
    expect(
      find.text('本周目标 1'),
      findsNothing,
      reason: '目标已不属于本周，应从当前视图消失',
    );

    // 翻到下周：目标在那儿，且排在已有内容之后（下周原本为空，队尾即唯一）
    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await settle(tester);
    expect(find.text('本周目标 1'), findsOneWidget);
  });

  testWidgets('勾选与删除沿用待办的既有交互', (tester) async {
    await openWeeklyTab(tester);

    // 勾选第 3 条（w2 未完成 → 完成）
    await tapAndFlush(
      tester,
      find.byType(InkCheckCircle).at(2),
    );
    expect(providerOf(tester).completed, 2, reason: 'w0 + w2 已完成');

    // 左滑第 3 条删除 → 确认对话框 → 删除
    await tester.drag(
      find.text('本周目标 2'),
      const Offset(-400, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('删除目标'), findsOneWidget);
    await tapAndFlush(tester, find.text('删除'));

    expect(find.text('本周目标 2'), findsNothing);
    expect(providerOf(tester).total, 2);
  });

  testWidgets('窄屏（320dp）下页面与 6 项导航栏不溢出', (tester) async {
    await pumpSeededApp(tester, size: const Size(320, 640));
    await switchToTab(tester, '每周');

    expect(tester.takeException(), isNull);
    expect(find.text('本周目标 0'), findsOneWidget);
    expect(find.byIcon(Icons.event_repeat_outlined), findsNWidgets(3));
  });
}
