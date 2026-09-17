import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_way_pro/core/ui/glass.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
  debugShowCheckedModeBanner: false,
);

/// 模拟统计页的时长格式化（字符串里混着数字和单位）
String _formatDuration(int seconds) {
  if (seconds < 60) return '${seconds}s';
  if (seconds < 3600) return '${seconds ~/ 60}m';
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  return '${hours}h ${minutes}m';
}

void main() {
  setUp(UiEffects.resetForTesting);

  testWidgets('初始显示 format(0)，动画结束后显示 format(value)', (tester) async {
    await tester.pumpWidget(
      _host(const CountUpText(value: 1200, format: _formatDuration)),
    );

    // 首帧是动画起点 0
    expect(find.text('0s'), findsOneWidget);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 650));
    expect(find.text('20m'), findsOneWidget);
  });

  testWidgets('中途是介于两端之间的值', (tester) async {
    await tester.pumpWidget(
      _host(const CountUpText(value: 600, format: _formatDuration)),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final text = tester.widget<Text>(find.byType(Text)).data!;
    expect(text, isNot('0s'));
    expect(text, isNot('10m'));
  });

  testWidgets('值变化时从当前值滚到新值，不从 0 重来', (tester) async {
    await tester.pumpWidget(
      _host(const CountUpText(value: 600, format: _formatDuration)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 650));
    expect(find.text('10m'), findsOneWidget);

    // 换一个新值
    await tester.pumpWidget(
      _host(const CountUpText(value: 900, format: _formatDuration)),
    );
    await tester.pump();

    // 起点应是 10m 附近，而不是回到 0s
    final startText = tester.widget<Text>(find.byType(Text)).data!;
    expect(startText, isNot('0s'));

    await tester.pump(const Duration(milliseconds: 650));
    expect(find.text('15m'), findsOneWidget);
  });

  testWidgets('UiEffects 关掉 countUp 时直接显示终值', (tester) async {
    UiEffects.resetForTesting();
    UiEffects.tier.value = UiEffectTier.minimal;

    await tester.pumpWidget(
      _host(const CountUpText(value: 1200, format: _formatDuration)),
    );

    expect(find.text('20m'), findsOneWidget);
    addTearDown(UiEffects.resetForTesting);
  });

  testWidgets('外面包了 RepaintBoundary，每帧只重绘这一小块', (tester) async {
    await tester.pumpWidget(
      _host(const CountUpText(value: 60, format: _formatDuration)),
    );

    expect(
      find.descendant(
        of: find.byType(CountUpText),
        matching: find.byType(RepaintBoundary),
      ),
      findsWidgets,
    );
  });

  testWidgets('format 为纯数字字符串也能工作', (tester) async {
    await tester.pumpWidget(
      _host(const CountUpText(value: 8, format: _plainInt)),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 650));
    expect(find.text('8'), findsOneWidget);
  });
}

String _plainInt(int v) => '$v';
