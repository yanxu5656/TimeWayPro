import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:time_way_pro/core/ui/glass.dart';
import 'package:time_way_pro/features/daily/providers/daily_provider.dart';

import '../../support/app_harness.dart';

/// 「添加待办」弹窗的回归测试。
///
/// ## 为什么要单独测这个弹窗
///
/// v1.3.1 上有一个只会在 **release 构建**里显形的 bug：`GlassChip` 把
/// `Expanded` 包在了 `GestureDetector` 里面，而 `Expanded` 是
/// `ParentDataWidget`、**必须是 Flex 的直接子节点**。这个误用在 debug 下
/// 只抛异常，在 release 下则会把整个子树换成 `ErrorWidget`——也就是一块
/// 纯灰色方块，正好盖住「时间段」那一行，用户报的是「整个时间段被很大的
/// 灰色方块挡住了，而且也创建不了」。
///
/// 之前的所有测试与截图都只覆盖 5 个 Tab 页，从来没打开过这个弹窗，
/// 所以它一直没被发现。这个文件专门守住它。
void main() {
  Future<void> openAddSheet(WidgetTester tester) async {
    await pumpSeededApp(tester);
    await tester.tap(find.byType(GlassFab));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('打开时不抛异常（ParentDataWidget 误用会在这里暴露）', (tester) async {
    await openAddSheet(tester);

    expect(find.byType(GlassSheet), findsOneWidget);
    expect(
      tester.takeException(),
      isNull,
      reason: '打开弹窗不该抛任何异常；release 构建下这类异常会变成灰色方块',
    );
  });

  testWidgets('三个时段 chip 等宽且铺满一行', (tester) async {
    // 守的就是上面那个 bug：误用状态下每个 chip 只有 30px 宽（宽度塌成
    // 内容宽度），修好后应该各占约 106px 把一行铺满。
    await openAddSheet(tester);

    final List<Rect> rects = find
        .byType(GlassChip)
        .evaluate()
        .map((Element e) => tester.getRect(find.byWidget(e.widget)))
        .toList();

    expect(rects, hasLength(3));
    for (final Rect r in rects) {
      expect(
        r.width,
        greaterThan(90),
        reason: 'chip 宽度只有 ${r.width}，说明 Expanded 没生效',
      );
    }
    // 三者等宽
    expect(rects[0].width, moreOrLessEquals(rects[1].width, epsilon: 1));
    expect(rects[1].width, moreOrLessEquals(rects[2].width, epsilon: 1));
  });

  testWidgets('键盘弹起时布局不溢出、添加按钮仍可见', (tester) async {
    await openAddSheet(tester);

    // 标题框是 autofocus，真机上键盘会弹起来
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);

    final Rect button = tester.getRect(
      find.widgetWithText(ElevatedButton, '添加'),
    );
    final Rect screen = tester.getRect(find.byType(MaterialApp));
    expect(
      button.bottom,
      lessThanOrEqualTo(screen.bottom),
      reason: '添加按钮落到了屏幕外，用户点不到',
    );
  });

  testWidgets('输入内容后能真的创建出待办', (tester) async {
    await openAddSheet(tester);

    final DailyProvider provider = tester
        .element(find.byType(GlassFab))
        .read<DailyProvider>();
    final int before = provider.tasks.length;

    await tester.enterText(find.byType(TextField).first, '测试新增待办');
    await tester.pump();

    // 触发了写入，必须让真实文件 IO 有机会跑完，否则 insert 不返回、
    // provider 的 loadTasks 不执行，表现为"点了没反应"
    await tapAndFlush(tester, find.widgetWithText(ElevatedButton, '添加'));

    expect(find.byType(GlassSheet), findsNothing, reason: '创建后弹窗应关闭');
    expect(provider.tasks.length, before + 1, reason: '待办数量没有增加，说明创建没走通');
    expect(provider.tasks.any((t) => t.title == '测试新增待办'), isTrue);
  });

  testWidgets('标题为空时点添加不创建、也不关闭弹窗', (tester) async {
    await openAddSheet(tester);

    final DailyProvider provider = tester
        .element(find.byType(GlassFab))
        .read<DailyProvider>();
    final int before = provider.tasks.length;

    await tapAndFlush(tester, find.widgetWithText(ElevatedButton, '添加'));

    expect(provider.tasks.length, before);
    expect(find.byType(GlassSheet), findsOneWidget, reason: '不该关闭');
  });

  testWidgets('选中的时段会带进新建的待办', (tester) async {
    await openAddSheet(tester);

    final DailyProvider provider = tester
        .element(find.byType(GlassFab))
        .read<DailyProvider>();

    // 点「晚上」。必须限定在弹窗内：待办列表里也有个「晚上」分段标题，
    // 直接 find.text('晚上') 会匹配到两个而报歧义。
    await tester.tap(
      find.descendant(of: find.byType(GlassSheet), matching: find.text('晚上')),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, '晚上的事');
    await tester.pump();
    await tapAndFlush(tester, find.widgetWithText(ElevatedButton, '添加'));

    final task = provider.tasks.firstWhere((t) => t.title == '晚上的事');
    expect(task.timePeriodText, '晚上');
  });
}
