import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/task.dart';
import '../data/models/task_record.dart';
import '../data/repositories/task_repository.dart';

// 计时状态
class TimerState {
  final String taskId;
  final String recordId;
  final DateTime startTime;
  int elapsedSeconds;
  Timer? timer;
  bool isPaused;

  TimerState({
    required this.taskId,
    required this.recordId,
    required this.startTime,
    this.elapsedSeconds = 0,
    this.isPaused = false,
  });

  // 根据实际时间计算已过秒数
  int get currentElapsedSeconds {
    if (isPaused) return elapsedSeconds;
    return DateTime.now().difference(startTime).inSeconds;
  }

  // 转换为Map用于持久化
  Map<String, dynamic> toMap() {
    return {
      'taskId': taskId,
      'recordId': recordId,
      'startTime': startTime.toIso8601String(),
      'elapsedSeconds': elapsedSeconds,
      'isPaused': isPaused,
    };
  }

  // 从Map恢复
  factory TimerState.fromMap(Map<String, dynamic> map) {
    return TimerState(
      taskId: map['taskId'],
      recordId: map['recordId'],
      startTime: DateTime.parse(map['startTime']),
      elapsedSeconds: map['elapsedSeconds'] ?? 0,
      isPaused: map['isPaused'] ?? false,
    );
  }
}

class TaskProvider extends ChangeNotifier {
  final TaskRepository _repository = TaskRepository();

  List<Task> _tasks = [];
  List<TaskRecord> _records = [];
  bool _isLoading = false;

  // 计时状态管理
  final Map<String, TimerState> _activeTimers = {};

  List<Task> get tasks => _tasks;
  List<TaskRecord> get records => _records;
  bool get isLoading => _isLoading;
  Map<String, TimerState> get activeTimers => _activeTimers;

  List<Task> get activeTasks =>
      _tasks.where((t) => !t.isCompleted).toList();

  List<Task> get completedTasks =>
      _tasks.where((t) => t.isCompleted).toList();

  // 检查任务是否正在计时
  bool isTaskRunning(String taskId) => _activeTimers.containsKey(taskId);

  // 获取任务已计时秒数（基于实际时间）
  int getTaskElapsedSeconds(String taskId) {
    final timerState = _activeTimers[taskId];
    if (timerState == null) return 0;
    return timerState.currentElapsedSeconds;
  }

