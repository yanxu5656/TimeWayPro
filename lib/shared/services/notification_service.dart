import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../../features/task/data/models/task.dart';

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

  /// 专注计时通知队列（独立于任务计时通知，互不干扰）
  Future<void> _focusOpQueue = Future<void>.value();

  Future<void> _reminderOpQueue = Future<void>.value();

  // 通知ID
  static const int _timerNotificationId = 1001;
  static const String _channelId = 'timer_channel';
  static const String _channelName = '计时通知';

  static const int _focusNotificationId = 1002;
  static const String _focusChannelId = 'focus_channel';
  static const String _focusChannelName = '专注计时通知';

  static const int _focusAlarmNotificationId = 1003;
  static const String _focusAlarmChannelId = 'focus_alarm_channel';
  static const String _focusAlarmChannelName = '专注闹铃提醒';

  static const String _reminderChannelId = 'task_reminder_channel';
  static const String _reminderChannelName = '任务截止提醒';
  static const int _firstTaskReminderId = 2000;
  static const int _taskReminderIdRange = 100000000;

  Future<void> _enqueueOp(Future<void> Function() action) {
    final Future<void> task = _opQueue
        .catchError((Object _) {})
        .then((_) => action());
    _opQueue = task.then((_) {}, onError: (Object _) {});
    return task;
  }

  Future<void> _enqueueFocusOp(Future<void> Function() action) {
    final Future<void> task = _focusOpQueue
        .catchError((Object _) {})
        .then((_) => action());
    _focusOpQueue = task.then((_) {}, onError: (Object _) {});
    return task;
  }

  Future<void> _enqueueReminderOp(Future<void> Function() action) {
    final Future<void> task = _reminderOpQueue
        .catchError((Object _) {})
        .then((_) => action());
    _reminderOpQueue = task.then((_) {}, onError: (Object _) {});
    return task;
  }

  Future<void> _safePluginCall(
    String actionName,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } on MissingPluginException catch (e) {
      debugPrint('NotificationService $actionName skipped: $e');
    } on PlatformException catch (e) {
      debugPrint('NotificationService $actionName skipped: $e');
    } catch (e) {
      // flutter_local_notifications 在未注册平台实现的宿主环境（如桌面测试）
      // 会抛出 LateInitializationError，这里降级跳过以保持纯逻辑/UI 测试稳定。
      debugPrint('NotificationService $actionName skipped: $e');
    }
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    await _safePluginCall('initialize', () async {
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const initSettings = InitializationSettings(android: androidSettings);

      tz_data.initializeTimeZones();
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

      const focusChannel = AndroidNotificationChannel(
        _focusChannelId,
        _focusChannelName,
        description: '显示 45/5 专注与休息倒计时',
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
      );

      final focusAlarmChannel = AndroidNotificationChannel(
        _focusAlarmChannelId,
        _focusAlarmChannelName,
        description: '每 45 分钟专注结束或 5 分钟休息结束时的闹铃提醒',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        vibrationPattern: Int64List.fromList(<int>[0, 650, 350]),
      );

      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.createNotificationChannel(channel);
      await androidPlugin?.createNotificationChannel(focusChannel);
      await androidPlugin?.createNotificationChannel(focusAlarmChannel);

      const reminderChannel = AndroidNotificationChannel(
        _reminderChannelId,
        _reminderChannelName,
        description: '在任务截止日当天 09:00 前发出提醒',
      );
      await androidPlugin?.createNotificationChannel(reminderChannel);

      _isInitialized = true;
    });
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
        await _plugin.show(
          _timerNotificationId,
          '⏱️ $taskTitle',
          body,
          details,
        );
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

  // ==================== 专注 45/5 计时与闹铃通知 ====================
  // 倒计时与闹铃通知均由原生前台服务发出（见 FocusAlarmService.kt），
  // Dart 侧仅保留渠道创建与清理入口。

  Future<void> removeFocusTimerNotification() {
    return _enqueueFocusOp(() async {
      await _safePluginCall(
        'focus cancel',
        () => _plugin.cancel(_focusNotificationId),
      );
    });
  }

  Future<void> removeFocusAlarmNotification() {
    return _enqueueFocusOp(() async {
      await _safePluginCall(
        'focus alarm cancel',
        () => _plugin.cancel(_focusAlarmNotificationId),
      );
    });
  }

  Future<void> syncTaskReminders(List<Task> tasks) {
    if (!Platform.isAndroid && !Platform.isIOS) return Future<void>.value();
    return _enqueueReminderOp(() async {
      await initialize();
      await _safePluginCall('sync task reminders', () async {
        final Set<int> currentIds = tasks
            .map((Task task) => _taskReminderId(task.id))
            .toSet();
        final pending = await _plugin.pendingNotificationRequests();
        final staleIds = staleTaskReminderIds(
          pending.map((request) => request.id),
          currentIds,
        );
        for (final int id in staleIds) {
          await _plugin.cancel(id);
        }
        for (final Task task in tasks) {
          final int id = _taskReminderId(task.id);
          final DateTime? reminderAt = taskReminderAt(task);
          if (reminderAt == null) {
            await _plugin.cancel(id);
            continue;
          }
          final due = task.dueDate!;
          const details = NotificationDetails(
            android: AndroidNotificationDetails(
              _reminderChannelId,
              _reminderChannelName,
              channelDescription: '任务截止提醒',
              importance: Importance.high,
              priority: Priority.high,
              playSound: true,
              enableVibration: true,
            ),
          );
          await _plugin.zonedSchedule(
            id,
            '任务即将到期',
            '「${task.title}」将于 ${due.month}月${due.day}日 09:00 到期',
            tz.TZDateTime.from(reminderAt.toUtc(), tz.UTC),
            details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
        }
      });
    });
  }

  @visibleForTesting
  static List<int> staleTaskReminderIds(
    Iterable<int> pendingIds,
    Iterable<int> currentIds,
  ) {
    final Set<int> current = currentIds.toSet();
    return pendingIds
        .where(
          (int id) =>
              id >= _firstTaskReminderId &&
              id < _firstTaskReminderId + _taskReminderIdRange &&
              !current.contains(id),
        )
        .toList();
  }

  static DateTime? taskReminderAt(Task task) {
    if (task.isCompleted ||
        task.dueDate == null ||
        task.reminderMinutes == null ||
        task.reminderMinutes! < 0) {
      return null;
    }
    final due = task.dueDate!;
    final reminderAt = DateTime(
      due.year,
      due.month,
      due.day,
      9,
    ).subtract(Duration(minutes: task.reminderMinutes!));
    return reminderAt.isAfter(DateTime.now()) ? reminderAt : null;
  }

  static int _taskReminderId(String taskId) {
    int hash = 2166136261;
    for (final int unit in taskId.codeUnits) {
      hash ^= unit;
      hash = (hash * 16777619) & 0x7fffffff;
    }
    return _firstTaskReminderId + hash % _taskReminderIdRange;
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
