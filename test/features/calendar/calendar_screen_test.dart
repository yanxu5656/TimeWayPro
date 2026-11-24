import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:time_way_pro/features/calendar/providers/calendar_provider.dart';

import '../../support/app_harness.dart';

/// 月历页的端到端测试。
///
/// 种子数据（`test/support/app_harness.dart`）里：
/// - 今天 2 条标注（c1 考试 / c2 抢票）
/// - 本月 20 号 1 条（c3 交房租；今天恰为 20 号时并入今天）
void main() {
  final now = DateTime.now();
  final monthKey =
      '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}';
  final today = '$monthKey-${now.day.toString().padLeft(2, '0')}';

  Future<void> openCalendarTab(WidgetTester tester) async {
    await pumpSeededApp(tester);
    await switchToTab(tester, '月历');
  }

  CalendarProvider providerOf(WidgetTester tester) =>
      Provider.of<CalendarProvider>(
        tester.element(find.text('MONTH BOARD')),
        listen: false,
      );

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  // 首位运行：直接 pumpSeededApp 走真实 IO，避开写队列尾巴（同每周页）
  testWidgets('窄屏（320dp）下月网格与单行导航不溢出', (tester) async {
    await pumpSeededApp(tester, size: const Size(320, 640));
    await switchToTab(tester, '月历');

    expect(tester.takeException(), isNull);
    expect(find.byKey(Key('cal_day_$today')), findsOneWidget);
  });

  testWidgets('默认当前月：今天高亮、格子预览第一条 + 余量', (tester) async {
    await openCalendarTab(tester);
    final provider = providerOf(tester);

    expect(find.text('${now.year} 年 ${now.month} 月'), findsOneWidget);
    expect(find.text('回今天'), findsNothing);

    // 格子里预览当天第一条，余量计数随种子条数变化（今天=20 号时并入 c3）
    final dayCount = provider.notesForDay(today).length;
    expect(
      find.descendant(
        of: find.byKey(Key('cal_day_$today')),
        matching: find.text('9-11 高数期末考试'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(Key('cal_day_$today')),
        matching: find.text('+${dayCount - 1}'),
      ),
      findsOneWidget,
    );
    expect(find.text('本月标注'), findsOneWidget);
    expect(find.text('${provider.notes.length} 条'), findsOneWidget);
  });

  testWidgets('翻月与回今天：标注按月隔离', (tester) async {
    await openCalendarTab(tester);

    // 月行箭头在树里先于议程行的 chevron，取第一个
    await tester.tap(find.byIcon(Icons.chevron_right_rounded).first);
    await settle(tester);

    final next = DateTime(now.year, now.month + 1);
    expect(find.text('${next.year} 年 ${next.month} 月'), findsOneWidget);
    expect(find.text('这个月还没有标注'), findsOneWidget);
    expect(find.text('回今天'), findsOneWidget);
    expect(find.text('9-11 高数期末考试'), findsNothing);

    await tapAndFlush(tester, find.text('回今天'));
    expect(find.text('${now.year} 年 ${now.month} 月'), findsOneWidget);
    expect(find.text('9-11 高数期末考试'), findsWidgets);
  });

  testWidgets('翻月跨年正确（1 月往前是上一年 12 月）', (tester) async {
    await openCalendarTab(tester);
    final provider = providerOf(tester);

    // 从当前月一路翻到上一年 12 月
    for (var i = 0; i < now.month; i++) {
      provider.previousMonth();
      await tester.pump();
    }
    expect(provider.selectedMonth.year, now.year - 1);
    expect(provider.selectedMonth.month, 12);

    provider.goToToday();
    await tester.pump();
    expect(provider.selectedMonth.month, now.month);
  });

  testWidgets('点今天开 sheet 添加标注：留在面板里且网格立即更新', (tester) async {
    await openCalendarTab(tester);
    final provider = providerOf(tester);
    final before = provider.notesForDay(today).length;

    await tester.tap(find.byKey(Key('cal_day_$today')));
    await openSheet(tester);
    expect(find.text('添加标注'), findsOneWidget);
    expect(find.text('这一天还没有标注'), findsNothing);

    await tester.enterText(find.byType(TextField), '下午取快递');
    // 泵一帧让 CTA 从禁用态重建出来，否则 tap 落在旧树的禁用按钮上
    await tester.pump();
    await tapAndFlush(tester, find.text('添加标注'));

    expect(find.text('添加标注'), findsOneWidget, reason: '添加后面板不关，便于连续记');
    expect(find.text('下午取快递'), findsOneWidget);
    expect(provider.notesForDay(today), hasLength(before + 1));
    expect(
      find.descendant(
        of: find.byKey(Key('cal_day_$today')),
        matching: find.text('+$before'),
      ),
      findsOneWidget,
      reason: '网格余量计数应立即 +1',
    );

    // 点 sheet 之外的遮罩关闭（Material bottom sheet 没有 Cupertino 返回键）
    await tester.tapAt(const Offset(195, 60));
    await tester.pumpAndSettle();
    expect(find.text('${provider.notes.length} 条'), findsOneWidget);
  });

  testWidgets('sheet 里点条目进入编辑，保存修改生效', (tester) async {
    await openCalendarTab(tester);

    await tester.tap(find.byKey(Key('cal_day_$today')));
    await openSheet(tester);

    await tester.tap(find.text('抢回家的车票').last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('保存修改'), findsOneWidget);
    expect(find.text('取消编辑'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '抢回家的车票',
    );

    await tester.enterText(find.byType(TextField), '抢回家的车票（候补）');
    await tester.pump();
    await tapAndFlush(tester, find.text('保存修改'));

    expect(find.text('抢回家的车票（候补）'), findsOneWidget);
    expect(find.text('抢回家的车票'), findsNothing);
    expect(find.text('添加标注'), findsOneWidget, reason: '保存后回到添加态');
  });

  testWidgets('sheet 里删除单条标注', (tester) async {
    await openCalendarTab(tester);
    final provider = providerOf(tester);
    final before = provider.notesForDay(today).length;

    await tester.tap(find.byKey(Key('cal_day_$today')));
    await openSheet(tester);

    await tapAndFlush(tester, find.byTooltip('删除标注').first);

    expect(provider.notesForDay(today), hasLength(before - 1));
    expect(find.text('9-11 高数期末考试'), findsNothing, reason: '首条已从面板删除');
  });
}
