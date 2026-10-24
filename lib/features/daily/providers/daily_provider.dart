import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/week.dart';
import '../data/models/daily_task.dart';
import '../data/repositories/daily_repository.dart';

class DailyProvider extends ChangeNotifier {
  final DailyRepository _repository = DailyRepository();

  // 归一到当天 00:00：`DateTime.now()` 带时分，在 00:00-00:59 之间
  // 用 ±24h 跨夏令时会掉到前前一天（中国无 DST，但逻辑上应正确）
  DateTime _selectedDate = startOfDay(DateTime.now());
  List<DailyTask> _tasks = [];
  bool _isLoading = false;

  DateTime get selectedDate => _selectedDate;
  List<DailyTask> get tasks => _tasks;
  bool get isLoading => _isLoading;

  String get dateKey => DateFormat('yyyy-MM-dd').format(_selectedDate);

  // 每周目标已迁至独立的「每周」Tab（lib/features/weekly/），
  // 本页回归纯「当天」视角。

  // 按时间段分组的任务
  List<DailyTask> get morningTasks =>
      _tasks.where((t) => t.timePeriod == TimePeriod.morning).toList();

  List<DailyTask> get afternoonTasks =>
      _tasks.where((t) => t.timePeriod == TimePeriod.afternoon).toList();

  List<DailyTask> get eveningTasks =>
      _tasks.where((t) => t.timePeriod == TimePeriod.evening).toList();

  // 统计
  int get totalTasks => _tasks.length;
  int get completedTasks => _tasks.where((t) => t.isCompleted).length;
  double get progress => totalTasks > 0 ? completedTasks / totalTasks : 0;

  // 切换日期
  void setDate(DateTime date) {
    _selectedDate = startOfDay(date);
    loadTasks();
  }

  // 前一天 / 后一天：构造函数日运算（±Duration 是绝对时间运算，
  // DST 切换日会差一小时），DateTime(y, m, d±n) 自动处理跨月跨年
  void previousDay() =>
      setDate(DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day - 1));

  void nextDay() =>
      setDate(DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day + 1));

  // 回到今天
  void goToToday() => setDate(DateTime.now());

  // 加载任务
  Future<void> loadTasks() async {
    _isLoading = true;
    notifyListeners();

    try {
      _tasks = await _repository.getTasksByDate(dateKey);
    } catch (e) {
      debugPrint('Error loading daily tasks: $e');
      _tasks = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 添加任务
  Future<void> addTask({
    required String title,
    String? description,
    required TimePeriod timePeriod,
  }) async {
    final task = DailyTask(
      id: '',
      title: title,
      description: description,
      timePeriod: timePeriod,
      dateKey: dateKey,
      createdAt: DateTime.now(),
    );

    await _repository.addTask(task);
    await loadTasks();
  }

  // 更新任务
  Future<void> updateTask(DailyTask task) async {
    await _repository.updateTask(task);
    await loadTasks();
  }

  // 删除任务
  Future<void> deleteTask(String id) async {
    await _repository.deleteTask(id);
    await loadTasks();
  }

  // 切换完成状态
  Future<void> toggleComplete(String id) async {
    await _repository.toggleComplete(id);
    await loadTasks();
  }
}
