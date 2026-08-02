import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/models/daily_task.dart';
import '../data/repositories/daily_repository.dart';

class DailyProvider extends ChangeNotifier {
  final DailyRepository _repository = DailyRepository();

  DateTime _selectedDate = DateTime.now();
  List<DailyTask> _tasks = [];
  bool _isLoading = false;

  DateTime get selectedDate => _selectedDate;
  List<DailyTask> get tasks => _tasks;
  bool get isLoading => _isLoading;

  String get dateKey => DateFormat('yyyy-MM-dd').format(_selectedDate);

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
    _selectedDate = date;
    loadTasks();
  }

  // 前一天
  void previousDay() {
    _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    loadTasks();
  }

  // 后一天
  void nextDay() {
    _selectedDate = _selectedDate.add(const Duration(days: 1));
    loadTasks();
  }

  // 回到今天
  void goToToday() {
    _selectedDate = DateTime.now();
    loadTasks();
  }

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
