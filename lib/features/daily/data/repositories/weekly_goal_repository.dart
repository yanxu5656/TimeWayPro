import 'package:uuid/uuid.dart';

import '../../../../shared/database/database_helper.dart';
import '../models/weekly_goal.dart';

/// 本周目标的存取。
///
/// 表结构、id 生成方式、CRUD 写法都照 `daily_repository.dart` 的样板。
class WeeklyGoalRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _uuid = const Uuid();

  static const String _table = 'weekly_goals';

  /// 取某一周的目标，按 sortOrder 排序
  Future<List<WeeklyGoal>> getByWeek(String weekKey) async {
    try {
      final maps = await _dbHelper.queryWhere(
        _table,
        (map) => map['week_key'] == weekKey,
      );
      final goals = maps.map(WeeklyGoal.fromMap).toList();
      goals.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return goals;
    } catch (e) {
      print('Error getting weekly goals: $e');
      return [];
    }
  }

  Future<String> add(WeeklyGoal goal) async {
    final id = goal.id.isEmpty ? _uuid.v4() : goal.id;
    await _dbHelper.insert(_table, goal.copyWith(id: id).toMap());
    return id;
  }

  Future<void> update(WeeklyGoal goal) async {
    await _dbHelper.update(_table, goal.toMap(), 'id');
  }

  Future<void> delete(String id) async {
    await _dbHelper.delete(_table, 'id', id);
  }

  Future<void> toggleComplete(String id) async {
    final maps = await _dbHelper.queryWhere(_table, (map) => map['id'] == id);
    if (maps.isEmpty) return;
    final goal = WeeklyGoal.fromMap(maps.first);
    await update(goal.copyWith(isCompleted: !goal.isCompleted));
  }
}
