import 'package:uuid/uuid.dart';
import '../../../../shared/database/database_helper.dart';
import '../models/daily_task.dart';

class DailyRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _uuid = const Uuid();

  // 获取指定日期的任务
  Future<List<DailyTask>> getTasksByDate(String dateKey) async {
    try {
      final maps = await _dbHelper.queryWhere(
        'daily_tasks',
        (map) => map['date_key'] == dateKey,
      );
      final tasks = maps.map((map) => DailyTask.fromMap(map)).toList();
      // 按时间段和排序顺序分组
      tasks.sort((a, b) {
        if (a.timePeriod.index != b.timePeriod.index) {
          return a.timePeriod.index.compareTo(b.timePeriod.index);
        }
        return a.sortOrder.compareTo(b.sortOrder);
      });
      return tasks;
    } catch (e) {
      print('Error getting daily tasks: $e');
      return [];
    }
  }

  // 添加任务
  Future<String> addTask(DailyTask task) async {
    final id = task.id.isEmpty ? _uuid.v4() : task.id;
    final newTask = task.copyWith(id: id);
    await _dbHelper.insert('daily_tasks', newTask.toMap());
    return id;
  }

  // 更新任务
  Future<void> updateTask(DailyTask task) async {
    await _dbHelper.update('daily_tasks', task.toMap(), 'id');
  }

  // 删除任务
  Future<void> deleteTask(String id) async {
    await _dbHelper.delete('daily_tasks', 'id', id);
  }

  // 切换完成状态
  Future<void> toggleComplete(String id) async {
    final maps = await _dbHelper.queryWhere(
      'daily_tasks',
      (map) => map['id'] == id,
    );
    if (maps.isNotEmpty) {
      final task = DailyTask.fromMap(maps.first);
      await updateTask(task.copyWith(isCompleted: !task.isCompleted));
    }
  }

  // 获取指定日期的统计
  Future<Map<String, int>> getStatsByDate(String dateKey) async {
    final tasks = await getTasksByDate(dateKey);
    final total = tasks.length;
    final completed = tasks.where((t) => t.isCompleted).length;
    return {'total': total, 'completed': completed};
  }
}
