import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/week.dart';
import '../data/models/daily_task.dart';
import '../data/models/weekly_goal.dart';
import '../data/repositories/daily_repository.dart';
import '../data/repositories/weekly_goal_repository.dart';

class DailyProvider extends ChangeNotifier {
  final DailyRepository _repository = DailyRepository();
  final WeeklyGoalRepository _weeklyRepository = WeeklyGoalRepository();

  DateTime _selectedDate = DateTime.now();
  List<DailyTask> _tasks = [];
  bool _isLoading = false;

  List<WeeklyGoal> _weeklyGoals = [];

  DateTime get selectedDate => _selectedDate;
  List<DailyTask> get tasks => _tasks;
  bool get isLoading => _isLoading;

  String get dateKey => DateFormat('yyyy-MM-dd').format(_selectedDate);

  // ── 本周目标 ──
  //
  // 只存本周，不做周导航，所以没有额外的导航状态。跨周时旧数据仍留在
  // JSON 文件里，只是不再显示。

  List<WeeklyGoal> get weeklyGoals => _weeklyGoals;

  /// 本周的周标识（本周周一的日期）。每次加载时现算，
  /// 这样应用长期开着跨过周日午夜后，下一次加载就会切到新的一周。
  String get currentWeekKey => weekKeyOf(DateTime.now());

  int get weeklyTotal => _weeklyGoals.length;
  int get weeklyCompleted => _weeklyGoals.where((g) => g.isCompleted).length;
  double get weeklyProgress =>
      weeklyTotal > 0 ? weeklyCompleted / weeklyTotal : 0;

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
      // 本周目标与日期导航无关，但同屏显示，跟着一起刷最省事
      _weeklyGoals = await _weeklyRepository.getByWeek(currentWeekKey);
    } catch (e) {
      debugPrint('Error loading daily tasks: $e');
      _tasks = [];
      _weeklyGoals = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─ 本周目标的增删改 ──

  Future<void> addWeeklyGoal(String title) async {
    await _weeklyRepository.add(
      WeeklyGoal(
        id: '',
        title: title,
        weekKey: currentWeekKey,
        sortOrder: _weeklyGoals.length,
        createdAt: DateTime.now(),
      ),
    );
    await loadTasks();
  }

  Future<void> updateWeeklyGoal(WeeklyGoal goal) async {
    await _weeklyRepository.update(goal);
    await loadTasks();
  }

  Future<void> deleteWeeklyGoal(String id) async {
    await _weeklyRepository.delete(id);
    await loadTasks();
  }

  Future<void> toggleWeeklyGoal(String id) async {
    await _weeklyRepository.toggleComplete(id);
    await loadTasks();
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
