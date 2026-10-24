import 'package:flutter/material.dart';

import '../../../core/utils/week.dart';
import '../data/models/weekly_goal.dart';
import '../data/repositories/weekly_goal_repository.dart';

/// 每周目标页的状态：当前浏览哪一周 + 该周的目标列表。
///
/// `_weekAnchor` 永远归一为周一（[startOfWeek]）。所有增删改都落在
/// **当前浏览的周**上——「翻到下周再添加」就是提前列下周的计划，
/// 「翻回旧周」就能回看并继续编辑历史目标。
class WeeklyProvider extends ChangeNotifier {
  final WeeklyGoalRepository _repository = WeeklyGoalRepository();

  DateTime _weekAnchor = startOfWeek(DateTime.now());
  List<WeeklyGoal> _goals = [];
  bool _isLoading = false;

  DateTime get selectedWeekStart => _weekAnchor;

  String get selectedWeekKey => weekKeyOf(_weekAnchor);

  /// 是否正浏览真实意义上的本周。对 `DateTime.now()` 现算而不是记一个
  /// bool：应用开着跨过周日午夜后，旧 anchor 会自动变成「上周」。
  bool get isCurrentWeek => weekKeyOf(DateTime.now()) == selectedWeekKey;

  List<WeeklyGoal> get goals => _goals;
  bool get isLoading => _isLoading;

  int get total => _goals.length;
  int get completed => _goals.where((g) => g.isCompleted).length;
  double get progress => total > 0 ? completed / total : 0;

  // ── 周导航 ──

  void previousWeek() =>
      selectWeek(_weekAnchor.subtract(const Duration(days: 7)));

  void nextWeek() => selectWeek(_weekAnchor.add(const Duration(days: 7)));

  /// 跳到 [date] 所在的周。传周内任意一天都会归一到周一。
  void selectWeek(DateTime date) {
    _weekAnchor = startOfWeek(date);
    loadGoals();
  }

  void goToCurrentWeek() => selectWeek(DateTime.now());

  // ── 加载 ──

  Future<void> loadGoals() async {
    _isLoading = true;
    notifyListeners();

    try {
      _goals = await _repository.getByWeek(selectedWeekKey);
    } catch (e) {
      debugPrint('Error loading weekly goals: $e');
      _goals = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── 增删改（都落在当前浏览的周）──

  Future<void> addGoal(String title) async {
    await _repository.add(
      WeeklyGoal(
        id: '',
        title: title,
        weekKey: selectedWeekKey,
        sortOrder: _goals.length,
        createdAt: DateTime.now(),
      ),
    );
    await loadGoals();
  }

  Future<void> updateGoal(WeeklyGoal goal) async {
    await _repository.update(goal);
    await loadGoals();
  }

  Future<void> deleteGoal(String id) async {
    // 乐观删除：Dismissible 的滑动动画结束后行已经从视觉上消失，
    // 这里先同步更新状态让 UI 立即一致，再走持久化。
    // （onDismissed 在动画播完才触发，时序上晚于用户手势。）
    _goals = _goals.where((WeeklyGoal g) => g.id != id).toList();
    notifyListeners();
    await _repository.delete(id);
    await loadGoals();
  }

  Future<void> toggleGoal(String id) async {
    await _repository.toggleComplete(id);
    await loadGoals();
  }

  /// 把 [goal] 挪到 [targetWeekKey] 对应的周，排到目标周队尾
  /// （不动目标周现有条目的顺序）。目标周就是所在周时视作无操作。
  Future<void> moveGoalToWeek(
    WeeklyGoal goal,
    String targetWeekKey,
  ) async {
    if (goal.weekKey == targetWeekKey) return;
    final List<WeeklyGoal> targetGoals =
        await _repository.getByWeek(targetWeekKey);
    final int maxOrder = targetGoals.fold<int>(
      -1,
      (int max, WeeklyGoal g) => g.sortOrder > max ? g.sortOrder : max,
    );
    await _repository.update(
      goal.copyWith(weekKey: targetWeekKey, sortOrder: maxOrder + 1),
    );
    await loadGoals();
  }
}
