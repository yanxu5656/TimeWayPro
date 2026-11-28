import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:time_way_pro/core/ui/paper.dart';
import 'package:time_way_pro/features/weekly/data/models/weekly_goal.dart';
import 'package:time_way_pro/features/weekly/providers/weekly_provider.dart';

import '../../support/app_harness.dart';

void main() {
  testWidgets('每周目标可配置金币，新模块展示商店仓库和明细', (tester) async {
    await pumpSeededApp(tester);
    await switchToTab(tester, '每周');
    await tester.tap(find.byType(PaperFab));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.enterText(find.byKey(const Key('weekly_goal_title')), '跑步三次');
    await tester.tap(find.byKey(const Key('weekly_reward_switch')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('weekly_coin_reward')));
    await tester.enterText(find.byKey(const Key('weekly_coin_reward')), '120');
    await tester.ensureVisible(find.text('添加'));
    await tester.pump();
    expect(
      tester
          .widget<PaperButton>(find.widgetWithText(PaperButton, '添加'))
          .onPressed,
      isNotNull,
    );
    expect(find.text('请输入 1–999999 金币'), findsNothing);
    await tester.runAsync(() async {
      tester
          .widget<PaperButton>(find.widgetWithText(PaperButton, '添加'))
          .onPressed!();
      await Future<void>.delayed(const Duration(milliseconds: 800));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('跑步三次'), findsOneWidget);
    expect(find.byKey(const Key('weekly_goal_title')), findsNothing);
    final WeeklyProvider weekly = tester
        .element(find.text('每周目标'))
        .read<WeeklyProvider>();
    expect(
      weekly.goals.firstWhere((WeeklyGoal goal) => goal.title == '跑步三次').coinReward,
      120,
    );
    expect(find.text('完成奖励 120 金币'), findsOneWidget);

    await switchToTab(tester, '商店');
    expect(find.text('奖励商店'), findsOneWidget);
    expect(find.text('看一场电影'), findsOneWidget);
    await tester.tap(find.text('仓库'));
    await tester.pump();
    expect(find.text('仓库空着'), findsOneWidget);
    await tester.tap(find.text('明细'));
    await tester.pump();
    expect(find.text('还没有金币明细'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
