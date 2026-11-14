import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 原生持续振动与闹铃服务。
///
/// 通过 Android `MainActivity` 暴露的平台通道调用系统 `Vibrator`（循环波形）
/// 与 `MediaPlayer`（`USAGE_ALARM` 闹钟声道循环响铃）；在测试环境或非 Android
/// 平台下若未注册通道会安全跳过。
class FocusAlarmService {
  static final FocusAlarmService _instance = FocusAlarmService._internal();
  factory FocusAlarmService() => _instance;
  FocusAlarmService._internal();

  static const MethodChannel _channel = MethodChannel(
    'com.timewaypro.time_way_pro/alarm',
  );

  Future<void> startAlarm() async {
    try {
      await _channel.invokeMethod<bool>('startAlarm');
    } on MissingPluginException catch (e) {
      debugPrint('FocusAlarmService startAlarm skipped: $e');
    } on PlatformException catch (e) {
      debugPrint('FocusAlarmService startAlarm failed: $e');
    }
  }

  Future<void> stopAlarm() async {
    try {
      await _channel.invokeMethod<bool>('stopAlarm');
    } on MissingPluginException catch (e) {
      debugPrint('FocusAlarmService stopAlarm skipped: $e');
    } on PlatformException catch (e) {
      debugPrint('FocusAlarmService stopAlarm failed: $e');
    }
  }
}
