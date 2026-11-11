import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:time_way_pro/core/utils/week.dart';
import 'package:time_way_pro/features/weekly/data/models/weekly_goal.dart';
import 'package:time_way_pro/features/weekly/data/repositories/weekly_goal_repository.dart';
import 'package:time_way_pro/features/weekly/providers/weekly_provider.dart';
import 'package:time_way_pro/shared/database/database_helper.dart';

import '../../support/app_harness.dart';

/// 每周目标的拖拽排序。
///
/// 种子数据本周 3 条：w0 / w1 / w2，sort_order 依次 0 / 1 / 2。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final String thisWeek = weekKeyOf(DateTime.now());

  group('WeeklyProvider.reorderGoals', () {
    late WeeklyProvider provider;

    setUp(() async {
      installPathProviderMock();
      await DatabaseHelper().importAll(seedData());
      provider = WeeklyProvider();
      await provider.loadGoals();
    });

    test('往下拖：首条移到末位，其余依次前移', () async {
      await provider.reorderGoals(0, 2);

      expect(
        provider.goals.map((WeeklyGoal g) => g.id).toList(),
        orderedEquals(<String>['w1', 'w2', 'w0']),
      );
    });

    test('往上拖：末条移到首位', () async {
      await provider.reorderGoals(2, 0);

      expect(
        provider.goals.map((WeeklyGoal g) => g.id).toList(),
        orderedEquals(<String>['w2', 'w0', 'w1']),
      );
    });

    test('sortOrder 重编号成连续的 0..n-1', () async {
      await provider.reorderGoals(0, 2);

      expect(
        provider.goals.map((WeeklyGoal g) => g.sortOrder).toList(),
        orderedEquals(<int>[0, 1, 2]),
        reason: '不连续的话队尾追加取的 max+1 会与现存值撞车',
      );
    });

    test('原地不动是无操作', () async {
      await provider.reorderGoals(1, 1);

      expect(
        provider.goals.map((WeeklyGoal g) => g.id).toList(),
        orderedEquals(<String>['w0', 'w1', 'w2']),
      );
    });

    test('新顺序落盘，重新读库仍是新顺序', () async {
      await provider.reorderGoals(0, 2);

      final List<WeeklyGoal> persisted = await WeeklyGoalRepository().getByWeek(
        thisWeek,
      );
      expect(
        persisted.map((WeeklyGoal g) => g.id).toList(),
        orderedEquals(<String>['w1', 'w2', 'w0']),
      );
    });

    test('排序不动其它周的目标', () async {
      await provider.reorderGoals(0, 2);

      final List<Map<String, dynamic>> all = await DatabaseHelper().query(
        'weekly_goals',
      );
      final Map<String, dynamic> old = all.firstWhere(
        (Map<String, dynamic> m) => m['id'] == 'w-old',
      );
      expect(old['week_key'], isNot(thisWeek));
      expect(old['sort_order'], 0);
    });

    test('排序不触发 isLoading（否则列表会在拖完瞬间变成加载圈）', () async {
      final Future<void> done = provider.reorderGoals(0, 2);
      expect(provider.isLoading, isFalse);
      await done;
      expect(provider.isLoading, isFalse);
    });
  });

  group('每周页的拖拽把手', () {
    Future<void> openWeekly(WidgetTester tester) async {
      await pumpSeededApp(tester);
      await switchToTab(tester, '每周');
    }

    WeeklyProvider providerOf(WidgetTester tester) =>
        Provider.of<WeeklyProvider>(
          tester.element(find.text('每周目标')),
          listen: false,
        );

    testWidgets('每条目标都有自己的把手，分区标题没有', (tester) async {
      await openWeekly(tester);

      expect(find.byIcon(Icons.drag_handle_rounded), findsNWidgets(3));
      expect(find.byType(ReorderableDragStartListener), findsNWidgets(3));
    });

    testWidgets('按住把手往下拖，顺序真的变了', (tester) async {
      await openWeekly(tester);

      final Finder firstHandle = find.byIcon(Icons.drag_handle_rounded).first;
      final double rowHeight = tester
          .getSize(find.byIcon(Icons.drag_handle_rounded).first)
          .height;

      // 拖过两行的高度：首条应落到末位
      await tester.runAsync(() async {
        await tester.drag(firstHandle, Offset(0, rowHeight * 8));
        await Future<void>.delayed(const Duration(milliseconds: 400));
      });
      await tester.pumpAndSettle();

      expect(
        providerOf(tester).goals.map((WeeklyGoal g) => g.id).toList(),
        orderedEquals(<String>['w1', 'w2', 'w0']),
        reason: '拖动把手应把首条挪到队尾',
      );
    });

    testWidgets('把手不抢左滑删除的手势', (tester) async {
      await openWeekly(tester);

      await tester.drag(find.text('本周目标 2'), const Offset(-400, 0));
      await tester.pumpAndSettle();

      expect(find.text('删除目标'), findsOneWidget);
    });
  });
}
