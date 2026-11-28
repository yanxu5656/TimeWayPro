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

  Future<void> seedGoal(WeeklyGoal value) async {
    await db.importAll(<String, dynamic>{
      'tasks': <dynamic>[],
      'task_records': <dynamic>[],
      'plans': <dynamic>[],
      'weekly_goals': <dynamic>[value.toMap()],
    });
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
    await seedGoal(goal());
    await repository.updateWeeklyGoal(goal(completed: true));
    final products = await repository.getProducts();
    expect(products, hasLength(4));
    await Future.wait<void>(<Future<void>>[
      repository.purchase(products.first.id),
      repository.purchase(products.first.id).catchError((Object _) {}),
    ]);
    final inventory = await repository.getInventory();
    expect(inventory, hasLength(1));
    expect(inventory.single.quantity, 1);
    final balance = (await repository.getTransactions()).fold<int>(
      0,
      (int sum, dynamic item) => sum + (item.amount as num).toInt(),
    );
    expect(balance, 20);
    await expectLater(repository.purchase(products.first.id), throwsStateError);
  });

  test('余额不足时兑换失败且不产生库存', () async {
    await seedGoal(goal());
    await repository.updateWeeklyGoal(goal(completed: true));
    final product = (await repository.getProducts()).firstWhere(
      (RewardProduct item) => item.price > 100,
    );
    await expectLater(repository.purchase(product.id), throwsStateError);
    expect(await repository.getInventory(), isEmpty);
  });

  test('库存、限购、下架和仓库兑现', () async {
    await seedGoal(goal());
    await repository.updateWeeklyGoal(goal(completed: true));
    final DateTime now = DateTime.now();
    final RewardProduct product = RewardProduct(
      id: 'custom',
      title: '限量奶茶',
      price: 30,
      stock: 1,
      purchaseLimit: 1,
      createdAt: now,
    );
    await repository.saveProduct(product);
    await repository.purchase(product.id);
    await expectLater(repository.purchase(product.id), throwsStateError);
    expect((await repository.getInventory()).single.quantity, 1);
    await repository.fulfill(product.id);
    final InventoryItem used = (await repository.getInventory()).single;
    expect(used.quantity, 0);
    expect(used.usedCount, 1);
    await expectLater(repository.fulfill(product.id), throwsStateError);
    await repository.archiveProduct(product.id);
    await expectLater(repository.restoreProduct(product.id), completes);
  });

  test('备份保留金币、库存与领取状态', () async {
    await seedGoal(goal());
    await repository.updateWeeklyGoal(goal(completed: true));
    final product = (await repository.getProducts()).first;
    await repository.purchase(product.id);
    final exported = await db.exportAll();
    db.resetForTesting();
    await db.importAll(exported);
    expect((await repository.getTransactions()).length, 2);
    expect((await repository.getInventory()).single.quantity, 1);
    final rows = await db.query('weekly_goals');
    expect(WeeklyGoal.fromMap(rows.single).rewardClaimedAt, isNotNull);
  });
}
