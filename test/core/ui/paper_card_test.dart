import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_way_pro/core/ui/paper.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
  debugShowCheckedModeBanner: false,
);

void main() {
  group('PaperCard', () {
    testWidgets('渲染 child', (tester) async {
      await tester.pumpWidget(_host(const PaperCard(child: Text('内容'))));
      expect(find.text('内容'), findsOneWidget);
    });

    testWidgets('onTap 触发', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(PaperCard(onTap: () => taps++, child: const Text('可点'))),
      );

      await tester.tap(find.text('可点'));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('onLongPress 触发', (tester) async {
      var longs = 0;
      await tester.pumpWidget(
        _host(
          PaperCard(onLongPress: () => longs++, child: const Text('长按')),
        ),
      );

      await tester.longPress(find.text('长按'));
      await tester.pump();
      expect(longs, 1);
    });

    testWidgets('无回调时不包 InkWell（避免无谓的层级）', (tester) async {
      await tester.pumpWidget(_host(const PaperCard(child: Text('静态'))));
      expect(
        find.descendant(
          of: find.byType(PaperCard),
          matching: find.byType(InkWell),
        ),
        findsNothing,
      );
    });

    testWidgets('有回调时整卡可点，包括 padding 区域', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          PaperCard(
            padding: const EdgeInsets.all(40),
            onTap: () => taps++,
            child: const Text('内'),
          ),
        ),
      );

      // 点在 padding 区域（卡片左上角内側）也应触发
      final cardRect = tester.getRect(find.byType(PaperCard));
      await tester.tapAt(cardRect.topLeft + const Offset(5, 5));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('tint 非空时不抛异常', (tester) async {
      await tester.pumpWidget(
        _host(
          const PaperCard(tint: AppColors.success, child: Text('进行中')),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('进行中'), findsOneWidget);
    });

    testWidgets('四档 tone 都能渲染', (tester) async {
      for (final tone in PaperTone.values) {
        await tester.pumpWidget(
          _host(PaperCard(tone: tone, child: Text('$tone'))),
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('任何档位都不用 BackdropFilter（纸面体系的硬约束）', (tester) async {
      for (final tone in PaperTone.values) {
        await tester.pumpWidget(
          _host(
            PaperCard(
              tone: tone,
              tint: tone == PaperTone.raised ? AppColors.success : null,
              child: Text('$tone'),
            ),
          ),
        );
        expect(
          find.byType(BackdropFilter),
          findsNothing,
          reason: '$tone 档引入了模糊——静白志体系不允许',
        );
      }
    });

    testWidgets('animate:true 时用 AnimatedContainer 支持隐式过渡', (tester) async {
      await tester.pumpWidget(
        _host(
          const PaperCard(
            animate: true,
            tint: AppColors.success,
            child: Text('动'),
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(PaperCard),
          matching: find.byType(AnimatedContainer),
        ),
        findsOneWidget,
      );
    });

    testWidgets('margin 生效且不叠加 padding', (tester) async {
      await tester.pumpWidget(
        _host(
          const PaperCard(margin: EdgeInsets.all(20), child: Text('边距')),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('PaperCard 表面档位语义', () {
    testWidgets('row 档只画下缘发丝线（相邻行不会出现双线）', (tester) async {
      await tester.pumpWidget(
        _host(const PaperCard(tone: PaperTone.row, child: Text('行'))),
      );
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(PaperCard),
          matching: find.byType(Container),
        ).first,
      );
      final decoration = container.decoration! as BoxDecoration;
      final border = decoration.border as Border;

      expect(border.bottom.color, AppColors.divider);
      expect(border.bottom.width, 1);
      expect(border.top, BorderSide.none);
    });

    testWidgets('row 档带 tint 时左缘有着重线', (tester) async {
      await tester.pumpWidget(
        _host(
          const PaperCard(
            tone: PaperTone.row,
            tint: AppColors.success,
            child: Text('进行中'),
          ),
        ),
      );
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(PaperCard),
          matching: find.byType(Container),
        ).first,
      );
      final border = (container.decoration! as BoxDecoration).border as Border;
      expect(border.left.color, AppColors.success);
      expect(border.left.width, 2.5);
    });

    testWidgets('raised 档是白底 + 圆角（真正浮起的表面）', (tester) async {
      await tester.pumpWidget(
        _host(
          const PaperCard(tone: PaperTone.raised, child: Text('浮起')),
        ),
      );
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(PaperCard),
          matching: find.byType(Container),
        ).first,
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, AppColors.surface);
      expect(decoration.borderRadius, AppRadius.brLg);
    });
  });
}
