import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/services/notification_service.dart';
import '../services/focus_alarm_service.dart';

/// 专注 45 分钟 / 休息 5 分钟循环计时阶段。
enum FocusPhase {
  idle,
  focusing,
  focusAlarm,
  breaking,
  breakAlarm,
}

/// 悬浮球全局 45/5 专注计时控制器。
///
/// 使用壁钟截止时间（`_phaseEndTime`）推算剩余秒数；每个阶段开始时拉起
/// 原生前台服务全程保活——倒计时通知由系统渲染，到点由原生服务直接
/// 切换持续振动闹铃。锁屏、切后台、最近任务清理后依然准时提醒。
class FocusTimerProvider extends ChangeNotifier {
  FocusTimerProvider({
    int focusDurationSeconds = defaultFocusSeconds,
    int breakDurationSeconds = defaultBreakSeconds,
    FocusAlarmService? alarmService,
    NotificationService? notificationService,
  }) : _focusDurationSeconds = focusDurationSeconds > 0
           ? focusDurationSeconds
           : defaultFocusSeconds,
       _breakDurationSeconds = breakDurationSeconds > 0
           ? breakDurationSeconds
           : defaultBreakSeconds,
       _alarmService = alarmService ?? FocusAlarmService(),
       _notificationService = notificationService ?? NotificationService();

  static const int defaultFocusSeconds = 45 * 60;
  static const int defaultBreakSeconds = 5 * 60;
  static const String _prefsKey = 'focus_timer_state';
  static const String _modePrefsKey = 'focus_alarm_mode';
  static const String _batteryPromptPrefsKey = 'focus_battery_prompt_shown';

  final FocusAlarmService _alarmService;
  final NotificationService _notificationService;

  int _focusDurationSeconds;
  int _breakDurationSeconds;

  FocusPhase _phase = FocusPhase.idle;
  bool _isPaused = false;
  DateTime? _phaseEndTime;
  int _pausedRemainingSeconds = 0;
  int _completedRounds = 0;
  bool _isTestingAlarm = false;
  FocusAlarmMode _alarmMode = FocusAlarmMode.soundAndVibration;

  Timer? _ticker;

  FocusPhase get phase => _phase;
  bool get isPaused => _isPaused;
  bool get isRunning =>
      _phase == FocusPhase.focusing || _phase == FocusPhase.breaking;
  bool get isAlarming =>
      _phase == FocusPhase.focusAlarm || _phase == FocusPhase.breakAlarm;
  bool get isActive => _phase != FocusPhase.idle;
  bool get isTestingAlarm => _isTestingAlarm;
  FocusAlarmMode get alarmMode => _alarmMode;
  int get completedRounds => _completedRounds;
  int get focusDurationSeconds => _focusDurationSeconds;
  int get breakDurationSeconds => _breakDurationSeconds;

  int get totalPhaseSeconds {
    if (_phase == FocusPhase.breaking || _phase == FocusPhase.breakAlarm) {
      return _breakDurationSeconds;
    }
    return _focusDurationSeconds;
  }

  int get remainingSeconds {
    switch (_phase) {
      case FocusPhase.idle:
        return _focusDurationSeconds;
      case FocusPhase.focusAlarm:
      case FocusPhase.breakAlarm:
        return 0;
      case FocusPhase.focusing:
      case FocusPhase.breaking:
        if (_isPaused) {
          return _pausedRemainingSeconds.clamp(0, totalPhaseSeconds);
        }
        final DateTime? end = _phaseEndTime;
        if (end == null) return 0;
        final int diffMs = end.difference(DateTime.now()).inMilliseconds;
        if (diffMs <= 0) return 0;
        return (diffMs / 1000).ceil().clamp(0, totalPhaseSeconds);
    }
  }

  double get progress {
    final int total = totalPhaseSeconds;
    if (total <= 0) return 0;
    return (1 - remainingSeconds / total).clamp(0.0, 1.0);
  }

  String get formattedRemaining => formatClock(remainingSeconds);

