import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_way_pro/core/ui/aurora_background.dart';
import 'package:time_way_pro/core/ui/ui_effects.dart';

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(body: child),
      debugShowCheckedModeBanner: false,
    );

void main() {
  setUp(UiEffects.resetForTesting);

  testWidgets('forceAnimated:false 时 pumpAndSettle 能收敛', (tester) async {
    await tester.pumpWidget(
      _host(const AuroraBackground(forceAnimated: false)),
    );

    // 若控制器仍在 repeat，这里会因永不 settle 而抛 StateError。
    // 这条测试的意义是给后续所有 UI 测试留一个可用的逃生口。
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });

  testWidgets('UiEffects 降到 reduced 后自动停掉漂移动画', (tester) async {
    await tester.pumpWidget(_host(const AuroraBackground()));
    await tester.pump();

    UiEffects.tier.value = UiEffectTier.reduced;

    // 降级生效后才能 settle
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });

  testWidgets('UiEffects 降到 minimal 后同样停掉动画', (tester) async {
    await tester.pumpWidget(_host(const AuroraBackground()));
    await tester.pump();

    UiEffects.tier.value = UiEffectTier.minimal;
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });

  testWidgets('动画状态切换不残留 Ticker', (tester) async {
    await tester.pumpWidget(_host(const AuroraBackground()));
    await tester.pump();

    // 换成静止模式（触发 didUpdateWidget）
    await tester.pumpWidget(_host(const AuroraBackground(forceAnimated: false)));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    // 卸载：dispose 必须取消 UiEffects 监听并释放 controller，
    // 否则 flutter_test 会在 teardown 时报 pending ticker
    await tester.pumpWidget(_host(const SizedBox.shrink()));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });

  testWidgets('自带 RepaintBoundary 隔离每帧重绘', (tester) async {
    await tester.pumpWidget(_host(const AuroraBackground(forceAnimated: false)));

    expect(
      find.descendant(
        of: find.byType(AuroraBackground),
        matching: find.byType(RepaintBoundary),
      ),
      findsWidgets,
    );
  });

  testWidgets('CustomPaint 声明 willChange，避免被光栅缓存', (tester) async {
    await tester.pumpWidget(_host(const AuroraBackground(forceAnimated: false)));

    final paint = tester.widget<CustomPaint>(
      find
          .descendant(
            of: find.byType(AuroraBackground),
            matching: find.byType(CustomPaint),
          )
          .first,
    );
    expect(paint.willChange, isTrue);
    expect(paint.isComplex, isFalse);
  });

  testWidgets('极端宽高比下不抛异常', (tester) async {
    // 光斑半径按 size.shortestSide 计算，细长/超宽比例都不应出现 NaN 或除零
    for (final size in const [Size(320, 4000), Size(4000, 100)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        _host(const AuroraBackground(forceAnimated: false)),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '尺寸 $size 下渲染失败');
    }
    await tester.binding.setSurfaceSize(null);
  });
}