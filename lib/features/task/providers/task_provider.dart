import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/utils/week.dart';
import '../data/models/task.dart';
import '../data/models/task_record.dart';
import '../data/repositories/task_repository.dart';
import '../../../shared/services/notification_service.dart';

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
  final NotificationService _notificationService = NotificationService();

  List<Task> _tasks = [];
  List<TaskRecord> _records = [];
  bool _isLoading = false;

  // 计时状态管理
  final Map<String, TimerState> _activeTimers = {};

  /// 启动中的任务（同步防抖）。
  ///
  /// `startTimer` 在检查 `_activeTimers` 与真正写入之间有两个 await
  /// （查任务、插记录），快速双击会插入两条记录、泄漏一个孤儿 Timer。
  /// 进入时先在这里占位，整个启动链走完才释放。
  final Set<String> _startingTimers = <String>{};

  List<Task> get tasks => _tasks;
  List<TaskRecord> get records => _records;
  bool get isLoading => _isLoading;
  Map<String, TimerState> get activeTimers => _activeTimers;

  List<Task> get activeTasks => _tasks.where((t) => !t.isCompleted).toList();

  List<Task> get completedTasks => _tasks.where((t) => t.isCompleted).toList();

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
            _startTimerForState(taskId, timerState);
          }

          _activeTimers[taskId] = timerState;
        }

        // 清除已恢复的状态（已暂停的保留）
        if (_activeTimers.isEmpty) {
          await _clearSavedTimers();
        } else {
          await _saveActiveTimers();

          // 恢复通知
          final firstEntry = _activeTimers.entries.first;
          final task = await _repository.getTaskById(firstEntry.key);
          if (task != null) {
            await _notificationService.showTimerNotification(
              taskTitle: task.title,
              elapsedSeconds: firstEntry.value.currentElapsedSeconds,
              isCountDown: task.timerType == TimerType.countDown,
              totalDuration: task.duration,
            );

            // 启动通知定时更新
            _notificationService.startPeriodicUpdate(
              taskTitle: task.title,
              getElapsedSeconds: () => firstEntry.value.currentElapsedSeconds,
              isCountDown: task.timerType == TimerType.countDown,
              getTotalDuration: () => task.duration,
            );
          }
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
      final record = records
          .where((r) => r.id == timerState.recordId)
          .firstOrNull;

      if (record != null) {
        await _repository.updateRecord(
          record.copyWith(
            endTime: DateTime.now(),
            duration: timerState.currentElapsedSeconds,
            completedAt: DateTime.now(),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error auto-stopping timer: $e');
    }
  }

  // 为 TimerState 启动定时器
  //
  // tick 里按 taskId 现查任务而不是捕获启动时的快照：
  // 计时中把倒计时时长从 25 分钟改成 50 分钟，到点判定要跟着新值走。
  void _startTimerForState(String taskId, TimerState timerState) {
    timerState.timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      notifyListeners();

      // 倒计时模式检查（任务被删则跳过，deleteTask 会先停表）
      final task = _taskById(taskId);
      if (task != null &&
          task.timerType == TimerType.countDown &&
          task.duration != null &&
          timerState.currentElapsedSeconds >= task.duration!) {
        stopTimer(taskId);
      }
    });
  }

  Task? _taskById(String taskId) =>
      _tasks.where((t) => t.id == taskId).firstOrNull;

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
    // 同步占位：见 _startingTimers 的注释（双击防抖）
    if (_activeTimers.containsKey(taskId) ||
        _startingTimers.contains(taskId)) {
      return;
    }
    _startingTimers.add(taskId);
    try {
      final task = await _repository.getTaskById(taskId);
      if (task == null) return;

      final now = DateTime.now();

      // 创建记录
      final record = TaskRecord(id: '', taskId: taskId, startTime: now);
      final recordId = await _repository.insertRecord(record);

      // 创建计时状态
      final timerState = TimerState(
        taskId: taskId,
        recordId: recordId,
        startTime: now,
      );

      // 启动定时器
      _startTimerForState(taskId, timerState);

      _activeTimers[taskId] = timerState;

      // 显示通知
      await _notificationService.showTimerNotification(
        taskTitle: task.title,
        elapsedSeconds: 0,
        isCountDown: task.timerType == TimerType.countDown,
        totalDuration: task.duration,
      );

      // 启动通知定时更新。闭包按 taskId 现查任务，
      // 计时中编辑时长后通知里的总时长也会跟上。
      _notificationService.startPeriodicUpdate(
        taskTitle: task.title,
        getElapsedSeconds: () => timerState.currentElapsedSeconds,
        isCountDown: task.timerType == TimerType.countDown,
        getTotalDuration: () => _taskById(taskId)?.duration,
      );

      // 保存计时器状态
      await _saveActiveTimers();

      notifyListeners();
    } finally {
      _startingTimers.remove(taskId);
    }
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
    // 只更新本次计时对应的那条记录。找不到（比如计时中途做了数据
    // 恢复/导入，recordId 已不在当前数据集里）就放弃更新——
    // 绝不能回退到 records.first，那会把该任务最旧的一条历史记录
    // 的时长和结束时间改掉。
    final record = records.where((r) => r.id == timerState.recordId).firstOrNull;

    if (record != null) {
      await _repository.updateRecord(
        record.copyWith(
          endTime: DateTime.now(),
          duration: actualElapsed,
          completedAt: DateTime.now(),
        ),
      );
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
      // 移除通知
      await _notificationService.removeTimerNotification();
      _notificationService.stopPeriodicUpdate();
    } else {
      await _saveActiveTimers();
      // 更新通知为下一个活跃任务。
      // 必须同步重绑 startPeriodicUpdate：5 秒前为已停止任务启动的
      // 周期更新器还持有旧闭包，不重绑的话通知会被刷回已停止的任务。
      final nextEntry = _activeTimers.entries.first;
      final nextTask = await _repository.getTaskById(nextEntry.key);
      if (nextTask != null) {
        await _notificationService.showTimerNotification(
          taskTitle: nextTask.title,
          elapsedSeconds: nextEntry.value.currentElapsedSeconds,
          isCountDown: nextTask.timerType == TimerType.countDown,
          totalDuration: nextTask.duration,
        );
        _notificationService.startPeriodicUpdate(
          taskTitle: nextTask.title,
          getElapsedSeconds: () => nextEntry.value.currentElapsedSeconds,
          isCountDown: nextTask.timerType == TimerType.countDown,
          getTotalDuration: () => _taskById(nextEntry.key)?.duration,
        );
      }
    }

    notifyListeners();

    await loadTasks();
  }

  /// 数据恢复/导入前调用：停掉所有计时器并清空持久化计时状态。
  ///
  /// 活跃数据即将被整体替换：在途会话的记录随旧数据一起消失，
  /// 所以不做记录回写、不自动完成任务，只负责把表和通知清干净。
  /// 不先停表的话，恢复后 recordId 都指向新数据集里不存在的记录。
  Future<void> stopAllTimersForDataReset() async {
    for (final timerState in _activeTimers.values) {
      timerState.timer?.cancel();
    }
    _activeTimers.clear();
    await _clearSavedTimers();
    await _notificationService.removeTimerNotification();
    _notificationService.stopPeriodicUpdate();
    notifyListeners();
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

    // 同步占位，防连点导致的重复恢复（会产生两个 Timer，先启的那个泄漏）
    if (_startingTimers.contains(taskId)) return;
    _startingTimers.add(taskId);
    try {
      final task = await _repository.getTaskById(taskId);
      if (task == null) return;

      // 创建新的 TimerState，重新设置开始时间
      final newStartTime = DateTime.now().subtract(
        Duration(seconds: oldTimerState.elapsedSeconds),
      );
      final newTimerState = TimerState(
        taskId: oldTimerState.taskId,
        recordId: oldTimerState.recordId,
        startTime: newStartTime,
        elapsedSeconds: oldTimerState.elapsedSeconds,
        isPaused: false,
      );

      // 启动定时器
      _startTimerForState(taskId, newTimerState);

      // 替换旧的 TimerState
      _activeTimers[taskId] = newTimerState;

      // 保存状态
      await _saveActiveTimers();

      // 恢复通知并重绑周期更新：暂停期间旧更新器已冻结在暂停时刻
      await _notificationService.showTimerNotification(
        taskTitle: task.title,
        elapsedSeconds: newTimerState.currentElapsedSeconds,
        isCountDown: task.timerType == TimerType.countDown,
        totalDuration: task.duration,
      );
      _notificationService.startPeriodicUpdate(
        taskTitle: task.title,
        getElapsedSeconds: () {
          final state = _activeTimers[taskId];
          // 已被停掉后旧更新器不会再触发（stopTimer 会解绑），这里兜底
          return state?.currentElapsedSeconds ?? 0;
        },
        isCountDown: task.timerType == TimerType.countDown,
        getTotalDuration: () => _taskById(taskId)?.duration,
      );

      notifyListeners();
    } finally {
      _startingTimers.remove(taskId);
    }
  }

  // 任务记录相关
  Future<void> loadRecords(String taskId) async {
    _records = await _repository.getRecordsByTaskId(taskId);
    notifyListeners();
  }

  Future<List<TaskRecord>> getRecordsByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    return await _repository.getRecordsByDateRange(start, end);
  }

  Future<int> getTotalDurationByDateRange(DateTime start, DateTime end) async {
    return await _repository.getTotalDurationByDateRange(start, end);
  }

  // 获取指定任务在某一天的累计时长（默认今天）
  Future<int> getTaskDailyDuration(String taskId, {DateTime? day}) async {
    final DateTime target = day ?? DateTime.now();
    // 半开区间 [当天 00:00, 次日 00:00)——与 getRecordsByDateRange 的判定
    // 严格匹配，且不会漏掉 23:59:59.xxx 的记录
    final records = await _repository.getRecordsByDateRange(
      startOfDay(target),
      nextDayStart(target),
    );
    int total = 0;
    for (var record in records) {
      if (record.taskId == taskId) {
        total += record.duration;
      }
    }
    return total;
  }

  // 获取所有任务在某一天的累计时长（默认今天）
  //
  // 任务页的日期选择器就靠这个：传入选中的日期即可拿到那天的时长。
  // 原先「今天」是写死在方法体里的（DateTime.now()），所以翻日期时
  // 标题变了、数字不变。
  Future<Map<String, int>> getAllTaskDailyDurations({DateTime? day}) async {
    final DateTime target = day ?? DateTime.now();
    final records = await _repository.getRecordsByDateRange(
      startOfDay(target),
      nextDayStart(target),
    );
    Map<String, int> durationMap = {};
    for (var record in records) {
      durationMap[record.taskId] =
          (durationMap[record.taskId] ?? 0) + record.duration;
    }
    return durationMap;
  }

  Future<int> getCompletedTaskCountByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    return await _repository.getCompletedTaskCountByDateRange(start, end);
  }

  Future<List<Map<String, dynamic>>> getTaskDurationSummary(
    DateTime start,
    DateTime end,
  ) async {
    return await _repository.getTaskDurationSummary(start, end);
  }

  Future<Map<String, int>> getDailyDurationMap(
    DateTime start,
    DateTime end,
  ) async {
    return await _repository.getDailyDurationMap(start, end);
  }

  @override
  void dispose() {
    // 取消所有定时器
    for (var timerState in _activeTimers.values) {
      timerState.timer?.cancel();
    }
    _activeTimers.clear();
    // 清理通知服务
    _notificationService.stopPeriodicUpdate();
    super.dispose();
  }
}
