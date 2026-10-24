import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_way_pro/core/ui/paper.dart';

void main() {
  setUp(UiEffects.resetForTesting);

  Widget hostWithButton({required VoidCallback onPressed, bool showHandle = true}) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) => Center(
            child: ElevatedButton(
              onPressed: () => showPaperSheet<int>(
                context,
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
    expect(find.byType(PaperSheet), findsOneWidget);
  });

  testWidgets('默认带拖拽把手', (tester) async {
    await tester.pumpWidget(hostWithButton(onPressed: () {}));
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(PaperSheet),
        matching: find.byType(PaperSheetHandle),
      ),
      findsOneWidget,
    );
  });

  testWidgets('showHandle:false 时不渲染把手', (tester) async {
    await tester.pumpWidget(
      hostWithButton(onPressed: () {}, showHandle: false),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.byType(PaperSheetHandle), findsNothing);
  });

  testWidgets('底板是纯白浮起面，不用模糊（纸面体系的硬约束）', (tester) async {
    await tester.pumpWidget(hostWithButton(onPressed: () {}));
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(PaperSheet),
        matching: find.byType(BackdropFilter),
      ),
      findsNothing,
    );
    final sheet = find.byType(PaperSheet);
    expect(
      tester
          .widget<DecoratedBox>(
            find.descendant(of: sheet, matching: find.byType(DecoratedBox)).first,
          )
          .decoration is BoxDecoration,
      isTrue,
    );
  });

  testWidgets('pop 能带回返回值', (tester) async {
    int? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showPaperSheet<int>(
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
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('返回 42'));
    await tester.pumpAndSettle();

    expect(result, 42);
  });

  testWidgets('遮罩是墨色 scrim 而非纯黑', (tester) async {
    await tester.pumpWidget(hostWithButton(onPressed: () {}));
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    final modalBarrier = tester.widget<ModalBarrier>(
      find.byType(ModalBarrier).last,
    );
    expect(modalBarrier.color, AppColors.scrim);
  });
}
