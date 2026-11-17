import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 闹铃提醒模式。
enum FocusAlarmMode {
  /// 闹钟铃声 + 持续振动（默认）。
  soundAndVibration('sound'),

  /// 仅持续振动，适合会议、图书馆等需要安静的场合。
  vibrationOnly('vibrate');

  const FocusAlarmMode(this.prefValue);

  /// 持久化取值，原生侧通过 `flutter.focus_alarm_mode` 读取同一约定。
  final String prefValue;

  static FocusAlarmMode fromPref(String? raw) =>
      raw == vibrationOnly.prefValue ? vibrationOnly : soundAndVibration;
}

/// 原生专注计时前台服务。
///
/// 整个 45/5 循环期间由原生前台服务保活：倒计时通知由系统渲染，
/// 到点切换持续振动 +（可选）闹铃铃声。锁屏、切后台、最近任务清理后
/// 进程依然存活，闹铃准时响起。在测试环境或非 Android 平台下
/// 若未注册通道会安全跳过。
class FocusAlarmService {
  static final FocusAlarmService _instance = FocusAlarmService._internal();
  factory FocusAlarmService() => _instance;
  FocusAlarmService._internal();

  static const MethodChannel _channel = MethodChannel(
    'com.timewaypro.time_way_pro/alarm',
  );

  /// 启动（或更新）倒计时阶段，原生服务常驻并预约到点闹铃。
  Future<void> startCountdown({
    required DateTime end,
    required bool isFocus,
    required int rounds,
  }) async {
    try {
      await _channel.invokeMethod<bool>('startCountdown', <String, dynamic>{
        'endMillis': end.millisecondsSinceEpoch,
        'isFocus': isFocus,
        'rounds': rounds,
      });
    } on MissingPluginException catch (e) {
      debugPrint('FocusAlarmService startCountdown skipped: $e');
    } on PlatformException catch (e) {
      debugPrint('FocusAlarmService startCountdown failed: $e');
    }
  }

  Future<void> pauseCountdown({
    required int remainingSeconds,
    required bool isFocus,
  }) async {
    try {
      await _channel.invokeMethod<bool>('pauseCountdown', <String, dynamic>{
        'remainingSeconds': remainingSeconds,
        'isFocus': isFocus,
      });
    } on MissingPluginException catch (e) {
      debugPrint('FocusAlarmService pauseCountdown skipped: $e');
    } on PlatformException catch (e) {
      debugPrint('FocusAlarmService pauseCountdown failed: $e');
    }
  }

  Future<void> startAlarm({
    FocusAlarmMode mode = FocusAlarmMode.soundAndVibration,
    String title = '⏰ 专注时间到',
    String body = '',
  }) async {
    try {
      await _channel.invokeMethod<bool>('startAlarm', <String, dynamic>{
        'mode': mode.prefValue,
        'title': title,
        'body': body,
      });
    } on MissingPluginException catch (e) {
      debugPrint('FocusAlarmService startAlarm skipped: $e');
    } on PlatformException catch (e) {
      debugPrint('FocusAlarmService startAlarm failed: $e');
    }
  }

  /// 仅停止闹铃播放（试听）；进行中的倒计时由原生自动恢复。
  Future<void> stopAlarm() async {
    try {
      await _channel.invokeMethod<bool>('stopAlarm');
    } on MissingPluginException catch (e) {
      debugPrint('FocusAlarmService stopAlarm skipped: $e');
    } on PlatformException catch (e) {
      debugPrint('FocusAlarmService stopAlarm failed: $e');
    }
  }

  /// 结束整个专注会话：停服务、取消系统闹钟、清除全部相关通知。
  Future<void> stopAll() async {
    try {
      await _channel.invokeMethod<bool>('stopAll');
    } on MissingPluginException catch (e) {
      debugPrint('FocusAlarmService stopAll skipped: $e');
    } on PlatformException catch (e) {
      debugPrint('FocusAlarmService stopAll failed: $e');
    }
  }

  Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      return await _channel.invokeMethod<bool>(
            'isIgnoringBatteryOptimizations',
          ) ??
          true;
    } on MissingPluginException catch (e) {
      debugPrint('FocusAlarmService battery check skipped: $e');
      return true;
    } on PlatformException catch (e) {
      debugPrint('FocusAlarmService battery check failed: $e');
      return true;
    }
  }

  Future<bool> requestIgnoreBatteryOptimizations() async {
    try {
      return await _channel.invokeMethod<bool>(
            'requestIgnoreBatteryOptimizations',
          ) ??
          false;
    } on MissingPluginException catch (e) {
      debugPrint('FocusAlarmService battery request skipped: $e');
      return false;
    } on PlatformException catch (e) {
      debugPrint('FocusAlarmService battery request failed: $e');
      return false;
    }
  }
}