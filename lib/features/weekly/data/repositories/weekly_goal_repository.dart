import 'package:uuid/uuid.dart';

import '../../../../core/utils/row_parse.dart';

import '../../../../shared/database/database_helper.dart';
import '../models/weekly_goal.dart';

/// 每周目标的存取。
///
/// 表结构、id 生成方式、CRUD 写法都照 `daily_repository.dart` 的样板。
/// [getByWeek] 接受任意 weekKey，周导航、回看旧周都走它。
class WeeklyGoalRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _uuid = const Uuid();

  static const String _table = 'weekly_goals';

  /// 取某一周的目标，按 sortOrder 排序
  Future<List<WeeklyGoal>> getByWeek(String weekKey) async {
    final maps = await _dbHelper.queryWhere(
      _table,
      (map) => map['week_key'] == weekKey,
    );
    final goals = parseRows(maps, WeeklyGoal.fromMap);
    goals.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return goals;
  }

  Future<String> add(WeeklyGoal goal) async {
    final id = goal.id.isEmpty ? _uuid.v4() : goal.id;
    await _dbHelper.insert(_table, goal.copyWith(id: id).toMap());
    return id;
  }

  Future<void> update(WeeklyGoal goal) async {
    await _dbHelper.update(_table, goal.toMap(), 'id');
  }

  /// 落盘一组目标的新 sortOrder，一次写盘。
  ///
  /// 调用方给的列表已经是排好的最终顺序（sortOrder 由调用方重编号），
  /// 这里只负责写，不再排序。
  Future<void> reorder(List<WeeklyGoal> goals) async {
    await _dbHelper.updateAll(
      _table,
      goals.map((WeeklyGoal g) => g.toMap()).toList(),
      'id',
    );
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
