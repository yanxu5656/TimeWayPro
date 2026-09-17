import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_way_pro/core/ui/glass.dart';

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: child), debugShowCheckedModeBanner: false);

double _opacityOf(WidgetTester tester, int index) {
  final FadeTransition fade = tester.widget<FadeTransition>(
    find
        .descendant(
          of: find.byType(StaggeredEntrance).at(index),
          matching: find.byType(FadeTransition),
        )
        .first,
  );
  return fade.opacity.value;
}

void main() {
  setUp(UiEffects.resetForTesting);

  testWidgets('首项入场：起始淡入中，结束为完全不透明', (tester) async {
    await tester.pumpWidget(
      _host(
        StaggerScope(
          child: Column(
            children: <Widget>[
              StaggeredEntrance(index: 0, child: const SizedBox(height: 20)),
            ],
          ),
        ),
      ),
    );

    await tester.pump(); // 启动 ticker
    expect(_opacityOf(tester, 0), lessThan(1.0));

    await tester.pump(const Duration(milliseconds: 700));
    expect(_opacityOf(tester, 0), moreOrLessEquals(1.0, epsilon: 0.001));
  });

  testWidgets('index >= maxItems 的项直接返回 child，不产生动画对象', (tester) async {
    await tester.pumpWidget(
      _host(
        StaggerScope(
          maxItems: 8,
          child: Column(
            children: <Widget>[
              StaggeredEntrance(index: 0, child: const SizedBox(height: 10)),
              StaggeredEntrance(index: 20, child: const SizedBox(height: 10)),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    // 第 21 项不应该被包 FadeTransition
    expect(
      find.descendant(
        of: find.byType(StaggeredEntrance).at(1),
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
    );
  });

  testWidgets('错峰顺序：后面的项起始透明度不高于前面的项', (tester) async {
    await tester.pumpWidget(
      _host(
        StaggerScope(
          child: Column(
            children: <Widget>[
              for (int i = 0; i < 4; i++)
                StaggeredEntrance(index: i, child: const SizedBox(height: 10)),
            ],
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final first = _opacityOf(tester, 0);
    final last = _opacityOf(tester, 3);
    expect(first, greaterThanOrEqualTo(last));
  });

  testWidgets('UiEffects 关掉 stagger 时全部直接显示', (tester) async {
    UiEffects.resetForTesting();
    UiEffects.tier.value = UiEffectTier.minimal;

    await tester.pumpWidget(
      _host(
        StaggerScope(
          child: Column(
            children: <Widget>[
              StaggeredEntrance(index: 0, child: const SizedBox(height: 10)),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.descendant(
        of: find.byType(StaggeredEntrance),
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
    );
    addTearDown(UiEffects.resetForTesting);
  });

  testWidgets('不在 StaggerScope 之下时安全降级为直接渲染', (tester) async {
    await tester.pumpWidget(
      _host(const StaggeredEntrance(index: 0, child: Text('孤立'))),
    );

    expect(find.text('孤立'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(StaggeredEntrance),
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
    );
  });

  group('TabVisibility 播放时机', () {
    testWidgets('slotIndex 与当前 Tab 不符时不播放（避免被 IndexedStack 偷偷播完）', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          TabVisibility(
            index: 0,
            child: StaggerScope(
              slotIndex: 2, // 本页是第 3 个 Tab，当前在第 1 个
              child: Column(
                children: <Widget>[
                  StaggeredEntrance(
                    index: 0,
                    child: const SizedBox(height: 10),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 700));

      // 一次都没开始，透明度仍是 0
      expect(_opacityOf(tester, 0), moreOrLessEquals(0.0, epsilon: 0.001));
    });

    testWidgets('slotIndex 与当前 Tab 相符时正常播放', (tester) async {
      await tester.pumpWidget(
        _host(
          TabVisibility(
            index: 1,
            child: StaggerScope(
              slotIndex: 1,
              child: Column(
                children: <Widget>[
                  StaggeredEntrance(
                    index: 0,
                    child: const SizedBox(height: 10),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      expect(_opacityOf(tester, 0), moreOrLessEquals(1.0, epsilon: 0.001));
    });

    testWidgets('slotIndex 为 -1（独立路由）时立即播放', (tester) async {
      await tester.pumpWidget(
        _host(
          StaggerScope(
            slotIndex: -1,
            child: Column(
              children: <Widget>[
                StaggeredEntrance(index: 0, child: const SizedBox(height: 10)),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      expect(_opacityOf(tester, 0), moreOrLessEquals(1.0, epsilon: 0.001));
    });
  });
}
