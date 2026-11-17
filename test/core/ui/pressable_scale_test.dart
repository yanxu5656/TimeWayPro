import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_way_pro/core/ui/paper.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
  debugShowCheckedModeBanner: false,
);

/// 读取当前缩放值。
///
/// 注意不能用 `Matrix4.getMaxScaleOnAxis()`——它会把 Z 轴的 1.0 也算进去，
/// 于是对角线为 (0.965, 0.965, 1.0) 的矩阵永远返回 1.0。这里直接读 X 轴。
double _currentScale(WidgetTester tester) {
  final Transform t = tester.widget<Transform>(
    find
        .descendant(
          of: find.byType(PressableScale),
          matching: find.byType(Transform),
        )
        .first,
  );
  return t.transform.entry(0, 0);
}

/// 按下并推进动画。
///
/// `AnimationController.forward()` 之后的**第一个** `pump` 只是给新 ticker
/// 定下起始时刻（该帧 elapsed = 0），动画值不会前进。必须再 pump 一次带
/// 时长的帧才真正推进。踩过坑，别删。
Future<void> _pressAndAdvance(WidgetTester tester, {int ms = 110}) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: ms));
}

/// 抬起并推进释放动画
Future<void> _releaseAndAdvance(WidgetTester tester, {int ms = 220}) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: ms));
}

