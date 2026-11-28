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
      weekly.goals
          .firstWhere((WeeklyGoal goal) => goal.title == '跑步三次')
          .coinReward,
      120,
    );
    expect(find.text('完成奖励 120 金币'), findsOneWidget);

    await switchToTab(tester, '商店');
    expect(find.text('奖励商店'), findsOneWidget);
    expect(find.text('商店还是空的'), findsOneWidget);
    expect(find.text('看一场电影'), findsNothing);
    await tester.tap(find.text('仓库'));
    await tester.pump();
    expect(find.text('仓库空着'), findsOneWidget);
    await tester.tap(find.text('明细'));
    await tester.pump();
    expect(find.text('还没有金币明细'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('自定义奖励可正常删除且不出现奖励不存在', (tester) async {
    await pumpSeededApp(tester);
    await switchToTab(tester, '商店');
    await tapAndFlush(tester, find.byType(PaperFab));
    await tester.enterText(find.byKey(const Key('product_title')), '测试奖励');
    await tester.enterText(find.byKey(const Key('product_price')), '20');
    await tester.ensureVisible(find.byKey(const Key('product_save')));
    await tester.pump();
    await tapAndFlush(tester, find.byKey(const Key('product_save')));
    expect(find.text('测试奖励'), findsOneWidget);

    await tester.tap(find.text('测试奖励'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.ensureVisible(find.byKey(const Key('product_delete')));
    await tester.pump();
    await tapAndFlush(tester, find.byKey(const Key('product_delete')));
    await tapAndFlush(tester, find.text('确认删除'));
    expect(find.text('测试奖励'), findsNothing);
    expect(find.text('商店还是空的'), findsOneWidget);
    expect(find.text('奖励不存在'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
