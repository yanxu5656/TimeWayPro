import 'package:flutter/material.dart';
import '../data/models/plan.dart';
import '../data/repositories/plan_repository.dart';

class PlanProvider extends ChangeNotifier {
  PlanProvider({PlanRepository? repository})
    : _repository = repository ?? PlanRepository();

  final PlanRepository _repository;
  int _loadGeneration = 0;
  bool _disposed = false;

  List<Plan> _allPlans = [];
  bool _isLoading = false;

  List<Plan> get allPlans => _allPlans;
  bool get isLoading => _isLoading;

  List<Plan> get rootPlans =>
      _allPlans.where((p) => p.parentId == null).toList();

  List<Plan> getChildPlans(String parentId) =>
      _allPlans.where((p) => p.parentId == parentId).toList();

  Future<void> loadPlans() async {
    final int generation = ++_loadGeneration;
    _isLoading = true;
    notifyListeners();

    try {
      final List<Plan> plans = await _repository.getAllPlans();
      if (_disposed || generation != _loadGeneration) return;
      _allPlans = plans;
    } catch (e) {
      if (!_disposed && generation == _loadGeneration) {
        debugPrint('Error loading plans: $e');
      }
    } finally {
      if (!_disposed && generation == _loadGeneration) {
        _isLoading = false;
        notifyListeners();
      }
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

  @override
  void dispose() {
    _disposed = true;
    _loadGeneration++;
    super.dispose();
  }
}
