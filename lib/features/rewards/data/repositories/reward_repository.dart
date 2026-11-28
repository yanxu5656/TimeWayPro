import 'package:uuid/uuid.dart';

import '../../../../shared/database/database_helper.dart';
import '../../../weekly/data/models/weekly_goal.dart';
import '../models/reward_product.dart';

class RewardRepository {
  final DatabaseHelper _db = DatabaseHelper();
  final Uuid _uuid = const Uuid();

  static const Set<String> _legacyProductIds = <String>{
    'default-movie',
    'default-coffee',
    'default-game',
    'default-dayoff',
  };

  Future<void> _removeLegacyCatalog() async {
    await _db.transaction<void>((Map<String, dynamic> data) {
      (data['reward_products'] as List).removeWhere(
        (dynamic row) => _legacyProductIds.contains(row['id']),
      );
      data.remove('reward_meta');
    });
  }

  Future<WeeklyGoal> updateWeeklyGoal(WeeklyGoal updated) {
    return _db.transaction<WeeklyGoal>((Map<String, dynamic> data) {
      final List<dynamic> goals = data['weekly_goals'] as List;
      final int index = goals.indexWhere(
        (dynamic row) => row['id'] == updated.id,
      );
      if (index < 0) throw StateError('目标不存在');
      final WeeklyGoal current = WeeklyGoal.fromMap(
        Map<String, dynamic>.from(goals[index] as Map),
      );
      final int reward = current.rewardClaimedAt == null
          ? updated.coinReward
          : current.coinReward;
      DateTime? claimedAt = current.rewardClaimedAt;
      if (!current.isCompleted &&
          updated.isCompleted &&
          claimedAt == null &&
          reward > 0) {
        final List<dynamic> ledger = data['coin_transactions'] as List;
        final String transactionId = 'weekly_${updated.id}';
        if (!ledger.any((dynamic row) => row['id'] == transactionId)) {
          final DateTime now = DateTime.now();
          ledger.add(<String, dynamic>{
            'id': transactionId,
            'amount': reward,
            'type': 'weekly_reward',
            'title': '完成目标：${updated.title}',
            'reference_id': updated.id,
            'created_at': now.toIso8601String(),
          });
          claimedAt = now;
        }
      }
      final WeeklyGoal stored = WeeklyGoal(
        id: updated.id,
        title: updated.title,
        isCompleted: updated.isCompleted,
        weekKey: updated.weekKey,
        sortOrder: updated.sortOrder,
        createdAt: updated.createdAt,
        progressMode: updated.progressMode,
        milestones: updated.milestones,
        coinReward: reward,
        rewardClaimedAt: claimedAt,
      );
      goals[index] = stored.toMap();
      return stored;
    });
  }

  Future<List<RewardProduct>> getProducts() async {
    final List<Map<String, dynamic>> rows = await _db.query('reward_products');
    if (rows.any(
      (Map<String, dynamic> row) => _legacyProductIds.contains(row['id']),
    )) {
      await _removeLegacyCatalog();
      return getProducts();
    }
    final List<RewardProduct> products = rows
        .map(RewardProduct.fromMap)
        .toList();
    products.sort(
      (RewardProduct a, RewardProduct b) => a.sortOrder.compareTo(b.sortOrder),
    );
    return products;
  }

  Future<List<InventoryItem>> getInventory() async {
    final rows = await _db.query('reward_inventory');
    final items = rows
        .map(InventoryItem.fromMap)
        .where((InventoryItem item) => item.quantity > 0 || item.usedCount > 0)
        .toList();
    items.sort(
      (InventoryItem a, InventoryItem b) => b.updatedAt.compareTo(a.updatedAt),
    );
    return items;
  }

  Future<List<CoinTransaction>> getTransactions() async {
    final rows = await _db.query('coin_transactions');
    final items = rows.map(CoinTransaction.fromMap).toList();
    items.sort(
      (CoinTransaction a, CoinTransaction b) =>
          b.createdAt.compareTo(a.createdAt),
    );
    return items;
  }

