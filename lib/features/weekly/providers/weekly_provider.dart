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

  // 用构造函数日运算而不是 ±Duration(7 days)：Duration 是绝对时间
  // 运算，DST 切换周会差 1 小时，锚点又是本地 00:00，落点会掉到
  // 前一天 23:00——翻周直接跳过一周或原地不动。
  void previousWeek() => selectWeek(
    DateTime(_weekAnchor.year, _weekAnchor.month, _weekAnchor.day - 7),
  );

  void nextWeek() => selectWeek(
    DateTime(_weekAnchor.year, _weekAnchor.month, _weekAnchor.day + 7),
  );

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
        // 队尾追加取 max+1：用 _goals.length 在删除过条目后会与现存
        // sortOrder 重复，非稳定排序下条目顺序每次加载可能变化
        sortOrder: _maxSortOrder + 1,
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

  /// 拖拽排序：把 [oldIndex] 的条目移到 [newIndex]（移除后的最终下标，
  /// 与 ReorderableListView.onReorderItem 的语义一致）。
  ///
  /// 整周重编号成 0..n-1 而不是只改被拖的那一条：sort_order 保持连续，
  /// 队尾追加取的 max+1 才不会与现存值撞车。
  ///
  /// 不走 [loadGoals]——它会把 isLoading 置真，整张列表在拖完的瞬间
  /// 被替换成加载圈。这里乐观更新 + 落盘，顺序在磁盘上已经是最终态。
  Future<void> reorderGoals(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;
    final List<WeeklyGoal> reordered = List<WeeklyGoal>.from(_goals);
    final WeeklyGoal moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    _goals = <WeeklyGoal>[
      for (final (int i, WeeklyGoal g) in reordered.indexed)
        g.copyWith(sortOrder: i),
    ];
    notifyListeners();
    await _repository.reorder(_goals);
  }

  int get _maxSortOrder => _goals.fold<int>(
    -1,
    (int max, WeeklyGoal g) => g.sortOrder > max ? g.sortOrder : max,
  );

  /// 把 [goal] 挪到 [targetWeekKey] 对应的周，排到目标周队尾
  /// （不动目标周现有条目的顺序）。目标周就是所在周时视作无操作。
  Future<void> moveGoalToWeek(WeeklyGoal goal, String targetWeekKey) async {
    if (goal.weekKey == targetWeekKey) return;
    final List<WeeklyGoal> targetGoals = await _repository.getByWeek(
      targetWeekKey,
    );
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
