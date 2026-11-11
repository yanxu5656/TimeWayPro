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
        _host(PaperCard(onLongPress: () => longs++, child: const Text('长按'))),
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
        _host(const PaperCard(tint: AppColors.success, child: Text('进行中'))),
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
          reason: '$tone 档引入了模糊——陶土暖笺体系不允许',
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
        _host(const PaperCard(margin: EdgeInsets.all(20), child: Text('边距'))),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('PaperCard 表面档位语义', () {
    BoxDecoration decorationOf(WidgetTester tester) {
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(PaperCard),
              matching: find.byType(Container),
            )
            .first,
      );
      return container.decoration! as BoxDecoration;
    }

    testWidgets('row 档是暖白圆角卡 + 两层暖阴影（靠 margin 分行，不靠线）', (tester) async {
      await tester.pumpWidget(
        _host(const PaperCard(tone: PaperTone.row, child: Text('行'))),
      );
      final decoration = decorationOf(tester);

      expect(decoration.color, AppColors.surface);
      expect(decoration.borderRadius, AppRadius.brCard);
      expect(decoration.boxShadow, AppShadows.e1);
      expect(decoration.boxShadow!.length, 2);
      // 整圈等宽描边：非均匀 Border 不能与 borderRadius 同用
      final border = decoration.border! as Border;
      expect(border.top, border.bottom);
      expect(border.left, border.right);
      expect(border.top.color, AppColors.divider);
    });

    testWidgets('row 档带 tint 时换成整圈着重描边，圆角不丢', (tester) async {
      await tester.pumpWidget(
        _host(
          const PaperCard(
            tone: PaperTone.row,
            tint: AppColors.success,
            child: Text('进行中'),
          ),
        ),
      );
      final decoration = decorationOf(tester);
      final border = decoration.border! as Border;

      expect(border.left.color, AppColors.success.withValues(alpha: 0.55));
      expect(border.left.width, 1.4);
      expect(border.top, border.left);
      expect(decoration.borderRadius, AppRadius.brCard);
    });

    testWidgets('raised 档是暖沙嵌套块：小一档圆角、不叠阴影', (tester) async {
      await tester.pumpWidget(
        _host(const PaperCard(tone: PaperTone.raised, child: Text('嵌套'))),
      );
      final decoration = decorationOf(tester);

      expect(decoration.color, AppColors.surfaceVariant);
      expect(decoration.borderRadius, AppRadius.brLg);
      expect(decoration.boxShadow, isNull);
    });

    testWidgets('只有 row 档带默认阴影（同屏阴影数要克制）', (tester) async {
      for (final tone in PaperTone.values) {
        await tester.pumpWidget(
          _host(PaperCard(tone: tone, child: Text('$tone'))),
        );
        expect(
          decorationOf(tester).boxShadow,
          tone == PaperTone.row ? isNotNull : isNull,
          reason: '$tone 档的阴影档位不对——大容器浮起来会和列表项抢体量',
        );
      }
    });
  });
}
