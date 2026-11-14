import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:time_way_pro/app/app.dart';
import 'package:time_way_pro/core/ui/paper.dart';
import 'package:time_way_pro/features/task/providers/task_provider.dart';
import 'package:time_way_pro/shared/database/database_helper.dart';
import 'package:time_way_pro/shared/services/notification_service.dart';

import '../../support/app_harness.dart';

/// 任务计时模块回归测试：
/// 1. 结束计时只需点击一次，不再弹出确认弹窗
/// 2. 结束/完成正在计时的任务后，通知栏计时框可靠移除且不被异步刷新贴回
/// 3. 结束计时后统计页时长立即刷新，无需重启应用
void main() {
  const MethodChannel notificationChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );

  late List<String> notificationCalls;
  Completer<void>? showDelayCompleter;

  void installNotificationMock() {
    notificationCalls = <String>[];
    showDelayCompleter = null;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationChannel, (MethodCall call) async {
          notificationCalls.add(call.method);
          if (call.method == 'show' && showDelayCompleter != null) {
            await showDelayCompleter!.future;
          }
          if (call.method == 'initialize') return true;
          return null;
        });
  }

  group('NotificationService 竞态与清理', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      installNotificationMock();
    });

    tearDown(() {
      NotificationService().stopPeriodicUpdate();
    });

    test('在途的异步 show 未完成时调用 removeTimerNotification，最终一定会 cancel 且过时代次不再 show', () async {
      final NotificationService service = NotificationService();
      await service.initialize();
      notificationCalls.clear();

      // 让第一次 show 卡在异步平台调用上，模拟周期刷新或刚启动时立即停止的竞态
      showDelayCompleter = Completer<void>();
      final Future<void> firstShow = service.showTimerNotification(
        taskTitle: '测试任务',
        elapsedSeconds: 5,
        isCountDown: false,
      );
      // 让 firstShow 真正进入平台通道 _plugin.show 并挂起在 Completer 上
      await Future<void>.delayed(Duration.zero);

      // firstShow 在途时有一次周期刷新进入队列，紧接着调用移除通知
      final Future<void> secondShow = service.showTimerNotification(
        taskTitle: '测试任务',
        elapsedSeconds: 10,
        isCountDown: false,
      );
      final Future<void> removeFuture = service.removeTimerNotification();

      // 释放第一次 show 的平台调用
      showDelayCompleter!.complete();
      await Future.wait(<Future<void>>[
        firstShow,
        secondShow,
        removeFuture,
      ]);

      // 队列中未执行的 secondShow 应因代次过期被跳过，最终以 cancel 收尾
      expect(notificationCalls, <String>['show', 'cancel']);
    });
  });

  group('TaskProvider 计时结束与通知清理', () {
    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues(<String, Object>{});
      installPathProviderMock();
      installNotificationMock();
      await DatabaseHelper().importAll(seedData());
    });

    test('stopTimer 会递增 dataVersion 并取消通知', () async {
      final TaskProvider provider = TaskProvider();
      await provider.loadTasks();
      final int initialVersion = provider.dataVersion;

      notificationCalls.clear();
      await provider.startTimer('t1');
      expect(provider.isTaskRunning('t1'), isTrue);
      expect(notificationCalls, contains('show'));

      notificationCalls.clear();
      await provider.stopTimer('t1');

      expect(provider.isTaskRunning('t1'), isFalse);
      expect(provider.dataVersion, greaterThan(initialVersion));
      expect(notificationCalls, contains('cancel'));
      expect(notificationCalls.last, 'cancel');
    });

    test('直接点击完成正在计时的一次性任务也会停止计时并移除通知', () async {
      final TaskProvider provider = TaskProvider();
      await provider.loadTasks();

      await provider.startTimer('t1');
      expect(provider.isTaskRunning('t1'), isTrue);

      notificationCalls.clear();
      await provider.completeTask('t1');

      expect(provider.isTaskRunning('t1'), isFalse);
      expect(provider.activeTimers, isEmpty);
      expect(notificationCalls.last, 'cancel');
    });
  });

  group('任务页一键结束与统计页实时刷新', () {
    setUp(() {
      installNotificationMock();
    });

    testWidgets('点击结束按钮一次即停止计时，不弹窗，且切回统计页立即刷新时长', (tester) async {
      // 种子数据里今日总时长故意设为 0，便于明确验证统计页从 0s 变为 >0s
      final Map<String, dynamic> customSeed = seedData();
      customSeed['task_records'] = <Map<String, dynamic>>[];

      UiEffects.resetForTesting();
      UiEffects.tier.value = UiEffectTier.reduced;
      SharedPreferences.setMockInitialValues(<String, Object>{});
      installPathProviderMock();
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.runAsync(() => DatabaseHelper().importAll(customSeed));
      await tester.pumpWidget(const TimeWayProApp());
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }

      // 先进入统计页，建立缓存（此时今日总时长为 0s）
      await switchToTab(tester, '统计');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('0s'), findsOneWidget);

      // 切到任务页，开始「写周报」的正计时
      await switchToTab(tester, '任务');
      final Finder playButton = find.byIcon(Icons.play_arrow_rounded).first;
      await tester.runAsync(() async {
        await tester.tap(playButton);
        // 等待真实时间推进 2 秒，确保记录到非 0 时长
        await Future<void>.delayed(const Duration(milliseconds: 2100));
      });
      await tester.pump();

      expect(find.byIcon(Icons.stop_rounded), findsWidgets);

      // 点击一次结束按钮：不应弹出确认对话框，应直接结束计时
      notificationCalls.clear();
      await tester.runAsync(() async {
        await tester.tap(find.byIcon(Icons.stop_rounded).first);
        await Future<void>.delayed(const Duration(milliseconds: 400));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('结束计时'), findsNothing);
      expect(find.byIcon(Icons.stop_rounded), findsNothing);
      expect(find.text('时间已记录'), findsOneWidget);
      expect(notificationCalls.last, 'cancel');

      // 切回统计页，无需重启应用即应刷新出新时长（不再停留在 0s）
      await switchToTab(tester, '统计');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('0s'), findsNothing);
      final TaskProvider provider = tester
          .element(find.byType(MaterialApp))
          .read<TaskProvider>();
      expect(provider.activeTimers, isEmpty);
    });
  });
}