  static String formatClock(int totalSeconds) {
    final int safe = totalSeconds < 0 ? 0 : totalSeconds;
    final int minutes = safe ~/ 60;
    final int seconds = safe % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @visibleForTesting
  void configureDurationsForTesting({
    int? focusSeconds,
    int? breakSeconds,
  }) {
    if (focusSeconds != null) _focusDurationSeconds = focusSeconds;
    if (breakSeconds != null) _breakDurationSeconds = breakSeconds;
    notifyListeners();
  }

  /// 切换闹铃模式并持久化；正在响铃（含试听）时立即按新模式重放。
  Future<void> setAlarmMode(FocusAlarmMode mode) async {
    if (_alarmMode == mode) return;
    _alarmMode = mode;
    notifyListeners();
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_modePrefsKey, mode.prefValue);
    } catch (e) {
      debugPrint('FocusTimerProvider setAlarmMode persist error: $e');
    }
    if (isAlarming) {
      await _alarmService.startAlarm(
        mode: mode,
        title: _alarmTitle(_phase == FocusPhase.focusAlarm),
        body: _alarmBody(_phase == FocusPhase.focusAlarm),
      );
    } else if (_isTestingAlarm) {
      await _alarmService.startAlarm(mode: mode);
    }
  }

  /// 首次开始专注前是否需要引导用户关闭电池优化（仅 Android）。
  Future<bool> needsBatteryOptimizationPrompt() async {
    if (!Platform.isAndroid) return false;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_batteryPromptPrefsKey) == true) return false;
      return !await _alarmService.isIgnoringBatteryOptimizations();
    } catch (e) {
      debugPrint('FocusTimerProvider battery prompt check error: $e');
      return false;
    }
  }

  Future<void> markBatteryPromptShown() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_batteryPromptPrefsKey, true);
    } catch (e) {
      debugPrint('FocusTimerProvider markBatteryPromptShown error: $e');
    }
  }

  Future<bool> requestIgnoreBatteryOptimizations() =>
      _alarmService.requestIgnoreBatteryOptimizations();

  Future<void> restoreState() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      _alarmMode = FocusAlarmMode.fromPref(prefs.getString(_modePrefsKey));
      final String? raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) {
        notifyListeners();
        return;
      }

      final Map<String, dynamic> data =
          jsonDecode(raw) as Map<String, dynamic>;
      final int phaseIndex = (data['phase'] as num?)?.toInt() ?? 0;
      if (phaseIndex <= 0 || phaseIndex >= FocusPhase.values.length) {
        await _clearPersistedState();
        return;
      }

      _phase = FocusPhase.values[phaseIndex];
      _isPaused = data['isPaused'] == true;
      _pausedRemainingSeconds = (data['pausedRemaining'] as num?)?.toInt() ?? 0;
      _completedRounds = (data['completedRounds'] as num?)?.toInt() ?? 0;
      final String? endIso = data['phaseEndTime'] as String?;
      _phaseEndTime = endIso == null ? null : DateTime.tryParse(endIso);

      if (isAlarming) {
        await _triggerAlarm(fromPhase: _phase == FocusPhase.focusAlarm
            ? FocusPhase.focusing
            : FocusPhase.breaking);
        return;
      }

      if (isRunning) {
        if (_isPaused) {
          await _alarmService.pauseCountdown(
            remainingSeconds: _pausedRemainingSeconds,
            isFocus: _phase == FocusPhase.focusing,
          );
          notifyListeners();
        } else if (remainingSeconds <= 0) {
          await _triggerAlarm(fromPhase: _phase);
        } else {
          _startTicker();
          await _syncNativeCountdown();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('FocusTimerProvider restoreState error: $e');
    }
  }

  Future<void> startFocus() async {
    await stopTestAlarm();

    _phase = FocusPhase.focusing;
    _isPaused = false;
    _phaseEndTime = DateTime.now().add(
      Duration(seconds: _focusDurationSeconds),
    );
    _pausedRemainingSeconds = _focusDurationSeconds;

    _startTicker();
    await _persistState();
    await _syncNativeCountdown();
    notifyListeners();
  }

  Future<void> startBreak() async {
    await stopTestAlarm();

    _phase = FocusPhase.breaking;
    _isPaused = false;
    _phaseEndTime = DateTime.now().add(
      Duration(seconds: _breakDurationSeconds),
    );
    _pausedRemainingSeconds = _breakDurationSeconds;

    _startTicker();
    await _persistState();
    await _syncNativeCountdown();
    notifyListeners();
  }

  Future<void> pause() async {
    if (!isRunning || _isPaused) return;
    _pausedRemainingSeconds = remainingSeconds;
    _isPaused = true;
    _ticker?.cancel();
    _ticker = null;

    await _persistState();
    await _alarmService.pauseCountdown(
      remainingSeconds: _pausedRemainingSeconds,
      isFocus: _phase == FocusPhase.focusing,
    );
    notifyListeners();
  }

  Future<void> resume() async {
    if (!isRunning || !_isPaused) return;
    if (_pausedRemainingSeconds <= 0) {
      await _triggerAlarm(fromPhase: _phase);
      return;
    }

    _phaseEndTime = DateTime.now().add(
      Duration(seconds: _pausedRemainingSeconds),
    );
    _isPaused = false;

    _startTicker();
    await _persistState();
    await _syncNativeCountdown();
    notifyListeners();
  }

  /// 仅关闭闹铃并回到未开始状态（保留已完成轮数供本次界面展示）。
  Future<void> dismissAlarm() async {
    await stopTestAlarm();
    await _alarmService.stopAll();
    await _notificationService.removeFocusAlarmNotification();
    await _notificationService.removeFocusTimerNotification();

    _ticker?.cancel();
    _ticker = null;
    _phase = FocusPhase.idle;
    _isPaused = false;
    _phaseEndTime = null;
    _pausedRemainingSeconds = 0;

    await _clearPersistedState();
    notifyListeners();
  }

  /// 彻底结束本轮专注循环并清零。
  Future<void> stop() async {
    await stopTestAlarm();
    await _alarmService.stopAll();
    await _notificationService.removeFocusAlarmNotification();
    await _notificationService.removeFocusTimerNotification();

    _ticker?.cancel();
    _ticker = null;
    _phase = FocusPhase.idle;
    _isPaused = false;
    _phaseEndTime = null;
    _pausedRemainingSeconds = 0;
    _completedRounds = 0;

    await _clearPersistedState();
    notifyListeners();
  }

  Future<void> toggleTestAlarm() async {
    if (_isTestingAlarm) {
      await stopTestAlarm();
    } else {
      _isTestingAlarm = true;
      notifyListeners();
      await _alarmService.startAlarm(mode: _alarmMode);
    }
  }

  Future<void> stopTestAlarm() async {
    if (!_isTestingAlarm) return;
    _isTestingAlarm = false;
    if (!isAlarming) {
      await _alarmService.stopAlarm();
    }
    notifyListeners();
  }

  /// 从后台回到前台时根据壁钟立即同步状态（若已过节点则立刻响铃）。
  Future<void> syncWithClock() async {
    if (!isRunning || _isPaused) return;
    if (remainingSeconds <= 0) {
      await _triggerAlarm(fromPhase: _phase);
    } else {
      notifyListeners();
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _onTick();
    });
  }

  void _onTick() {
    if (!isRunning || _isPaused) {
      _ticker?.cancel();
      _ticker = null;
      return;
    }

    if (remainingSeconds <= 0) {
      _triggerAlarm(fromPhase: _phase);
      return;
    }

    notifyListeners();
  }

  Future<void> _triggerAlarm({required FocusPhase fromPhase}) async {
    _ticker?.cancel();
    _ticker = null;
    _isPaused = false;
    _phaseEndTime = null;
    _pausedRemainingSeconds = 0;

    final bool finishedFocus = fromPhase == FocusPhase.focusing;
    if (finishedFocus && _phase != FocusPhase.focusAlarm) {
      _completedRounds++;
    }
    _phase = finishedFocus ? FocusPhase.focusAlarm : FocusPhase.breakAlarm;

    await _persistState();
    await _alarmService.startAlarm(
      mode: _alarmMode,
      title: _alarmTitle(finishedFocus),
      body: _alarmBody(finishedFocus),
    );
    notifyListeners();
  }

  static String _alarmTitle(bool finishedFocus) =>
      finishedFocus ? '⏰ 45 分钟专注时间到' : '🔔 5 分钟休息结束';

  static String _alarmBody(bool finishedFocus) => finishedFocus
      ? '请放下手头工作，点击关闭闹铃并休息 5 分钟'
      : '休息结束，点击关闭闹铃并开始下一轮 45 分钟专注';

  /// 让原生前台服务与当前阶段对齐：常驻保活 + 系统渲染倒计时通知。
  Future<void> _syncNativeCountdown() async {
    final DateTime? end = _phaseEndTime;
    if (end != null && isRunning && !_isPaused) {
      await _alarmService.startCountdown(
        end: end,
        isFocus: _phase == FocusPhase.focusing,
        rounds: _completedRounds + 1,
      );
    }
  }

  Future<void> _persistState() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode(<String, dynamic>{
          'phase': _phase.index,
          'isPaused': _isPaused,
          'phaseEndTime': _phaseEndTime?.toIso8601String(),
          'pausedRemaining': _pausedRemainingSeconds,
          'completedRounds': _completedRounds,
        }),
      );
    } catch (e) {
      debugPrint('FocusTimerProvider persistState error: $e');
    }
  }

  Future<void> _clearPersistedState() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (e) {
      debugPrint('FocusTimerProvider clearPersistedState error: $e');
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}