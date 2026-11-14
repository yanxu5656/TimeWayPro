import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  Timer? _updateTimer;
  bool _isInitialized = false;

  /// 通知代次令牌：每次停止定时更新或移除通知时同步递增。
  ///
  /// 用来消除 `Timer.periodic` 回调 / `startTimer` 里的异步 `show` 与
  /// `removeTimerNotification` 之间的竞态：旧代次的 `show` 在 `await`
  /// 恢复后若发现代次已过期会直接放弃，不再把已停止的通知重新贴回通知栏。
  int _notificationEpoch = 0;

  /// 串行队列：保证平台通道的 `show` 与 `cancel` 严格按调用顺序执行，
  /// 不会出现 `cancel` 先落地、更早发起的 `show` 后落地的问题。
  Future<void> _opQueue = Future<void>.value();

  // 通知ID
  static const int _timerNotificationId = 1001;
  static const String _channelId = 'timer_channel';
  static const String _channelName = '计时通知';

  Future<void> _enqueueOp(Future<void> Function() action) {
    final Future<void> task = _opQueue
        .catchError((Object _) {})
        .then((_) => action());
    _opQueue = task.then((_) {}, onError: (Object _) {});
    return task;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const initSettings = InitializationSettings(android: androidSettings);

      await _plugin.initialize(initSettings);

      // 请求通知权限（Android 13+）
      if (Platform.isAndroid) {
        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        if (android != null) {
          await android.requestNotificationsPermission();
        }
      }

      // 创建通知渠道
      const channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: '显示当前正在计时的任务',
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
      );

      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);

      _isInitialized = true;
    } on MissingPluginException catch (e) {
      debugPrint('NotificationService initialize skipped: $e');
    }
  }

  // 显示计时通知
  Future<void> showTimerNotification({
    required String taskTitle,
    required int elapsedSeconds,
    required bool isCountDown,
    int? totalDuration,
    int? expectedEpoch,
  }) {
    final int epoch = expectedEpoch ?? _notificationEpoch;
    return _enqueueOp(() async {
      if (epoch != _notificationEpoch) return;
      await initialize();
      if (epoch != _notificationEpoch) return;

      final timeStr = _formatDuration(elapsedSeconds);
      String body;

      if (isCountDown && totalDuration != null) {
        final remaining = totalDuration - elapsedSeconds;
        if (remaining > 0) {
          body = '剩余 ${_formatDuration(remaining)}';
        } else {
          body = '计时已完成';
        }
      } else {
        body = '已计时 $timeStr';
      }

      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: '显示当前正在计时的任务',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        showWhen: false,
        enableLights: false,
        enableVibration: false,
        playSound: false,
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: '⏱️ $taskTitle',
        ),
      );

      final details = NotificationDetails(android: androidDetails);

      try {
        await _plugin.show(_timerNotificationId, '⏱️ $taskTitle', body, details);
      } on MissingPluginException catch (e) {
        debugPrint('NotificationService show skipped: $e');
      }
    });
  }

  // 更新计时通知
  Future<void> updateTimerNotification({
    required String taskTitle,
    required int elapsedSeconds,
    required bool isCountDown,
    int? totalDuration,
    int? expectedEpoch,
  }) async {
    await showTimerNotification(
      taskTitle: taskTitle,
      elapsedSeconds: elapsedSeconds,
      isCountDown: isCountDown,
      totalDuration: totalDuration,
      expectedEpoch: expectedEpoch,
    );
  }

  // 移除计时通知
  Future<void> removeTimerNotification() {
    // 必须先同步停掉周期更新并递增代次，再排队取消通知，
    // 防止在途的定时刷新在 cancel 之后把通知重新贴回来。
    stopPeriodicUpdate();
    return _enqueueOp(() async {
      try {
        await _plugin.cancel(_timerNotificationId);
      } on MissingPluginException catch (e) {
        debugPrint('NotificationService cancel skipped: $e');
      }
    });
  }

  // 启动定时更新通知
  void startPeriodicUpdate({
    required String taskTitle,
    required int Function() getElapsedSeconds,
    required bool isCountDown,
    int? Function()? getTotalDuration,
  }) {
    _updateTimer?.cancel();
    final int epoch = ++_notificationEpoch;
    _updateTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (epoch != _notificationEpoch) {
        timer.cancel();
        return;
      }
      final elapsed = getElapsedSeconds();
      final total = getTotalDuration?.call();
      updateTimerNotification(
        taskTitle: taskTitle,
        elapsedSeconds: elapsed,
        isCountDown: isCountDown,
        totalDuration: total,
        expectedEpoch: epoch,
      );
    });
  }

  // 停止定时更新
  void stopPeriodicUpdate() {
    _notificationEpoch++;
    _updateTimer?.cancel();
    _updateTimer = null;
  }

  String _formatDuration(int seconds) {
    if (seconds < 0) seconds = 0;
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
  }
}
