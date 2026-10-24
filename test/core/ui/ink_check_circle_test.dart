import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_way_pro/core/ui/glass.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
  debugShowCheckedModeBanner: false,
);

void main() {
  setUp(UiEffects.resetForTesting);

  testWidgets('未选中时不渲染对勾', (tester) async {
    await tester.pumpWidget(
      _host(GlassCheckCircle(isChecked: false, onTap: () {})),
    );

    expect(find.byIcon(Icons.check), findsNothing);
  });

  testWidgets('选中时渲染对勾', (tester) async {
    await tester.pumpWidget(
      _host(GlassCheckCircle(isChecked: true, onTap: () {})),
    );

    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('点击触发回调', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(GlassCheckCircle(isChecked: false, onTap: () => taps++)),
    );

    await tester.tap(find.byType(GlassCheckCircle));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('默认尺寸 28（两页统一后的值）', (tester) async {
    await tester.pumpWidget(
      _host(GlassCheckCircle(isChecked: false, onTap: () {})),
    );

    expect(tester.getSize(find.byType(AnimatedContainer)), const Size(28, 28));
  });

  testWidgets('尺寸可覆盖，对勾大小跟着缩放', (tester) async {
    await tester.pumpWidget(
      _host(GlassCheckCircle(isChecked: true, onTap: () {}, size: 40)),
    );

    expect(tester.getSize(find.byType(AnimatedContainer)), const Size(40, 40));
    // 对勾保持 size * 0.57 的比例
    final Icon icon = tester.widget<Icon>(find.byIcon(Icons.check));
    expect(icon.size, moreOrLessEquals(40 * 0.57, epsilon: 0.01));
  });

  testWidgets('选中色可覆盖', (tester) async {
    await tester.pumpWidget(
      _host(
        GlassCheckCircle(
          isChecked: true,
          onTap: () {},
          color: AppColors.primary,
        ),
      ),
    );

    final AnimatedContainer box = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    final BoxDecoration deco = box.decoration! as BoxDecoration;
    expect(deco.color, AppColors.primary);
  });

  testWidgets('默认选中色是 success 绿（与「已完成」的语义一致）', (tester) async {
    await tester.pumpWidget(
      _host(GlassCheckCircle(isChecked: true, onTap: () {})),
    );

    final AnimatedContainer box = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    final BoxDecoration deco = box.decoration! as BoxDecoration;
    expect(deco.color, AppColors.success);
  });

  testWidgets('语义上是一个 checked 状态', (tester) async {
    // 直接断言组件声明的语义属性，而不是 getSemantics + matchesSemantics——
    // 后者对 StatelessWidget 会走到路由根节点，而且要求逐项精确匹配
    // 合并后的节点树，非常脆。
    await tester.pumpWidget(
      _host(
        GlassCheckCircle(isChecked: true, onTap: () {}, semanticLabel: '写周报'),
      ),
    );

    final Semantics sem = tester.widget<Semantics>(
      find
          .descendant(
            of: find.byType(GlassCheckCircle),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(sem.properties.checked, isTrue, reason: '应声明为 checked');
    expect(sem.properties.label, '写周报');
  });

  testWidgets('未选中时语义上是 unchecked', (tester) async {
    await tester.pumpWidget(
      _host(GlassCheckCircle(isChecked: false, onTap: () {})),
    );

    final Semantics sem = tester.widget<Semantics>(
      find
          .descendant(
            of: find.byType(GlassCheckCircle),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(sem.properties.checked, isFalse);
  });
}