  Future<void> saveProduct(RewardProduct product) async {
    if (product.title.trim().isEmpty) throw ArgumentError('请填写奖励名称');
    if (product.price < 1 || product.price > 999999) {
      throw ArgumentError('价格需在 1–999999 金币之间');
    }
    if (product.stock != null && product.stock! < 0) {
      throw ArgumentError('库存不能为负数');
    }
    if (product.purchaseLimit != null && product.purchaseLimit! < 1) {
      throw ArgumentError('限购次数至少为 1');
    }
    await _db.transaction<void>((Map<String, dynamic> data) {
      final List<dynamic> products = data['reward_products'] as List;
      final int index = products.indexWhere(
        (dynamic row) => row['id'] == product.id,
      );
      final Map<String, dynamic> row = product.toMap()..['is_active'] = 1;
      if (index >= 0) {
        products[index] = row;
      } else {
        products.add(row);
      }
    });
  }

  Future<void> deleteProduct(String id) async {
    await _db.transaction<void>((Map<String, dynamic> data) {
      final List<dynamic> products = data['reward_products'] as List;
      final int index = products.indexWhere((dynamic row) => row['id'] == id);
      if (index < 0) throw StateError('奖励不存在');
      products.removeAt(index);
    });
  }

  Future<void> purchase(String productId) async {
    await _db.transaction<void>((Map<String, dynamic> data) {
      final List<dynamic> products = data['reward_products'] as List;
      final int index = products.indexWhere(
        (dynamic row) => row['id'] == productId,
      );
      if (index < 0) throw StateError('奖励不存在');
      final Map<String, dynamic> row = Map<String, dynamic>.from(
        products[index] as Map,
      );
      final RewardProduct product = RewardProduct.fromMap(row);
      if (product.stock != null && product.stock! < 1) {
        throw StateError('该奖励已兑完');
      }
      final List<dynamic> inventory = data['reward_inventory'] as List;
      final int inventoryIndex = inventory.indexWhere(
        (dynamic item) => item['product_id'] == productId,
      );
      final InventoryItem? existing = inventoryIndex < 0
          ? null
          : InventoryItem.fromMap(
              Map<String, dynamic>.from(inventory[inventoryIndex] as Map),
            );
      final int acquired = (existing?.acquiredCount ?? 0) + 1;
      if (product.purchaseLimit != null && acquired > product.purchaseLimit!) {
        throw StateError('已达到该奖励的限购次数');
      }
      final List<dynamic> ledger = data['coin_transactions'] as List;
      final int balance = _balance(ledger);
      if (balance < product.price) throw StateError('金币不足');
      final DateTime now = DateTime.now();
      final String id = _uuid.v4();
      if (product.stock != null) row['stock'] = product.stock! - 1;
      products[index] = row;
      final InventoryItem acquiredItem = InventoryItem(
        productId: productId,
        title: product.title,
        icon: product.icon,
        quantity: (existing?.quantity ?? 0) + 1,
        acquiredCount: acquired,
        usedCount: existing?.usedCount ?? 0,
        updatedAt: now,
      );
      if (inventoryIndex < 0) {
        inventory.add(acquiredItem.toMap());
      } else {
        inventory[inventoryIndex] = acquiredItem.toMap();
      }
      ledger.add(<String, dynamic>{
        'id': id,
        'amount': -product.price,
        'type': 'purchase',
        'title': '兑换：${product.title}',
        'reference_id': productId,
        'created_at': now.toIso8601String(),
      });
    });
  }

  Future<void> fulfill(String productId) async {
    await _db.transaction<void>((Map<String, dynamic> data) {
      final List<dynamic> inventory = data['reward_inventory'] as List;
      final int index = inventory.indexWhere(
        (dynamic item) => item['product_id'] == productId,
      );
      if (index < 0) throw StateError('仓库中没有该奖励');
      final InventoryItem item = InventoryItem.fromMap(
        Map<String, dynamic>.from(inventory[index] as Map),
      );
      if (item.quantity < 1) throw StateError('该奖励已全部兑现');
      final DateTime now = DateTime.now();
      inventory[index] = InventoryItem(
        productId: item.productId,
        title: item.title,
        icon: item.icon,
        quantity: item.quantity - 1,
        acquiredCount: item.acquiredCount,
        usedCount: item.usedCount + 1,
        updatedAt: now,
      ).toMap();
      (data['coin_transactions'] as List).add(<String, dynamic>{
        'id': _uuid.v4(),
        'amount': 0,
        'type': 'fulfill',
        'title': '兑现：${item.title}',
        'reference_id': productId,
        'created_at': now.toIso8601String(),
      });
    });
  }

  static int _balance(List<dynamic> ledger) => ledger.fold<int>(
    0,
    (int sum, dynamic row) => sum + ((row['amount'] as num?)?.toInt() ?? 0),
  );
}
