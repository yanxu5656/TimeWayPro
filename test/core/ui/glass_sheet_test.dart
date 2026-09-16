import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_way_pro/core/ui/glass.dart';

void main() {
  setUp(UiEffects.resetForTesting);

  Widget hostWithButton({
    required VoidCallback onPressed,
    bool useBlur = true,
    bool showHandle = true,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) => Center(
            child: ElevatedButton(
              onPressed: () => showGlassSheet<int>(
                context,
                useBlur: useBlur,
                showHandle: showHandle,
                builder: (_) => const Text('弹窗内容'),
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
    );
  }

  testWidgets('打开后渲染 builder 内容', (tester) async {
    await tester.pumpWidget(hostWithButton(onPressed: () {}));
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.text('弹窗内容'), findsOneWidget);
    expect(find.byType(GlassSheet), findsOneWidget);
  });

  testWidgets('默认带拖拽把手', (tester) async {
    await tester.pumpWidget(hostWithButton(onPressed: () {}));
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(GlassSheet),
        matching: find.byType(GlassSheetHandle),
      ),
      findsOneWidget,
    );
  });

  testWidgets('showHandle:false 时不渲染把手', (tester) async {
    await tester.pumpWidget(hostWithButton(onPressed: () {}, showHandle: false));
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.byType(GlassSheetHandle), findsNothing);
  });

  testWidgets('顶角统一为 AppRadius.sheet（28）', (tester) async {
    await tester.pumpWidget(hostWithButton(onPressed: () {}));
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    final surface = tester.widget<GlassSurface>(
      find
          .descendant(
            of: find.byType(GlassSheet),
            matching: find.byType(GlassSurface),
          )
          .first,
    );
    expect(surface.topRadius, AppRadius.sheet);
    expect(surface.tone, GlassTone.strong);
    expect(surface.edge, GlassEdge.top);
  });

  testWidgets('useBlur:true 时插入 BackdropFilter', (tester) async {
    await tester.pumpWidget(hostWithButton(onPressed: () {}));
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(GlassSheet),
        matching: find.byType(BackdropFilter),
      ),
      findsOneWidget,
    );
  });

  testWidgets('useBlur:false 时不插入 BackdropFilter', (tester) async {
    await tester.pumpWidget(hostWithButton(onPressed: () {}, useBlur: false));
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(GlassSheet),
        matching: find.byType(BackdropFilter),
      ),
      findsNothing,
    );
  });

  testWidgets('pop 能带回返回值', (tester) async {
    int? result;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await showGlassSheet<int>(
                  context,
                  builder: (BuildContext ctx) => ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, 42),
                    child: const Text('返回 42'),
                  ),
                );
              },
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('返回 42'));
    await tester.pumpAndSettle();

    expect(result, 42);
  });

  testWidgets('遮罩用 tinted scrim 而非纯黑', (tester) async {
    await tester.pumpWidget(hostWithButton(onPressed: () {}));
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    final modalBarrier = tester.widget<ModalBarrier>(
      find.byType(ModalBarrier).last,
    );
    expect(modalBarrier.color, AppColors.glassScrim);
  });
}