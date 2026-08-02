import 'package:uuid/uuid.dart';
import '../../../../shared/database/database_helper.dart';
import '../models/task.dart';
import '../models/task_record.dart';

class TaskRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _uuid = const Uuid();

  // ==================== 任务 CRUD ====================

  Future<List<Task>> getAllTasks() async {
    final maps = await _dbHelper.query('tasks');
    return maps.map((map) => Task.fromMap(map)).toList();
  }

  Future<List<Task>> getActiveTasks() async {
    final maps = await _dbHelper.queryWhere(
      'tasks',
      (map) => map['is_completed'] == 0,
    );
    return maps.map((map) => Task.fromMap(map)).toList();
  }

  Future<Task?> getTaskById(String id) async {
    final maps = await _dbHelper.queryWhere(
      'tasks',
      (map) => map['id'] == id,
    );
    if (maps.isEmpty) return null;
    return Task.fromMap(maps.first);
  }

  Future<String> insertTask(Task task) async {
    final id = task.id.isEmpty ? _uuid.v4() : task.id;
    final newTask = task.copyWith(id: id);
    await _dbHelper.insert('tasks', newTask.toMap());
    return id;
  }

  Future<void> updateTask(Task task) async {
    await _dbHelper.update(
      'tasks',
      task.copyWith(updatedAt: DateTime.now()).toMap(),
      'id',
    );
  }

  Future<void> deleteTask(String id) async {
    await _dbHelper.delete('tasks', 'id', id);
    // 删除相关记录
    await _dbHelper.deleteWhere(
      'task_records',
      (map) => map['task_id'] == id,
    );
  }

  Future<void> completeTask(String taskId) async {
    final task = await getTaskById(taskId);
    if (task == null) return;

    if (task.repeatType == RepeatType.none) {
      await updateTask(task.copyWith(
        isCompleted: true,
        completedCount: task.completedCount + 1,
        lastCompletedDate: DateTime.now(),
      ));
    } else {
      await updateTask(task.copyWith(
        completedCount: task.completedCount + 1,
        lastCompletedDate: DateTime.now(),
      ));
    }
  }

  // ==================== 任务记录 CRUD ====================

  Future<List<TaskRecord>> getRecordsByTaskId(String taskId) async {
    final maps = await _dbHelper.queryWhere(
      'task_records',
      (map) => map['task_id'] == taskId,
    );
    return maps.map((map) => TaskRecord.fromMap(map)).toList();
  }

  Future<List<TaskRecord>> getRecordsByDateRange(
      DateTime start, DateTime end) async {
    final maps = await _dbHelper.queryWhere(
      'task_records',
      (map) {
        final startTime = DateTime.parse(map['start_time']);
        // 使用 !isBefore 来包含 start 时刻
        return !startTime.isBefore(start) && startTime.isBefore(end);
      },
    );
    return maps.map((map) => TaskRecord.fromMap(map)).toList();
  }

  Future<List<TaskRecord>> getAllRecords() async {
    final maps = await _dbHelper.query('task_records');
    return maps.map((map) => TaskRecord.fromMap(map)).toList();
  }

  Future<String> insertRecord(TaskRecord record) async {
    final id = record.id.isEmpty ? _uuid.v4() : record.id;
    final newRecord = record.copyWith(id: id);
    await _dbHelper.insert('task_records', newRecord.toMap());
    return id;
  }

  Future<void> updateRecord(TaskRecord record) async {
    await _dbHelper.update('task_records', record.toMap(), 'id');
  }

  Future<void> deleteRecord(String id) async {
    await _dbHelper.delete('task_records', 'id', id);
  }

  // ==================== 统计方法 ====================

  Future<int> getTotalDurationByDateRange(
      DateTime start, DateTime end) async {
    final records = await getRecordsByDateRange(start, end);
    int total = 0;
    for (var record in records) {
      total += record.duration;
    }
    return total;
  }

  Future<int> getCompletedTaskCountByDateRange(
      DateTime start, DateTime end) async {
    final records = await getRecordsByDateRange(start, end);
    final taskIds = records.map((r) => r.taskId).toSet();
    return taskIds.length;
  }

  Future<List<Map<String, dynamic>>> getTaskDurationSummary(
      DateTime start, DateTime end) async {
    final records = await getRecordsByDateRange(start, end);
    final tasks = await getAllTasks();
    final taskMap = {for (var t in tasks) t.id: t};

    Map<String, int> durationMap = {};
    for (var record in records) {
      durationMap[record.taskId] =
          (durationMap[record.taskId] ?? 0) + record.duration;
    }

    List<Map<String, dynamic>> result = [];
    durationMap.forEach((taskId, duration) {
      final task = taskMap[taskId];
      if (task != null) {
        result.add({
          'title': task.title,
          'total_duration': duration,
        });
      }
    });

    result.sort((a, b) =>
        (b['total_duration'] as int).compareTo(a['total_duration'] as int));
    return result;
  }

  Future<Map<String, int>> getDailyDurationMap(
      DateTime start, DateTime end) async {
    final records = await getRecordsByDateRange(start, end);
    Map<String, int> map = {};

    for (var record in records) {
      final dateStr = record.startTime.toIso8601String().substring(0, 10);
      map[dateStr] = (map[dateStr] ?? 0) + record.duration;
    }
    return map;
  }

  // ==================== 数据导入导出 ====================

  Future<Map<String, dynamic>> exportAllData() async {
    return await _dbHelper.exportAll();
  }

  Future<void> importAllData(Map<String, dynamic> data) async {
    await _dbHelper.importAll(data);
  }
}
