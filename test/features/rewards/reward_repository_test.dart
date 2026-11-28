import 'package:flutter_test/flutter_test.dart';
import 'package:time_way_pro/features/rewards/data/models/reward_product.dart';
import 'package:time_way_pro/features/rewards/data/repositories/reward_repository.dart';
import 'package:time_way_pro/features/weekly/data/models/weekly_goal.dart';
import 'package:time_way_pro/shared/database/database_helper.dart';

import '../../support/app_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final DatabaseHelper db = DatabaseHelper();
  final RewardRepository repository = RewardRepository();

  WeeklyGoal goal({bool completed = false, int reward = 100}) => WeeklyGoal(
    id: 'goal-1',
    title: '完成一次迭代',
    weekKey: '2026-11-23',
    createdAt: DateTime(2026, 11, 23),
    isCompleted: completed,
    coinReward: reward,
  );

  RewardProduct product({int price = 80, int? stock, int? limit}) =>
      RewardProduct(
        id: 'custom',
        title: '看一场电影',
        icon: 'movie',
        price: price,
        stock: stock,
        purchaseLimit: limit,
        createdAt: DateTime(2026, 11, 28),
      );

  Future<void> seedGoal(WeeklyGoal value) async {
    await db.importAll(<String, dynamic>{
      'tasks': <dynamic>[],
      'task_records': <dynamic>[],
      'plans': <dynamic>[],
      'weekly_goals': <dynamic>[value.toMap()],
    });
  }

  Future<void> earnCoins() async {
    await seedGoal(goal());
    await repository.updateWeeklyGoal(goal(completed: true));
  }

  setUp(() {
    installPathProviderMock();
    db.resetForTesting();
  });

  test('旧目标没有金币字段时默认为无奖励', () {
    final WeeklyGoal old = WeeklyGoal.fromMap(<String, dynamic>{
      'id': 'old',
      'title': '旧目标',
      'is_completed': 1,
      'week_key': '2026-11-23',
      'created_at': DateTime(2026).toIso8601String(),
    });
    expect(old.coinReward, 0);
    expect(old.rewardClaimedAt, isNull);
  });

  test('空商店不会生成示例奖励，保存后只显示自定义奖励', () async {
    expect(await repository.getProducts(), isEmpty);
    await repository.saveProduct(product());
    final products = await repository.getProducts();
    expect(products, hasLength(1));
    expect(products.single.id, 'custom');
    expect(await db.query('reward_products'), hasLength(1));
  });

  test('完成并发更新也只发放一次金币', () async {
    await seedGoal(goal());
    final WeeklyGoal completed = goal(completed: true);
    await Future.wait<WeeklyGoal>(<Future<WeeklyGoal>>[
      repository.updateWeeklyGoal(completed),
      repository.updateWeeklyGoal(completed),
    ]);
    final transactions = await repository.getTransactions();
    expect(transactions, hasLength(1));
    expect(transactions.single.amount, 100);
    expect(transactions.single.id, 'weekly_goal-1');
  });

  test('撤销再完成、挪周和重启均不重复发奖', () async {
    await seedGoal(goal());
    await repository.updateWeeklyGoal(goal(completed: true));
    await repository.updateWeeklyGoal(goal());
    await repository.updateWeeklyGoal(goal(completed: true));
    await repository.updateWeeklyGoal(
      goal(completed: true).copyWith(weekKey: '2026-11-30'),
    );
    db.resetForTesting();
    final transactions = await repository.getTransactions();
    expect(transactions, hasLength(1));
    expect(transactions.single.amount, 100);
  });

  test('兑换原子扣款入库，重复点击不会透支', () async {
    await earnCoins();
    await repository.saveProduct(product());
    await Future.wait<void>(<Future<void>>[
      repository.purchase('custom'),
      repository.purchase('custom').catchError((Object _) {}),
    ]);
    final inventory = await repository.getInventory();
    expect(inventory, hasLength(1));
    expect(inventory.single.quantity, 1);
    expect(
      (await repository.getTransactions()).fold<int>(
        0,
        (int sum, item) => sum + item.amount,
      ),
      20,
    );
    await expectLater(repository.purchase('custom'), throwsStateError);
  });

  test('余额不足时兑换失败且不产生库存', () async {
    await earnCoins();
    await repository.saveProduct(product(price: 300));
    await expectLater(repository.purchase('custom'), throwsStateError);
    expect(await repository.getInventory(), isEmpty);
  });

  test('库存、限购和仓库兑现', () async {
    await earnCoins();
    await repository.saveProduct(product(price: 30, stock: 1, limit: 1));
    await repository.purchase('custom');
    await expectLater(repository.purchase('custom'), throwsStateError);
    expect((await repository.getInventory()).single.quantity, 1);
    await repository.fulfill('custom');
    final InventoryItem used = (await repository.getInventory()).single;
    expect(used.quantity, 0);
    expect(used.usedCount, 1);
    await expectLater(repository.fulfill('custom'), throwsStateError);
  });

  test('删除真实奖励成功且保留仓库和流水', () async {
    await earnCoins();
    await repository.saveProduct(product());
    await repository.purchase('custom');
    await repository.deleteProduct('custom');
    expect(await repository.getProducts(), isEmpty);
    expect((await repository.getInventory()).single.quantity, 1);
    expect(await repository.getTransactions(), hasLength(2));
    await expectLater(repository.fulfill('custom'), completes);
    await expectLater(repository.deleteProduct('custom'), throwsStateError);
  });

  test('升级清理旧示例奖励但保留自定义商品、仓库和流水', () async {
    final DateTime now = DateTime(2026, 11, 28);
    await db.importAll(<String, dynamic>{
      'tasks': <dynamic>[],
      'task_records': <dynamic>[],
      'plans': <dynamic>[],
      'reward_products': <dynamic>[
        <String, dynamic>{
          'id': 'default-movie',
          'title': '看一场电影',
          'icon': 'movie',
          'price': 80,
          'is_active': 1,
          'created_at': now.toIso8601String(),
        },
        product().toMap(),
      ],
      'reward_inventory': <dynamic>[
        <String, dynamic>{
          'product_id': 'default-movie',
          'title': '看一场电影',
          'icon': 'movie',
          'quantity': 1,
          'acquired_count': 1,
          'used_count': 0,
          'updated_at': now.toIso8601String(),
        },
      ],
      'coin_transactions': <dynamic>[
        <String, dynamic>{
          'id': 'legacy-purchase',
          'amount': -80,
          'type': 'purchase',
          'title': '兑换：看一场电影',
          'reference_id': 'default-movie',
          'created_at': now.toIso8601String(),
        },
      ],
      'reward_meta': <dynamic>[
        <String, dynamic>{'id': 'catalog_seeded', 'value': 1},
      ],
    });
    final products = await repository.getProducts();
    expect(products.map((RewardProduct item) => item.id), <String>['custom']);
    expect((await db.query('reward_products')).single['id'], 'custom');
    expect((await repository.getInventory()).single.productId, 'default-movie');
    expect(await repository.getTransactions(), hasLength(1));
    expect((await db.exportAll()).containsKey('reward_meta'), isFalse);
  });
}
