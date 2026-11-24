import 'package:uuid/uuid.dart';
import '../../../../core/utils/row_parse.dart';
import '../../../../shared/database/database_helper.dart';
import '../models/plan.dart';

class PlanRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _uuid = const Uuid();

  Future<List<Plan>> getAllPlans() async {
    final maps = await _dbHelper.query('plans');
    return parseRows(maps, Plan.fromMap);
  }

  Future<List<Plan>> getRootPlans() async {
    final maps = await _dbHelper.queryWhere(
      'plans',
      (map) => map['parent_id'] == null,
    );
    return parseRows(maps, Plan.fromMap);
  }

  Future<List<Plan>> getChildPlans(String parentId) async {
    final maps = await _dbHelper.queryWhere(
      'plans',
      (map) => map['parent_id'] == parentId,
    );
    return parseRows(maps, Plan.fromMap);
  }

  Future<Plan?> getPlanById(String id) async {
    final maps = await _dbHelper.queryWhere('plans', (map) => map['id'] == id);
    if (maps.isEmpty) return null;
    return parseRows(maps, Plan.fromMap).firstOrNull;
  }

  Future<String> insertPlan(Plan plan) async {
    final id = plan.id.isEmpty ? _uuid.v4() : plan.id;
    final newPlan = plan.copyWith(id: id);
    await _dbHelper.insert('plans', newPlan.toMap());
    return id;
  }

  Future<void> updatePlan(Plan plan) async {
    await _dbHelper.update(
      'plans',
      plan.copyWith(updatedAt: DateTime.now()).toMap(),
      'id',
    );
  }

  Future<void> deletePlan(String id) async {
    final plans = await getAllPlans();
    final byParent = <String?, List<Plan>>{};
    for (final plan in plans) {
      (byParent[plan.parentId] ??= <Plan>[]).add(plan);
    }
    final ids = <String>{id};
    final pending = <String>[id];
    while (pending.isNotEmpty) {
      final parentId = pending.removeLast();
      for (final child in byParent[parentId] ?? const <Plan>[]) {
        if (ids.add(child.id)) pending.add(child.id);
      }
    }
    // 整棵子树一次落盘，避免递归删除中途失败留下父子关系不一致的半成品。
    await _dbHelper.deleteWhere(
      'plans',
      (dynamic row) => row is Map<String, dynamic> && ids.contains(row['id']),
    );
  }

  Future<void> updateProgress(String id, double progress) async {
    if (!progress.isFinite) return;
    final plan = await getPlanById(id);
    if (plan == null) return;
    await updatePlan(
      plan.copyWith(progress: progress.clamp(0.0, 1.0).toDouble()),
    );
  }

  Future<List<Plan>> getPlanTree() async {
    return await getRootPlans();
  }
}
