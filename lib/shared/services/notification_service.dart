import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  Timer? _updateTimer;
  bool _isInitialized = false;

  // 通知ID
  static const int _timerNotificationId = 1001;
  static const String _channelId = 'timer_channel';
  static const String _channelName = '计时通知';

  Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(initSettings);

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
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _isInitialized = true;
  }

  // 显示计时通知
  Future<void> showTimerNotification({
    required String taskTitle,
    required int elapsedSeconds,
    required bool isCountDown,
    int? totalDuration,
  }) async {
    await initialize();

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

    await _plugin.show(
      _timerNotificationId,
      '⏱️ $taskTitle',
      body,
      details,
    );
  }

  // 更新计时通知
  Future<void> updateTimerNotification({
    required String taskTitle,
    required int elapsedSeconds,
    required bool isCountDown,
    int? totalDuration,
  }) async {
    await showTimerNotification(
      taskTitle: taskTitle,
      elapsedSeconds: elapsedSeconds,
      isCountDown: isCountDown,
      totalDuration: totalDuration,
    );
  }

  // 移除计时通知
  Future<void> removeTimerNotification() async {
    await _plugin.cancel(_timerNotificationId);
    _updateTimer?.cancel();
    _updateTimer = null;
  }

  // 启动定时更新通知
  void startPeriodicUpdate({
    required String taskTitle,
    required int Function() getElapsedSeconds,
    required bool isCountDown,
    int? Function()? getTotalDuration,
  }) {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      final elapsed = getElapsedSeconds();
      final total = getTotalDuration?.call();
      updateTimerNotification(
        taskTitle: taskTitle,
        elapsedSeconds: elapsed,
        isCountDown: isCountDown,
        totalDuration: total,
      );
    });
  }

  // 停止定时更新
  void stopPeriodicUpdate() {
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
