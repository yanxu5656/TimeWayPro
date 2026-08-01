import 'dart:async';
import 'package:flutter/material.dart';
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

  TimerState({
    required this.taskId,
    required this.recordId,
    required this.startTime,
    this.elapsedSeconds = 0,
  });
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

  // 获取任务已计时秒数
  int getTaskElapsedSeconds(String taskId) {
    return _activeTimers[taskId]?.elapsedSeconds ?? 0;
  }

  Future<void> loadTasks() async {
    _isLoading = true;
    notifyListeners();

    try {
      _tasks = await _repository.getAllTasks();
    } catch (e) {
      debugPrint('Error loading tasks: $e');
      _tasks = [];
    } finally {
      _isLoading = false;
      notifyListeners();
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

    // 创建记录
    final record = TaskRecord(
      id: '',
      taskId: taskId,
      startTime: DateTime.now(),
    );
    final recordId = await _repository.insertRecord(record);

    // 创建计时状态
    final timerState = TimerState(
      taskId: taskId,
      recordId: recordId,
      startTime: DateTime.now(),
    );

    // 启动定时器
    timerState.timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      timerState.elapsedSeconds++;
      notifyListeners();

      // 倒计时模式检查
      if (task.timerType == TimerType.countDown &&
          task.duration != null &&
          timerState.elapsedSeconds >= task.duration!) {
        stopTimer(taskId);
      }
    });

    _activeTimers[taskId] = timerState;
    notifyListeners();
  }

  Future<void> stopTimer(String taskId, {bool autoComplete = true}) async {
    final timerState = _activeTimers[taskId];
    if (timerState == null) return;

    // 停止定时器
    timerState.timer?.cancel();

    // 更新记录
    final records = await _repository.getRecordsByTaskId(taskId);
    final record = records.firstWhere(
      (r) => r.id == timerState.recordId,
      orElse: () => records.first,
    );

    await _repository.updateRecord(record.copyWith(
      endTime: DateTime.now(),
      duration: timerState.elapsedSeconds,
      completedAt: DateTime.now(),
    ));

    // 获取任务信息
    final task = await _repository.getTaskById(taskId);

    // 倒计时模式自动完成任务，正计时模式只保存时间
    if (autoComplete && task?.timerType == TimerType.countDown) {
      await _repository.completeTask(taskId);
    }

    // 移除计时状态
    _activeTimers.remove(taskId);
    notifyListeners();

    await loadTasks();
  }

  Future<void> pauseTimer(String taskId) async {
    final timerState = _activeTimers[taskId];
    if (timerState == null) return;

    timerState.timer?.cancel();
    notifyListeners();
  }

  Future<void> resumeTimer(String taskId) async {
    final timerState = _activeTimers[taskId];
    if (timerState == null) return;

    final task = await _repository.getTaskById(taskId);
    if (task == null) return;

    timerState.timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      timerState.elapsedSeconds++;
      notifyListeners();

      if (task.timerType == TimerType.countDown &&
          task.duration != null &&
          timerState.elapsedSeconds >= task.duration!) {
        stopTimer(taskId);
      }
    });

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
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
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
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
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
