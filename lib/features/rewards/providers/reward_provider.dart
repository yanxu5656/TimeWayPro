import 'package:flutter/material.dart';

import '../data/models/reward_product.dart';
import '../data/repositories/reward_repository.dart';

class RewardProvider extends ChangeNotifier {
  final RewardRepository _repository;
  int _generation = 0;
  List<RewardProduct> _products = <RewardProduct>[];
  List<InventoryItem> _inventory = <InventoryItem>[];
  List<CoinTransaction> _transactions = <CoinTransaction>[];
  bool _isLoading = false;

  RewardProvider({RewardRepository? repository})
    : _repository = repository ?? RewardRepository();

  List<RewardProduct> get products => _products;
  List<InventoryItem> get inventory => _inventory;
  List<CoinTransaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  int get balance => _transactions.fold<int>(
    0,
    (int sum, CoinTransaction item) => sum + item.amount,
  );
  int get inventoryCount => _inventory.fold<int>(
    0,
    (int sum, InventoryItem item) => sum + item.quantity,
  );

  int purchasedCount(String productId) => _inventory
      .where((InventoryItem item) => item.productId == productId)
      .fold<int>(0, (int sum, InventoryItem item) => sum + item.acquiredCount);

  Future<void> load() async {
    final int generation = ++_generation;
    _isLoading = true;
    notifyListeners();
    try {
      final results = await Future.wait<Object>(<Future<Object>>[
        _repository.getProducts(),
        _repository.getInventory(),
        _repository.getTransactions(),
      ]);
      if (generation != _generation) return;
      _products = results[0] as List<RewardProduct>;
      _inventory = results[1] as List<InventoryItem>;
      _transactions = results[2] as List<CoinTransaction>;
    } finally {
      if (generation == _generation) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> saveProduct(RewardProduct product) async {
    await _repository.saveProduct(product);
    await load();
  }

  Future<void> deleteProduct(String id) async {
    await _repository.deleteProduct(id);
    await load();
  }

  Future<void> purchase(String id) async {
    await _repository.purchase(id);
    await load();
  }

  Future<void> fulfill(String id) async {
    await _repository.fulfill(id);
    await load();
  }
}
