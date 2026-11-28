import 'package:uuid/uuid.dart';

import '../../../../shared/database/database_helper.dart';
import '../../../weekly/data/models/weekly_goal.dart';
import '../models/reward_product.dart';

class RewardRepository {
  final DatabaseHelper _db = DatabaseHelper();
  final Uuid _uuid = const Uuid();

  static const List<Map<String, Object>> _defaults = <Map<String, Object>>[
    <String, Object>{
      'id': 'default-movie',
      'title': '看一场电影',
      'description': '留一个完整的晚上，好好放松。',
      'icon': 'movie',
      'price': 80,
    },
    <String, Object>{
      'id': 'default-coffee',
      'title': '一杯喜欢的咖啡',
      'description': '给自己一杯犒赏。',
      'icon': 'coffee',
      'price': 30,
    },
    <String, Object>{
      'id': 'default-game',
      'title': '痛快玩两小时游戏',
      'description': '不设闹钟，尽情享受。',
      'icon': 'game',
      'price': 60,
    },
    <String, Object>{
      'id': 'default-dayoff',
      'title': '休息一整天',
      'description': '放下待办，做真正想做的事。',
      'icon': 'rest',
      'price': 300,
    },
  ];

  static List<Map<String, dynamic>> _defaultRows(DateTime now) {
    return <Map<String, dynamic>>[
      for (int i = 0; i < _defaults.length; i++)
        <String, dynamic>{
          ..._defaults[i],
          'stock': null,
          'purchase_limit': null,
          'is_active': 1,
          'sort_order': i,
          'created_at': now.toIso8601String(),
        },
    ];
  }

  Future<void> ensureCatalog() async {
    await _db.transaction<void>((Map<String, dynamic> data) {
      final List<dynamic> meta = data['reward_meta'] as List;
      if (meta.any((dynamic row) => row['id'] == 'catalog_seeded')) return;
      final List<dynamic> products = data['reward_products'] as List;
      products.addAll(_defaultRows(DateTime.now()));
      meta.add(<String, dynamic>{'id': 'catalog_seeded', 'value': 1});
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

  Future<List<RewardProduct>> getProducts({
    bool includeInactive = false,
  }) async {
    final List<Map<String, dynamic>> rows = await _db.query('reward_products');
    final List<Map<String, dynamic>> source = rows.isEmpty
        ? _defaultRows(DateTime.now())
        : rows;
    final products = source
        .map((Map<String, dynamic> row) => RewardProduct.fromMap(row))
        .where((RewardProduct product) => includeInactive || product.isActive)
        .toList();
    products.sort((RewardProduct a, RewardProduct b) {
      if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
      return a.sortOrder.compareTo(b.sortOrder);
    });
    return products;
  }

  Future<List<InventoryItem>> getInventory() async {
    final rows = await _db.query('reward_inventory');
    final items = rows
        .map((Map<String, dynamic> row) => InventoryItem.fromMap(row))
        .where((InventoryItem item) => item.quantity > 0 || item.usedCount > 0)
        .toList();
    items.sort(
      (InventoryItem a, InventoryItem b) => b.updatedAt.compareTo(a.updatedAt),
    );
    return items;
  }

  Future<List<CoinTransaction>> getTransactions() async {
    final rows = await _db.query('coin_transactions');
    final items = rows
        .map((Map<String, dynamic> row) => CoinTransaction.fromMap(row))
        .toList();
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
    await ensureCatalog();
    await _db.transaction<void>((Map<String, dynamic> data) {
      final List<dynamic> products = data['reward_products'] as List;
      final int index = products.indexWhere(
        (dynamic row) => row['id'] == product.id,
      );
      if (index >= 0) {
        products[index] = product.toMap();
      } else {
        products.add(product.toMap());
      }
    });
  }

  Future<void> archiveProduct(String id) async {
    await _db.transaction<void>((Map<String, dynamic> data) {
      final List<dynamic> products = data['reward_products'] as List;
      final int index = products.indexWhere((dynamic row) => row['id'] == id);
      if (index < 0) throw StateError('奖励不存在');
      final Map<String, dynamic> row = Map<String, dynamic>.from(
        products[index] as Map,
      );
      row['is_active'] = 0;
      products[index] = row;
    });
  }

  Future<void> restoreProduct(String id) async {
    await _db.transaction<void>((Map<String, dynamic> data) {
      final List<dynamic> products = data['reward_products'] as List;
      final int index = products.indexWhere((dynamic row) => row['id'] == id);
      if (index < 0) throw StateError('奖励不存在');
      final Map<String, dynamic> row = Map<String, dynamic>.from(
        products[index] as Map,
      );
      row['is_active'] = 1;
      products[index] = row;
    });
  }

  Future<void> purchase(String productId) async {
    await ensureCatalog();
    await _db.transaction<void>((Map<String, dynamic> data) {
      final List<dynamic> products = data['reward_products'] as List;
      final int index = products.indexWhere(
        (dynamic row) => row['id'] == productId,
      );
      if (index < 0) throw StateError('奖励不存在');
      final Map<String, dynamic> row = Map<String, dynamic>.from(
        products[index] as Map,
      );
      if (row['is_active'] != 1) throw StateError('该奖励已下架');
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