  Future<void> loadTasks() async {
    _isLoading = true;
    notifyListeners();

    try {
      _tasks = await _repository.getAllTasks();
      // 检查并重置每日完成次数
      await _checkAndResetDailyCounts();
      // 恢复活跃的计时器
      await _restoreActiveTimers();
    } catch (e) {
      debugPrint('Error loading tasks: $e');
      _tasks = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 恢复活跃的计时器
  Future<void> _restoreActiveTimers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeTimersJson = prefs.getString('active_timers');

      if (activeTimersJson != null) {
        final Map<String, dynamic> timersMap = jsonDecode(activeTimersJson);

        for (var entry in timersMap.entries) {
          final taskId = entry.key;
          final timerData = entry.value as Map<String, dynamic>;

          // 检查任务是否还存在
          final task = await _repository.getTaskById(taskId);
          if (task == null) continue;

          // 恢复计时状态
          final timerState = TimerState.fromMap(timerData);

          // 检查计时时间是否合理（超过24小时则自动停止）
          if (timerState.currentElapsedSeconds > 86400) {
            // 自动停止并保存记录
            await _autoStopTimer(taskId, timerState);
            continue;
          }

          // 如果未暂停，启动定时器
          if (!timerState.isPaused) {
            _startTimerForState(taskId, task, timerState);
          }

          _activeTimers[taskId] = timerState;
        }

        // 清除已恢复的状态（已暂停的保留）
        if (_activeTimers.isEmpty) {
          await _clearSavedTimers();
        } else {
          await _saveActiveTimers();
        }

        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error restoring timers: $e');
    }
  }

  // 自动停止超时的计时器
  Future<void> _autoStopTimer(String taskId, TimerState timerState) async {
    try {
      final records = await _repository.getRecordsByTaskId(taskId);
      final record = records.where((r) => r.id == timerState.recordId).firstOrNull;

      if (record != null) {
        await _repository.updateRecord(record.copyWith(
          endTime: DateTime.now(),
          duration: timerState.currentElapsedSeconds,
          completedAt: DateTime.now(),
        ));
      }
    } catch (e) {
      debugPrint('Error auto-stopping timer: $e');
    }
  }

  // 为 TimerState 启动定时器
  void _startTimerForState(String taskId, Task task, TimerState timerState) {
    timerState.timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      notifyListeners();

      // 倒计时模式检查
      if (task.timerType == TimerType.countDown &&
          task.duration != null &&
          timerState.currentElapsedSeconds >= task.duration!) {
        stopTimer(taskId);
      }
    });
  }

  // 保存活跃的计时器状态
  Future<void> _saveActiveTimers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> timersMap = {};

      for (var entry in _activeTimers.entries) {
        timersMap[entry.key] = entry.value.toMap();
      }

      await prefs.setString('active_timers', jsonEncode(timersMap));
    } catch (e) {
      debugPrint('Error saving timers: $e');
    }
  }

  // 清除保存的计时器状态
  Future<void> _clearSavedTimers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('active_timers');
    } catch (e) {
      debugPrint('Error clearing timers: $e');
    }
  }

  // 检查并重置每日完成次数
  Future<void> _checkAndResetDailyCounts() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    bool needsUpdate = false;
    for (var task in _tasks) {
      if (task.isRepeatable && task.lastCompletedDate != null) {
        final lastDate = task.lastCompletedDate!;
        final lastDay = DateTime(lastDate.year, lastDate.month, lastDate.day);

        // 如果上次完成日期不是今天，重置完成次数
        if (lastDay.isBefore(today)) {
          final updatedTask = task.copyWith(
            completedCount: 0,
            lastCompletedDate: null,
          );
          await _repository.updateTask(updatedTask);
          needsUpdate = true;
        }
      }
    }

    if (needsUpdate) {
      _tasks = await _repository.getAllTasks();
    }
  }

  Future<void> addTask(Task task) async {
    await _repository.insertTask(task);
    await loadTasks();
  }

  Future<void> updateTask(Task task) async {
    await _repository.updateTask(task);
    await loadTasks();
  }

  Future<void> deleteTask(String id) async {
    // 如果正在计时，先停止
    if (_activeTimers.containsKey(id)) {
      await stopTimer(id);
    }
    await _repository.deleteTask(id);
    await loadTasks();
  }

  Future<void> completeTask(String taskId) async {
    await _repository.completeTask(taskId);
    await loadTasks();
  }

  // ==================== 计时功能 ====================

  Future<void> startTimer(String taskId) async {
    if (_activeTimers.containsKey(taskId)) return;

    final task = await _repository.getTaskById(taskId);
    if (task == null) return;

    final now = DateTime.now();

    // 创建记录
    final record = TaskRecord(
      id: '',
      taskId: taskId,
      startTime: now,
    );
    final recordId = await _repository.insertRecord(record);

    // 创建计时状态
    final timerState = TimerState(
      taskId: taskId,
      recordId: recordId,
      startTime: now,
    );

    // 启动定时器
    _startTimerForState(taskId, task, timerState);

    _activeTimers[taskId] = timerState;

    // 保存计时器状态
    await _saveActiveTimers();

    notifyListeners();
  }

  Future<void> stopTimer(String taskId, {bool autoComplete = true}) async {
    final timerState = _activeTimers[taskId];
    if (timerState == null) return;

    // 停止定时器
    timerState.timer?.cancel();

    // 计算实际经过的秒数
    final actualElapsed = timerState.currentElapsedSeconds;

    // 更新记录
    final records = await _repository.getRecordsByTaskId(taskId);
    if (records.isNotEmpty) {
      final record = records.where((r) => r.id == timerState.recordId).firstOrNull ?? records.first;

      await _repository.updateRecord(record.copyWith(
        endTime: DateTime.now(),
        duration: actualElapsed,
        completedAt: DateTime.now(),
      ));
    }

    // 获取任务信息
    final task = await _repository.getTaskById(taskId);

    // 倒计时模式自动完成任务，正计时模式只保存时间
    if (autoComplete && task?.timerType == TimerType.countDown) {
      await _repository.completeTask(taskId);
    }

    // 移除计时状态
    _activeTimers.remove(taskId);

    // 更新保存的状态
    if (_activeTimers.isEmpty) {
      await _clearSavedTimers();
    } else {
      await _saveActiveTimers();
    }

    notifyListeners();

    await loadTasks();
  }

  Future<void> pauseTimer(String taskId) async {
    final timerState = _activeTimers[taskId];
    if (timerState == null) return;

    // 取消定时器
    timerState.timer?.cancel();
    timerState.timer = null;

    // 记录当前已过秒数
    timerState.elapsedSeconds = timerState.currentElapsedSeconds;
    timerState.isPaused = true;

    // 保存状态
    await _saveActiveTimers();

    notifyListeners();
  }

  Future<void> resumeTimer(String taskId) async {
    final oldTimerState = _activeTimers[taskId];
    if (oldTimerState == null || !oldTimerState.isPaused) return;

    final task = await _repository.getTaskById(taskId);
    if (task == null) return;

    // 创建新的 TimerState，重新设置开始时间
    final newStartTime = DateTime.now().subtract(Duration(seconds: oldTimerState.elapsedSeconds));
    final newTimerState = TimerState(
      taskId: oldTimerState.taskId,
      recordId: oldTimerState.recordId,
      startTime: newStartTime,
      elapsedSeconds: oldTimerState.elapsedSeconds,
      isPaused: false,
    );

    // 启动定时器
    _startTimerForState(taskId, task, newTimerState);

    // 替换旧的 TimerState
    _activeTimers[taskId] = newTimerState;

    // 保存状态
    await _saveActiveTimers();

    notifyListeners();
  }

  // 任务记录相关
  Future<void> loadRecords(String taskId) async {
    _records = await _repository.getRecordsByTaskId(taskId);
    notifyListeners();
  }

  Future<List<TaskRecord>> getRecordsByDateRange(
      DateTime start, DateTime end) async {
    return await _repository.getRecordsByDateRange(start, end);
  }

  Future<int> getTotalDurationByDateRange(
      DateTime start, DateTime end) async {
    return await _repository.getTotalDurationByDateRange(start, end);
  }

  // 获取指定任务今日累计时长
  Future<int> getTaskDailyDuration(String taskId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day + 1);
    final records = await _repository.getRecordsByDateRange(startOfDay, endOfDay);
    int total = 0;
    for (var record in records) {
      if (record.taskId == taskId) {
        total += record.duration;
      }
    }
    return total;
  }

  // 获取所有任务今日累计时长
  Future<Map<String, int>> getAllTaskDailyDurations() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day + 1);
    final records = await _repository.getRecordsByDateRange(startOfDay, endOfDay);
    Map<String, int> durationMap = {};
    for (var record in records) {
      durationMap[record.taskId] = (durationMap[record.taskId] ?? 0) + record.duration;
    }
    return durationMap;
  }

  Future<int> getCompletedTaskCountByDateRange(
      DateTime start, DateTime end) async {
    return await _repository.getCompletedTaskCountByDateRange(start, end);
  }

  Future<List<Map<String, dynamic>>> getTaskDurationSummary(
      DateTime start, DateTime end) async {
    return await _repository.getTaskDurationSummary(start, end);
  }

  Future<Map<String, int>> getDailyDurationMap(
      DateTime start, DateTime end) async {
    return await _repository.getDailyDurationMap(start, end);
  }

  @override
  void dispose() {
    // 取消所有定时器
    for (var timerState in _activeTimers.values) {
      timerState.timer?.cancel();
    }
    _activeTimers.clear();
    super.dispose();
  }
}
