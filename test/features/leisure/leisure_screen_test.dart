import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:time_way_pro/core/ui/paper.dart';
import 'package:time_way_pro/features/leisure/providers/leisure_provider.dart';

import '../../support/app_harness.dart';

/// 闲时清单页的端到端测试。
///
/// 种子数据（`test/support/app_harness.dart`）里：
/// - l1 打一款新游戏（带备注，没试过）
/// - l2 学做提拉米苏（没试过）
/// - l3 重看一遍《千与千寻》（试过了）
void main() {
  Future<void> openLeisureTab(WidgetTester tester) async {
    await pumpSeededApp(tester);
    await switchToTab(tester, '闲时');
  }

  LeisureProvider providerOf(WidgetTester tester) =>
      Provider.of<LeisureProvider>(
        tester.element(find.text('IDLE HOURS')),
        listen: false,
      );

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  // 首位运行：直接 pumpSeededApp 走真实 IO，避开写队列尾巴（同每周页）
  testWidgets('窄屏（320dp）下页面与两行导航不溢出', (tester) async {
    await pumpSeededApp(tester, size: const Size(320, 640));
    await switchToTab(tester, '闲时');

    expect(tester.takeException(), isNull);
    expect(find.text('打一款新游戏'), findsOneWidget);
    expect(find.text('记一件'), findsOneWidget);
  });

  testWidgets('默认显示全部，试过的沉底并带标记', (tester) async {
    await openLeisureTab(tester);

    expect(find.text('打一款新游戏'), findsOneWidget);
    expect(find.text('学做提拉米苏'), findsOneWidget);
    expect(find.text('重看一遍《千与千寻》'), findsOneWidget);
    expect(find.text('等周末打折再入手'), findsOneWidget);
    expect(find.text('试过了'), findsNWidgets(2), reason: '筛选 chip + 完成标记');
    expect(providerOf(tester).totalCount, 3);
    expect(providerOf(tester).doneCount, 1);
  });

  testWidgets('三个筛选 chip 各自生效', (tester) async {
    await openLeisureTab(tester);

    await tester.tap(find.text('还没试'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('打一款新游戏'), findsOneWidget);
    expect(find.text('重看一遍《千与千寻》'), findsNothing);

    await tester.tap(find.text('试过了').first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('重看一遍《千与千寻》'), findsOneWidget);
    expect(find.text('打一款新游戏'), findsNothing);

    await tester.tap(find.text('全部'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(providerOf(tester).filteredItems, hasLength(3));
  });

  testWidgets('FAB 记一件：标题 + 备注落库并立即出现', (tester) async {
    await openLeisureTab(tester);

    await tester.tap(find.byType(PaperFab));
    await openSheet(tester);
    expect(find.text('记一件闲时想做的事'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), '去 livehouse 看演出');
    await tester.enterText(find.byType(TextField).at(1), '周五晚上那场');
    // 泵一帧让 CTA 从禁用态重建出来，否则 tap 落在旧树的禁用按钮上
    await tester.pump();
    await tapAndFlush(tester, find.text('添加'));

    expect(find.text('去 livehouse 看演出'), findsOneWidget);
    expect(find.text('周五晚上那场'), findsOneWidget);
    expect(providerOf(tester).totalCount, 4);
  });

  testWidgets('勾选后标记试过了并沉底', (tester) async {
    await openLeisureTab(tester);

    await tapAndFlush(tester, find.byType(InkCheckCircle).at(0));

    expect(providerOf(tester).doneCount, 2);
    final items = providerOf(tester).items;
    expect(items.first.isDone, isFalse, reason: '没试过的仍在前面');
    expect(items.last.isDone, isTrue, reason: '试过的整组沉底');
    expect(
      items.firstWhere((i) => i.title == '打一款新游戏').isDone,
      isTrue,
    );
  });

  testWidgets('点卡片编辑：改标题、清空备注都生效', (tester) async {
    await openLeisureTab(tester);

    await tester.tap(find.text('打一款新游戏'));
    await openSheet(tester);
    expect(find.text('编辑闲时条目'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), '打两款新游戏');
    await tester.enterText(find.byType(TextField).at(1), '');
    await tester.pump();
    await tapAndFlush(tester, find.text('保存'));

    expect(find.text('打两款新游戏'), findsOneWidget);
    expect(find.text('等周末打折再入手'), findsNothing, reason: '备注应被清空');
  });

  testWidgets('左滑删除走确认对话框', (tester) async {
    await openLeisureTab(tester);

    await tester.drag(find.text('学做提拉米苏'), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text('删除闲时条目'), findsOneWidget);

    await tapAndFlush(tester, find.text('删除'));

    expect(find.text('学做提拉米苏'), findsNothing);
    expect(providerOf(tester).totalCount, 2);
  });
}