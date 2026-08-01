import 'package:uuid/uuid.dart';
import '../../../../shared/database/database_helper.dart';
import '../models/plan.dart';

class PlanRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _uuid = const Uuid();

  Future<List<Plan>> getAllPlans() async {
    final maps = await _dbHelper.query('plans');
    return maps.map((map) => Plan.fromMap(map)).toList();
  }

  Future<List<Plan>> getRootPlans() async {
    final maps = await _dbHelper.queryWhere(
      'plans',
      (map) => map['parent_id'] == null,
    );
    return maps.map((map) => Plan.fromMap(map)).toList();
  }

  Future<List<Plan>> getChildPlans(String parentId) async {
    final maps = await _dbHelper.queryWhere(
      'plans',
      (map) => map['parent_id'] == parentId,
    );
    return maps.map((map) => Plan.fromMap(map)).toList();
  }

  Future<Plan?> getPlanById(String id) async {
    final maps = await _dbHelper.queryWhere(
      'plans',
      (map) => map['id'] == id,
    );
    if (maps.isEmpty) return null;
    return Plan.fromMap(maps.first);
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
    // 获取所有子计划并递归删除
    final children = await getChildPlans(id);
    for (var child in children) {
      await deletePlan(child.id);
    }
    await _dbHelper.delete('plans', 'id', id);
  }

  Future<void> updateProgress(String id, double progress) async {
    final plan = await getPlanById(id);
    if (plan == null) return;
    await updatePlan(plan.copyWith(progress: progress));
  }

  Future<List<Plan>> getPlanTree() async {
    return await getRootPlans();
  }
}
