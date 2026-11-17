import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_way_pro/core/ui/paper.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
  debugShowCheckedModeBanner: false,
);

void main() {
  setUp(UiEffects.resetForTesting);

  testWidgets('未选中时不渲染对勾', (tester) async {
    await tester.pumpWidget(
      _host(InkCheckCircle(isChecked: false, onTap: () {})),
    );

    expect(find.byIcon(Icons.check), findsNothing);
  });

  testWidgets('选中时渲染对勾', (tester) async {
    await tester.pumpWidget(
      _host(InkCheckCircle(isChecked: true, onTap: () {})),
    );

    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('点击触发回调', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(InkCheckCircle(isChecked: false, onTap: () => taps++)),
    );

    await tester.tap(find.byType(InkCheckCircle));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('默认尺寸 28（两页统一后的值）', (tester) async {
    await tester.pumpWidget(
      _host(InkCheckCircle(isChecked: false, onTap: () {})),
    );

    expect(tester.getSize(find.byType(AnimatedContainer)), const Size(28, 28));
  });

  testWidgets('尺寸可覆盖，对勾大小跟着缩放', (tester) async {
    await tester.pumpWidget(
      _host(InkCheckCircle(isChecked: true, onTap: () {}, size: 40)),
    );

    expect(tester.getSize(find.byType(AnimatedContainer)), const Size(40, 40));
    // 对勾保持 size * 0.57 的比例
    final Icon icon = tester.widget<Icon>(find.byIcon(Icons.check));
    expect(icon.size, moreOrLessEquals(40 * 0.57, epsilon: 0.01));
  });

  testWidgets('选中色可覆盖', (tester) async {
    await tester.pumpWidget(
      _host(
        InkCheckCircle(isChecked: true, onTap: () {}, color: AppColors.primary),
      ),
    );

    final AnimatedContainer box = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    final BoxDecoration deco = box.decoration! as BoxDecoration;
    expect(deco.color, AppColors.primary);
  });

  testWidgets('默认选中色是朱砂（完成是最值得用强调色的一刻）', (tester) async {
    await tester.pumpWidget(
      _host(InkCheckCircle(isChecked: true, onTap: () {})),
    );

    final AnimatedContainer box = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    final BoxDecoration deco = box.decoration! as BoxDecoration;
    expect(deco.color, AppColors.primary);
  });

  testWidgets('语义上是一个 checked 状态', (tester) async {
    // 直接断言组件声明的语义属性，而不是 getSemantics + matchesSemantics——
    // 后者对 StatelessWidget 会走到路由根节点，而且要求逐项精确匹配
    // 合并后的节点树，非常脆。
    await tester.pumpWidget(
      _host(
        InkCheckCircle(isChecked: true, onTap: () {}, semanticLabel: '写周报'),
      ),
    );

    final Semantics sem = tester.widget<Semantics>(
      find
          .descendant(
            of: find.byType(InkCheckCircle),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(sem.properties.checked, isTrue, reason: '应声明为 checked');
    expect(sem.properties.label, '写周报');
  });

  testWidgets('未选中时语义上是 unchecked', (tester) async {
    await tester.pumpWidget(
      _host(InkCheckCircle(isChecked: false, onTap: () {})),
    );

    final Semantics sem = tester.widget<Semantics>(
      find
          .descendant(
            of: find.byType(InkCheckCircle),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(sem.properties.checked, isFalse);
  });

  // 涟漪外层包着一个显式 Opacity（圆钮本体与对勾都没有），
  // 用它定位涟漪。不能用 Container：AnimatedContainer 内部也构建
  // 一个 Container，会永远匹配上。
  Finder ring() => find.descendant(
    of: find.byType(InkCheckCircle),
    matching: find.byType(Opacity),
  );

  testWidgets('false→true 切换时荡开涟漪，随后自行消失', (tester) async {
    await tester.pumpWidget(
      _host(InkCheckCircle(isChecked: false, onTap: () {})),
    );
    expect(ring(), findsNothing);

    await tester.pumpWidget(
      _host(InkCheckCircle(isChecked: true, onTap: () {})),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(ring(), findsOneWidget, reason: '完成瞬间应有涟漪');

    await tester.pump(const Duration(milliseconds: 400));
    expect(ring(), findsNothing, reason: '涟漪是一次性的，落定后必须移除');
  });

  testWidgets('初始就已完成时安静渲染，不放涟漪', (tester) async {
    // 种子数据 / 翻回历史日期时整页都是已完成项，
    // 若挂载也庆祝，进页面会闪成一片礼花。
    await tester.pumpWidget(
      _host(InkCheckCircle(isChecked: true, onTap: () {})),
    );
    await tester.pump();
    expect(ring(), findsNothing);
  });

  testWidgets('true→false（取消完成）不放涟漪', (tester) async {
    await tester.pumpWidget(
      _host(InkCheckCircle(isChecked: true, onTap: () {})),
    );
    await tester.pumpWidget(
      _host(InkCheckCircle(isChecked: false, onTap: () {})),
    );
    await tester.pump();
    expect(ring(), findsNothing);
  });

  testWidgets('勾选触发 mediumImpact，取消触发 selectionClick', (tester) async {
    final List<String?> haptics = <String?>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
          MethodCall call,
        ) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments as String?);
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await tester.pumpWidget(
      _host(InkCheckCircle(isChecked: false, onTap: () {})),
    );
    await tester.tap(find.byType(InkCheckCircle));
    await tester.pump();
    expect(haptics, <String>['HapticFeedbackType.mediumImpact']);

    haptics.clear();
    await tester.pumpWidget(
      _host(InkCheckCircle(isChecked: true, onTap: () {})),
    );
    await tester.tap(find.byType(InkCheckCircle));
    await tester.pump();
    expect(haptics, <String>['HapticFeedbackType.selectionClick']);
  });
}
