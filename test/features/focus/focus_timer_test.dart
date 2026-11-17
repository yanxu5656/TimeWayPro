import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:time_way_pro/core/ui/paper.dart';
import 'package:time_way_pro/features/focus/providers/focus_timer_provider.dart';
import 'package:time_way_pro/features/focus/services/focus_alarm_service.dart';

import '../../support/app_harness.dart';

void main() {
  const MethodChannel alarmChannel = MethodChannel(
    'com.timewaypro.time_way_pro/alarm',
  );

  test('FocusTimerProvider 默认时长为 45 分钟专注与 5 分钟休息', () {
    final FocusTimerProvider provider = FocusTimerProvider();
    expect(provider.focusDurationSeconds, 45 * 60);
    expect(provider.breakDurationSeconds, 5 * 60);
    expect(provider.formattedRemaining, '45:00');
    expect(provider.phase, FocusPhase.idle);
  });

  testWidgets('专注到点触发持续振动闹铃，进入休息停止闹铃且倒计时 5 分钟', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final List<String> alarmCalls = <String>[];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(alarmChannel, (MethodCall call) async {
      alarmCalls.add(call.method);
      return true;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(alarmChannel, null);
    });

    final FocusTimerProvider provider = FocusTimerProvider(
      focusDurationSeconds: 1,
      breakDurationSeconds: 1,
    );
    addTearDown(provider.dispose);

    await tester.runAsync(() async {
      await provider.startFocus();
      expect(provider.phase, FocusPhase.focusing);
      await Future<void>.delayed(const Duration(milliseconds: 1150));
      await provider.syncWithClock();

      expect(provider.phase, FocusPhase.focusAlarm);
      expect(provider.isAlarming, isTrue);
      expect(provider.completedRounds, 1);
      expect(alarmCalls, contains('startAlarm'));

      alarmCalls.clear();
      await provider.startBreak();
      expect(provider.phase, FocusPhase.breaking);
      expect(provider.isAlarming, isFalse);
      expect(alarmCalls, contains('startCountdown'));

      await Future<void>.delayed(const Duration(milliseconds: 1150));
      await provider.syncWithClock();
      expect(provider.phase, FocusPhase.breakAlarm);
      expect(alarmCalls, contains('startAlarm'));

      await provider.dismissAlarm();
      expect(provider.phase, FocusPhase.idle);
      expect(alarmCalls, contains('stopAll'));
    });
  });

  testWidgets('开始/暂停/恢复/结束会同步原生前台计时服务', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final List<MethodCall> calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(alarmChannel, (MethodCall call) async {
      calls.add(call);
      return true;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(alarmChannel, null);
    });

    final FocusTimerProvider provider = FocusTimerProvider(
      focusDurationSeconds: 60,
      breakDurationSeconds: 60,
    );
    addTearDown(provider.dispose);

    await tester.runAsync(() async {
      await provider.startFocus();
      final MethodCall countdown = calls.lastWhere(
        (MethodCall c) => c.method == 'startCountdown',
      );
      final Map<dynamic, dynamic> args =
          countdown.arguments as Map<dynamic, dynamic>;
      final int endMillis = args['endMillis'] as int;
      final int expected =
          DateTime.now().add(const Duration(seconds: 60)).millisecondsSinceEpoch;
      expect((endMillis - expected).abs(), lessThan(3000));
      expect(args['isFocus'], true);
      expect(args['rounds'], 1);

      await provider.pause();
      expect(calls.last.method, 'pauseCountdown');

      await provider.resume();
      expect(calls.last.method, 'startCountdown');

      await provider.stop();
      expect(calls.last.method, 'stopAll');
    });
  });

  testWidgets('闹铃模式默认响铃+振动，可切换仅振动并持久化', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final List<MethodCall> calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(alarmChannel, (MethodCall call) async {
      calls.add(call);
      return true;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(alarmChannel, null);
    });

    final FocusTimerProvider provider = FocusTimerProvider();
    addTearDown(provider.dispose);

    await tester.runAsync(() async {
      await provider.restoreState();
      expect(provider.alarmMode, FocusAlarmMode.soundAndVibration);

      await provider.setAlarmMode(FocusAlarmMode.vibrationOnly);
      expect(provider.alarmMode, FocusAlarmMode.vibrationOnly);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('focus_alarm_mode'), 'vibrate');

      await provider.toggleTestAlarm();
      final MethodCall start = calls.lastWhere(
        (MethodCall c) => c.method == 'startAlarm',
      );
      expect(
        (start.arguments as Map<dynamic, dynamic>)['mode'],
        'vibrate',
      );
      await provider.stopTestAlarm();

      // 重新加载后模式应恢复
      final FocusTimerProvider reloaded = FocusTimerProvider();
      addTearDown(reloaded.dispose);
      await reloaded.restoreState();
      expect(reloaded.alarmMode, FocusAlarmMode.vibrationOnly);
    });
  });

  testWidgets('八个 Tab 表面都存在专注悬浮按钮且不破坏主 FAB', (WidgetTester tester) async {
    await pumpSeededApp(tester);

    const Map<String, int> expectedPaperFabCount = <String, int>{
      '待办': 1,
      '每周': 1,
      '任务': 1,
      '统计': 0,
      '规划': 1,
      '闲时': 1,
      '月历': 0,
      '设置': 0,
    };

    for (final MapEntry<String, int> entry in expectedPaperFabCount.entries) {
      await switchToTab(tester, entry.key);
      expect(
        find.byKey(const Key('focus_timer_fab')),
        findsOneWidget,
        reason: 'Tab "${entry.key}" 应该显示全局专注悬浮按钮',
      );
      expect(
        find.byType(PaperFab),
        findsNWidgets(entry.value),
        reason: '全局专注按钮不应占用或改变 "${entry.key}" 页原有 PaperFab 数量',
      );
    }

    await tester.tap(find.byKey(const Key('focus_timer_fab')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('专注计时'), findsOneWidget);
    expect(find.text('开始 45 分钟专注'), findsOneWidget);
    expect(find.text('试听持续振动闹铃'), findsOneWidget);
  });

  testWidgets('闹铃触发后在任意 Tab 顶部展示全局停铃横幅并可一键开始休息', (WidgetTester tester) async {
    final List<String> alarmCalls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(alarmChannel, (MethodCall call) async {
      alarmCalls.add(call.method);
      return true;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(alarmChannel, null);
    });

    await pumpSeededApp(tester);

    final BuildContext mainCtx = tester.element(find.byType(PaperNavBar));
    final FocusTimerProvider provider = mainCtx.read<FocusTimerProvider>();
    provider.configureDurationsForTesting(focusSeconds: 1, breakSeconds: 300);

    await switchToTab(tester, '统计');
    await tester.runAsync(() async {
      await provider.startFocus();
      await Future<void>.delayed(const Duration(milliseconds: 1150));
      await provider.syncWithClock();
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byKey(const Key('focus_alarm_banner')), findsOneWidget);
    expect(find.text('45 分钟专注时间到！'), findsOneWidget);
    expect(alarmCalls, contains('startAlarm'));

    await tester.runAsync(() async {
      await tester.tap(find.text('停铃并休息 5 分钟'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(provider.phase, FocusPhase.breaking);
    expect(find.byKey(const Key('focus_alarm_banner')), findsNothing);
    expect(alarmCalls, contains('startCountdown'));

    await tester.runAsync(() => provider.stop());
  });
}
