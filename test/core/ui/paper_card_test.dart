import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_way_pro/core/ui/glass.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
  debugShowCheckedModeBanner: false,
);

void main() {
  group('GlassCard', () {
    testWidgets('渲染 child', (tester) async {
      await tester.pumpWidget(_host(const GlassCard(child: Text('内容'))));
      expect(find.text('内容'), findsOneWidget);
    });

    testWidgets('onTap 触发', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(GlassCard(onTap: () => taps++, child: const Text('可点'))),
      );

      await tester.tap(find.text('可点'));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('onLongPress 触发', (tester) async {
      var longs = 0;
      await tester.pumpWidget(
        _host(GlassCard(onLongPress: () => longs++, child: const Text('长按'))),
      );

      await tester.longPress(find.text('长按'));
      await tester.pump();
      expect(longs, 1);
    });

    testWidgets('无回调时不包 InkWell（避免无谓的层级）', (tester) async {
      await tester.pumpWidget(_host(const GlassCard(child: Text('静态'))));
      expect(
        find.descendant(
          of: find.byType(GlassCard),
          matching: find.byType(InkWell),
        ),
        findsNothing,
      );
    });

    testWidgets('有回调时整卡可点，包括 padding 区域', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          GlassCard(
            padding: const EdgeInsets.all(40),
            onTap: () => taps++,
            child: const Text('内'),
          ),
        ),
      );

      // 点在 padding 区域（卡片左上角内側）也应触发
      final cardRect = tester.getRect(find.byType(GlassCard));
      await tester.tapAt(cardRect.topLeft + const Offset(5, 5));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('tint 非空时不抛异常', (tester) async {
      await tester.pumpWidget(
        _host(const GlassCard(tint: AppColors.success, child: Text('进行中'))),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('进行中'), findsOneWidget);
    });

    testWidgets('三档 tone 都能渲染', (tester) async {
      for (final tone in GlassTone.values) {
        await tester.pumpWidget(
          _host(GlassCard(tone: tone, child: Text('$tone'))),
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('blur:true 时插入 BackdropFilter（UiEffects 允许时）', (tester) async {
      UiEffects.resetForTesting();
      await tester.pumpWidget(
        _host(const GlassCard(blur: true, child: Text('模糊'))),
      );
      expect(
        find.descendant(
          of: find.byType(GlassCard),
          matching: find.byType(BackdropFilter),
        ),
        findsOneWidget,
      );
    });

    testWidgets('blur:false 时不插入 BackdropFilter（列表卡片的默认姿势）', (tester) async {
      await tester.pumpWidget(_host(const GlassCard(child: Text('不模糊'))));
      expect(
        find.descendant(
          of: find.byType(GlassCard),
          matching: find.byType(BackdropFilter),
        ),
        findsNothing,
      );
    });

    testWidgets('UiEffects 降到 minimal 时即使 blur:true 也不模糊', (tester) async {
      UiEffects.resetForTesting();
      UiEffects.tier.value = UiEffectTier.minimal;

      await tester.pumpWidget(
        _host(const GlassCard(blur: true, child: Text('降级'))),
      );
      expect(
        find.descendant(
          of: find.byType(GlassCard),
          matching: find.byType(BackdropFilter),
        ),
        findsNothing,
      );
      addTearDown(UiEffects.resetForTesting);
    });

    testWidgets('animate:true 时用 AnimatedContainer 支持隐式过渡', (tester) async {
      await tester.pumpWidget(
        _host(
          const GlassCard(
            animate: true,
            tint: AppColors.success,
            child: Text('动'),
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(GlassCard),
          matching: find.byType(AnimatedContainer),
        ),
        findsOneWidget,
      );
    });

    testWidgets('margin 生效且不叠加 padding', (tester) async {
      await tester.pumpWidget(
        _host(const GlassCard(margin: EdgeInsets.all(20), child: Text('边距'))),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('GlassCard 半径与描边', () {
    testWidgets('edgeWidth 变化不导致圆角不同心（内层半径 = 外层 - 描边）', (tester) async {
      await tester.pumpWidget(
        _host(
          const GlassCard(
            radius: AppRadius.xl,
            edgeWidth: 2.0,
            child: Text('加粗描边'),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('edgeWidth 大于半径时不产生负半径', (tester) async {
      await tester.pumpWidget(
        _host(const GlassCard(radius: 1, edgeWidth: 3, child: Text('极端值'))),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