void main() {
  setUp(UiEffects.resetForTesting);

  testWidgets('按下缩小、抬起回到 1.0', (tester) async {
    await tester.pumpWidget(
      _host(const PressableScale(child: SizedBox(width: 100, height: 100))),
    );

    expect(_currentScale(tester), moreOrLessEquals(1.0, epsilon: 0.001));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PressableScale)),
    );
    await _pressAndAdvance(tester);
    expect(_currentScale(tester), lessThan(1.0));
    expect(_currentScale(tester), moreOrLessEquals(0.965, epsilon: 0.002));

    await gesture.up();
    await _releaseAndAdvance(tester);
    expect(_currentScale(tester), moreOrLessEquals(1.0, epsilon: 0.001));
  });

  testWidgets('按下后移动超过 8px 会取消压下态（列表滚动不粘滞）', (tester) async {
    await tester.pumpWidget(
      _host(const PressableScale(child: SizedBox(width: 200, height: 200))),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PressableScale)),
    );
    await _pressAndAdvance(tester);
    expect(_currentScale(tester), lessThan(1.0));

    // 移动 20px —— 视为开始滚动
    await gesture.moveBy(const Offset(20, 0));
    await _releaseAndAdvance(tester);
    expect(_currentScale(tester), moreOrLessEquals(1.0, epsilon: 0.001));

    await gesture.up();
    await tester.pump();
  });

  testWidgets('小幅抖动（< 8px）不取消', (tester) async {
    await tester.pumpWidget(
      _host(const PressableScale(child: SizedBox(width: 200, height: 200))),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PressableScale)),
    );
    await _pressAndAdvance(tester);

    await gesture.moveBy(const Offset(3, 3));
    await tester.pump(const Duration(milliseconds: 50));
    expect(_currentScale(tester), lessThan(1.0));

    await gesture.up();
    await _releaseAndAdvance(tester);
  });

  testWidgets('enabled:false 时按下不缩放', (tester) async {
    await tester.pumpWidget(
      _host(
        const PressableScale(
          enabled: false,
          child: SizedBox(width: 100, height: 100),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PressableScale)),
    );
    await _pressAndAdvance(tester);
    expect(_currentScale(tester), moreOrLessEquals(1.0, epsilon: 0.001));
    await gesture.up();
    await tester.pump();
  });

  testWidgets('释放曲线有过冲（easeOutBack），不是单调弹回', (tester) async {
    await tester.pumpWidget(
      _host(const PressableScale(child: SizedBox(width: 100, height: 100))),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PressableScale)),
    );
    await _pressAndAdvance(tester, ms: 130);
    await gesture.up();
    await tester.pump(); // 启动释放 ticker

    // 释放时 controller 从 1.0 反向走到 0.0，CurvedAnimation 对
    // reverseCurve 做的是 easeOutBack(parent.value)——而 easeOutBack 在
    // t≈0.75 处 > 1，映射到 Tween(1.0 → 0.965) 上就是**缩到比按下值更小**
    // （约 0.9628），随后才回到 1.0。所以过冲的方向是"过下"，不是"过上"。
    var minScale = 1.0;
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      minScale = minScale < _currentScale(tester)
          ? minScale
          : _currentScale(tester);
    }

    expect(
      minScale,
      lessThan(0.965),
      reason: 'easeOutBack 应产生过冲（缩过按下值），否则手感是匀速弹回',
    );
    expect(minScale, greaterThan(0.9), reason: '过冲幅度应克制，不超过按下的 6%');

    await tester.pump(const Duration(milliseconds: 100));
    expect(_currentScale(tester), moreOrLessEquals(1.0, epsilon: 0.001));
  });

  testWidgets('快按快放（未跑完按下动画）走正向曲线，不回弹', (tester) async {
    // 这条钉住 CurvedAnimation 的固有语义：reverseCurve 只在正向动画
    // completed 之后才生效。看 PressableScale 的类文档。
    await tester.pumpWidget(
      _host(const PressableScale(child: SizedBox(width: 100, height: 100))),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PressableScale)),
    );
    // 只推进 40ms —— 远未到 110ms 的按下动画总时长
    await _pressAndAdvance(tester, ms: 40);
    final pressedScale = _currentScale(tester);
    expect(pressedScale, lessThan(1.0));

    await gesture.up();
    await tester.pump();

    var minScale = 1.0;
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      minScale = minScale < _currentScale(tester)
          ? minScale
          : _currentScale(tester);
    }

    // 不会缩过刚才按到的位置
    expect(minScale, greaterThanOrEqualTo(pressedScale - 0.0001));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_currentScale(tester), moreOrLessEquals(1.0, epsilon: 0.001));
  });

  testWidgets('与内层 GestureDetector 共存：按下被感知且 tap 仍触发', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        PressableScale(
          child: GestureDetector(
            // opaque 是真实用法（PaperIconButton 也是这么写的）：
            // deferToChild 下无实心内容的盒子收不到命中
            behavior: HitTestBehavior.opaque,
            onTap: () => taps++,
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PressableScale)),
    );
    await _pressAndAdvance(tester);
    // Listener 走原始指针事件，不受手势竞技场影响
    expect(_currentScale(tester), lessThan(1.0));

    await gesture.up();
    await _releaseAndAdvance(tester);
    expect(taps, 1);
  });

  testWidgets('空白区域也能接收按下（无子内容的 SizedBox）', (tester) async {
    // 这条守的是 HitTestBehavior.opaque：deferToChild 下无子内容的
    // SizedBox 不可命中，整个 Listener 收不到事件。
    await tester.pumpWidget(
      _host(const PressableScale(child: SizedBox(width: 300, height: 300))),
    );

    final gesture = await tester.startGesture(
      tester.getTopLeft(find.byType(PressableScale)) + const Offset(4, 4),
    );
    await _pressAndAdvance(tester);
    expect(_currentScale(tester), lessThan(1.0));

    await gesture.up();
    await _releaseAndAdvance(tester);
  });

  testWidgets('pressOffset：按下时整体向桌面方向下沉，抬起归零', (tester) async {
    await tester.pumpWidget(
      _host(
        const PressableScale(
          pressOffset: 1.5,
          child: SizedBox(width: 100, height: 100),
        ),
      ),
    );

    // 下沉是第二层 Transform（translate），缩放是第一层
    double currentOffset() {
      final Transform t = tester.widget<Transform>(
        find
            .descendant(
              of: find.byType(PressableScale),
              matching: find.byType(Transform),
            )
            .last,
      );
      return t.transform.entry(1, 3);
    }

    expect(currentOffset(), moreOrLessEquals(0, epsilon: 0.001));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PressableScale)),
    );
    await _pressAndAdvance(tester);
    expect(currentOffset(), moreOrLessEquals(1.5, epsilon: 0.01));

    await gesture.up();
    await _releaseAndAdvance(tester);
    expect(currentOffset(), moreOrLessEquals(0, epsilon: 0.001));
  });

  testWidgets('builder 变体拿到 0..1 的按压进度，child 原样传入', (tester) async {
    final List<double> progress = <double>[];
    await tester.pumpWidget(
      _host(
        PressableScale(
          builder: (BuildContext context, double press, Widget? child) {
            progress.add(press);
            return SizedBox(
              width: 100,
              height: 100,
              child: ColoredBox(
                color: Color.lerp(Colors.white, Colors.black, press)!,
                child: child,
              ),
            );
          },
          child: const Text('内容'),
        ),
      ),
    );

    expect(find.text('内容'), findsOneWidget);
    expect(progress.last, moreOrLessEquals(0, epsilon: 0.001));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PressableScale)),
    );
    await _pressAndAdvance(tester);
    expect(progress.last, moreOrLessEquals(1.0, epsilon: 0.001));

    await gesture.up();
    await _releaseAndAdvance(tester);
    expect(progress.last, moreOrLessEquals(0, epsilon: 0.001));
  });

  testWidgets('系统减弱动效时缩放/位移退化，但触觉保留', (tester) async {
    final List<MethodCall> haptics = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
          MethodCall call,
        ) async {
          if (call.method == 'HapticFeedback.vibrate') haptics.add(call);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    // MediaQuery 必须放在 MaterialApp **里面**：MaterialApp 会用
    // MediaQuery.fromView 重建外层数据，包在外面会被覆盖掉
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: const Scaffold(
            body: Center(
              child: PressableScale(
                pressOffset: 1.5,
                child: SizedBox(width: 100, height: 100),
              ),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PressableScale)),
    );
    await _pressAndAdvance(tester);
    expect(
      _currentScale(tester),
      moreOrLessEquals(1.0, epsilon: 0.001),
      reason: '减弱动效下不应有缩放动画',
    );
    expect(haptics, isNotEmpty, reason: '触觉反馈不属于动效，应保留');

    await gesture.up();
    await tester.pump();
  });
}
