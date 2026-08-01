import 'package:flutter/material.dart';
import '../data/models/plan.dart';
import '../data/repositories/plan_repository.dart';

class PlanProvider extends ChangeNotifier {
  final PlanRepository _repository = PlanRepository();

  List<Plan> _allPlans = [];
  bool _isLoading = false;

  List<Plan> get allPlans => _allPlans;
  bool get isLoading => _isLoading;

  List<Plan> get rootPlans =>
      _allPlans.where((p) => p.parentId == null).toList();

  List<Plan> getChildPlans(String parentId) =>
      _allPlans.where((p) => p.parentId == parentId).toList();

  Future<void> loadPlans() async {
    _isLoading = true;
    notifyListeners();

    try {
      _allPlans = await _repository.getAllPlans();
    } catch (e) {
      debugPrint('Error loading plans: $e');
      _allPlans = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addPlan(Plan plan) async {
    await _repository.insertPlan(plan);
    await loadPlans();
  }

  Future<void> updatePlan(Plan plan) async {
    await _repository.updatePlan(plan);
    await loadPlans();
  }

  Future<void> deletePlan(String id) async {
    await _repository.deletePlan(id);
    await loadPlans();
  }

  Future<void> updateProgress(String id, double progress) async {
    await _repository.updateProgress(id, progress);
    await loadPlans();
  }
}
