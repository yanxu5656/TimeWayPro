import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';

/// 任务页日期选择器的端到端测试。
///
/// 守的是 v1.3.3 的改动：原先 `_selectedDate` 只参与标题渲染，卡片上那个
/// 「今日 X分钟」的数据源把 `DateTime.now()` 写死在 provider 里，所以翻日期
/// 时**标题变了、数字不变**——一个看得到但没作用的控件。
///
/// 种子数据（`test/support/app_harness.dart`）里：
/// - t1 今天有 80 分钟（→「今日 1小时20分钟」）
/// - t1 昨天有 37 分钟（→「当日 37分钟」）
/// - 前天没有记录
///
/// **37 这个值是刻意选的**：今天的三条记录是 80 / 15 / 45 分钟。最初我用
/// 45 分钟做昨天那条，结果断言 `find.text('当日 45分钟')` 在有 bug 时也
/// 会通过——因为今天 t3 恰好也是 45 分钟，数字撞车了。反证时才发现
/// （去掉重新加载后测试照样全绿）。现在用一个今天不存在的数值。
void main() {
  Future<void> openTaskTab(WidgetTester tester) async {
    await pumpSeededApp(tester);
    await switchToTab(tester, '任务');
  }

  /// 让时长重新加载那一轮跑完
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('默认选中的是今天，文案是「今日」', (tester) async {
    await openTaskTab(tester);

    expect(find.text('今日 1小时20分钟'), findsOneWidget);
    expect(find.textContaining('当日'), findsNothing);
  });

  testWidgets('翻到昨天：文案变「当日」，数字变成昨天那天的', (tester) async {
    await openTaskTab(tester);

    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await settle(tester);

    expect(
      find.text('当日 37分钟'),
      findsOneWidget,
      reason: '数字应变成昨天那条记录（37 分钟），而不是停在今天的 80 分钟',
    );
    // 关键的一条：今天 t1 的 80 分钟**无论带什么标签**都不该出现。
    // 只断言标签从「今日」变成「当日」是不够的——那个即使数字没更新也会变。
    expect(
      find.textContaining('1小时20分钟'),
      findsNothing,
      reason: '今天的数字还在页面上，说明翻日期只换了标签、没换数据',
    );
  });

  testWidgets('翻回今天：文案回到「今日」，数字回到今天的', (tester) async {
    await openTaskTab(tester);

    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await settle(tester);
    expect(find.text('当日 37分钟'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await settle(tester);

    expect(find.text('今日 1小时20分钟'), findsOneWidget);
    expect(find.textContaining('当日'), findsNothing);
  });

  testWidgets('列表内容不随日期变化（本次刻意不改列表语义）', (tester) async {
    // 用户明确选了「只改数字，不动列表」：任何日期都列出完整任务列表。
    // 这条守住它——翻到没有记录的日子，任务也一条都不能少。
    await openTaskTab(tester);

    const List<String> titles = <String>['写周报', '冥想', '读书'];
    for (final String title in titles) {
      expect(find.text(title), findsOneWidget, reason: '今天应显示「$title」');
    }

    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await settle(tester);

    for (final String title in titles) {
      expect(
        find.text(title),
        findsOneWidget,
        reason: '翻到昨天后「$title」不该消失——列表内容与日期无关',
      );
    }
  });
}
