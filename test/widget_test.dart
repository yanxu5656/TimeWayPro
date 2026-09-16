import 'package:flutter_test/flutter_test.dart';
import 'package:time_way_pro/app/app.dart';

void main() {
  testWidgets('App should render', (WidgetTester tester) async {
    await tester.pumpWidget(const TimeWayProApp());

    // 注意：MainScreen 用 IndexedStack，它把每个子项包在
    // Visibility(visible: i == index) 里，且 _IndexedStackElement
    // 的 debugVisitOnstageChildren 只访问当前选中索引的子项。
    // 因此默认 skipOffstage: true 的 finder 只能看到当前 Tab 的内容。
    // 初始选中索引 0 = 每日待办。
    expect(find.text('每日待办'), findsOneWidget);

    // 任务页在索引 1，此时处于 offstage，不应被找到。
    expect(find.text('时途'), findsNothing);
  });

  testWidgets('切换到任务 Tab 后应渲染任务页', (WidgetTester tester) async {
    await tester.pumpWidget(const TimeWayProApp());

    await tester.tap(find.text('任务'));
    await tester.pump();

    // 切到索引 1 后，任务页标题才进入 onstage
    expect(find.text('时途'), findsOneWidget);
  });
}