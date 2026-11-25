import 'package:flutter_test/flutter_test.dart';
import 'package:time_way_pro/core/utils/week.dart';
import 'package:time_way_pro/features/weekly/data/models/weekly_goal.dart';
import 'package:time_way_pro/features/weekly/data/repositories/weekly_goal_repository.dart';
import 'package:time_way_pro/shared/database/database_helper.dart';

import '../../support/app_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WeeklyGoalRepository repo;
  final String thisWeek = weekKeyOf(DateTime.now());

  setUp(() async {
    // 本文件直接做真实文件 IO，必须先装平台通道 mock
    // （v1.5.1 前落盘失败被 _saveData 吞掉，这里一直缺 mock 却侥幸通过）
    installPathProviderMock();
    repo = WeeklyGoalRepository();
    await DatabaseHelper().importAll(seedData());
  });

  group('按周过滤', () {
    test('只取本周的目标', () async {
      final List<WeeklyGoal> goals = await repo.getByWeek(thisWeek);

      expect(goals, hasLength(3));
      expect(goals.every((WeeklyGoal g) => g.weekKey == thisWeek), isTrue);
      expect(
        goals.any((WeeklyGoal g) => g.title.contains('上周')),
        isFalse,
        reason: '上一周的目标不该出现在本周列表里',
      );
    });

    test('上一周的数据仍在库里，只是不显示', () async {
      final List<Map<String, dynamic>> all = await DatabaseHelper().query(
        'weekly_goals',
      );

      expect(all, hasLength(4), reason: '3 条本周 + 1 条上周');
      final List<Map<String, dynamic>> lastWeek = all
          .where((Map<String, dynamic> m) => m['week_key'] != thisWeek)
          .toList();
      expect(lastWeek, hasLength(1));
    });

    test('查一个不存在的周返回空', () async {
      expect(await repo.getByWeek('1999-01-04'), isEmpty);
    });

    test('按 sortOrder 排序', () async {
      final List<WeeklyGoal> goals = await repo.getByWeek(thisWeek);
      final List<int> orders = goals
          .map((WeeklyGoal g) => g.sortOrder)
          .toList();
      expect(orders, orderedEquals(<int>[...orders]..sort()));
    });
  });

  group('增删改', () {
    test('新增会落库并归到本周', () async {
      await repo.add(
        WeeklyGoal(
          id: '',
          title: '新目标',
          weekKey: thisWeek,
          createdAt: DateTime.now(),
        ),
      );

      final List<WeeklyGoal> goals = await repo.getByWeek(thisWeek);
      expect(goals, hasLength(4));
      expect(goals.map((WeeklyGoal g) => g.title), contains('新目标'));
    });

    test('id 为空时自动生成', () async {
      final String id = await repo.add(
        WeeklyGoal(
          id: '',
          title: '自动 id',
          weekKey: thisWeek,
          createdAt: DateTime.now(),
        ),
      );

      expect(id, isNotEmpty);
    });

    test('切换完成状态', () async {
      final List<WeeklyGoal> before = await repo.getByWeek(thisWeek);
      final WeeklyGoal target = before.firstWhere(
        (WeeklyGoal g) => !g.isCompleted,
      );

      await repo.toggleComplete(target.id);

      final List<WeeklyGoal> after = await repo.getByWeek(thisWeek);
      expect(
        after.firstWhere((WeeklyGoal g) => g.id == target.id).isCompleted,
        isTrue,
      );
    });

    test('删除', () async {
      final List<WeeklyGoal> before = await repo.getByWeek(thisWeek);
      await repo.delete(before.first.id);

      final List<WeeklyGoal> after = await repo.getByWeek(thisWeek);
      expect(after, hasLength(before.length - 1));
    });

    test('删除只影响目标本身，不动同周的其它条目', () async {
      final List<WeeklyGoal> before = await repo.getByWeek(thisWeek);
      final WeeklyGoal keep = before[1];
      await repo.delete(before.first.id);

      final List<WeeklyGoal> after = await repo.getByWeek(thisWeek);
      expect(after.map((WeeklyGoal g) => g.id), contains(keep.id));
    });
  });

  group('数据兼容', () {
    test('导入不含 weekly_goals 的旧备份不崩，且会被补成空表', () async {
      // 这是 v1.3.0 及更早版本写出的备份形状
      await DatabaseHelper().importAll(<String, dynamic>{
        'tasks': <dynamic>[],
        'task_records': <dynamic>[],
        'plans': <dynamic>[],
        'daily_tasks': <dynamic>[],
        'sync_config': <dynamic>[],
      });

      // 不该抛异常，且查询得到空列表
      expect(await repo.getByWeek(thisWeek), isEmpty);

      // 关键：键要真的存在，而不是"查询时靠 ?? [] 兜住"
      expect(
        (await DatabaseHelper().exportAll()).containsKey('weekly_goals'),
        isTrue,
        reason: 'importAll 应给缺失的新表补上键',
      );
    });

    test('旧备份导入后仍可正常新增本周目标', () async {
      await DatabaseHelper().importAll(<String, dynamic>{
        'tasks': <dynamic>[],
        'task_records': <dynamic>[],
        'plans': <dynamic>[],
      });

      await repo.add(
        WeeklyGoal(
          id: '',
          title: '导入后新增',
          weekKey: thisWeek,
          createdAt: DateTime.now(),
        ),
      );

      expect(await repo.getByWeek(thisWeek), hasLength(1));
    });
  });

  group('分段进度', () {
    test('阶段打卡点序列化后顺序与完成状态保持一致', () {
      final WeeklyGoal goal = WeeklyGoal(
        id: 'x1',
        title: '写完论文',
        weekKey: '2026-09-14',
        createdAt: DateTime(2026, 9, 14),
        progressMode: WeeklyProgressMode.stages,
        milestones: const <WeeklyMilestone>[
          WeeklyMilestone(id: 'm2', title: '阶段 2', sortOrder: 1),
          WeeklyMilestone(
            id: 'm1',
            title: '阶段 1',
            isCompleted: true,
            sortOrder: 0,
          ),
        ],
      );

      final WeeklyGoal back = WeeklyGoal.fromMap(goal.toMap());

      expect(back.progressMode, WeeklyProgressMode.stages);
      expect(back.milestones.map((WeeklyMilestone m) => m.id), <String>[
        'm1',
        'm2',
      ]);
      expect(back.completedMilestones, 1);
      expect(back.progress, 0.5);
      expect(back.isCompleted, isFalse);
    });

    test('旧数据没有打卡点时仍按普通目标读取', () {
      final WeeklyGoal goal = WeeklyGoal.fromMap(<String, dynamic>{
        'id': 'x1',
        'title': '旧目标',
        'is_completed': 1,
        'week_key': '2026-09-14',
        'created_at': DateTime(2026, 9, 14).toIso8601String(),
      });

      expect(goal.hasMilestones, isFalse);
      expect(goal.progressMode, isNull);
      expect(goal.isCompleted, isTrue);
      expect(goal.progress, 1);
    });

    test('坏打卡点跳过，缺 id 的合法打卡点使用稳定兜底', () {
      final WeeklyGoal goal = WeeklyGoal.fromMap(<String, dynamic>{
        'id': 'x1',
        'title': '容错目标',
        'week_key': '2026-09-14',
        'created_at': DateTime(2026, 9, 14).toIso8601String(),
        'milestones': <dynamic>[
          <String, dynamic>{'title': '缺 id'},
          <String, dynamic>{'id': 'bad'},
          'not a map',
        ],
      });

      expect(goal.milestones, hasLength(1));
      expect(goal.milestones.single.id, 'x1_milestone_0');
      expect(goal.milestones.single.title, '缺 id');
    });

    test('单项打卡会落库，全部完成后目标自动完成', () async {
      final String id = await repo.add(
        WeeklyGoal(
          id: '',
          title: '跑步',
          weekKey: thisWeek,
          createdAt: DateTime.now(),
          progressMode: WeeklyProgressMode.count,
          milestones: const <WeeklyMilestone>[
            WeeklyMilestone(id: 'run-1', title: '第 1 次'),
            WeeklyMilestone(id: 'run-2', title: '第 2 次', sortOrder: 1),
          ],
        ),
      );
      WeeklyGoal goal = (await repo.getByWeek(
        thisWeek,
      )).singleWhere((WeeklyGoal goal) => goal.id == id);

      await repo.update(goal.toggleMilestone('run-1'));
      goal = (await repo.getByWeek(
        thisWeek,
      )).singleWhere((WeeklyGoal goal) => goal.id == id);
      expect(goal.completedMilestones, 1);
      expect(goal.isCompleted, isFalse);

      await repo.update(goal.toggleMilestone('run-2'));
      goal = (await repo.getByWeek(
        thisWeek,
      )).singleWhere((WeeklyGoal goal) => goal.id == id);
      expect(goal.completedMilestones, 2);
      expect(goal.isCompleted, isTrue);
    });

    test('切换整个目标会同步全部打卡点', () async {
      final String id = await repo.add(
        WeeklyGoal(
          id: '',
          title: '读书',
          weekKey: thisWeek,
          createdAt: DateTime.now(),
          milestones: const <WeeklyMilestone>[
            WeeklyMilestone(id: 'read-1', title: '阶段 1'),
            WeeklyMilestone(id: 'read-2', title: '阶段 2', sortOrder: 1),
          ],
        ),
      );

      await repo.toggleComplete(id);
      WeeklyGoal goal = (await repo.getByWeek(
        thisWeek,
      )).singleWhere((WeeklyGoal goal) => goal.id == id);
      expect(
        goal.milestones.every((WeeklyMilestone m) => m.isCompleted),
        isTrue,
      );

      await repo.toggleComplete(id);
      goal = (await repo.getByWeek(
        thisWeek,
      )).singleWhere((WeeklyGoal goal) => goal.id == id);
      expect(
        goal.milestones.every((WeeklyMilestone m) => !m.isCompleted),
        isTrue,
      );
      expect(goal.isCompleted, isFalse);
    });

    test('清空打卡点后恢复普通目标且不残留进度模式', () {
      final WeeklyGoal goal = WeeklyGoal(
        id: 'x1',
        title: '普通目标',
        weekKey: '2026-09-14',
        createdAt: DateTime(2026, 9, 14),
        progressMode: WeeklyProgressMode.count,
        milestones: const <WeeklyMilestone>[
          WeeklyMilestone(id: 'm1', title: '第 1 次'),
        ],
      );

      final WeeklyGoal plain = goal.copyWith(
        milestones: const <WeeklyMilestone>[],
      );
      expect(plain.hasMilestones, isFalse);
      expect(plain.progressMode, isNull);
      expect(plain.toMap()['milestones'], isEmpty);
    });
  });

  group('序列化', () {
    test('toMap / fromMap 往返一致', () {
      final WeeklyGoal goal = WeeklyGoal(
        id: 'x1',
        title: '读三本书',
        isCompleted: true,
        weekKey: '2026-09-14',
        sortOrder: 2,
        createdAt: DateTime(2026, 9, 14, 10, 30),
      );

      final WeeklyGoal back = WeeklyGoal.fromMap(goal.toMap());

      expect(back.id, goal.id);
      expect(back.title, goal.title);
      expect(back.isCompleted, isTrue);
      expect(back.weekKey, goal.weekKey);
      expect(back.sortOrder, goal.sortOrder);
      expect(back.createdAt, goal.createdAt);
    });

    test('字段名是 snake_case，bool 存 0/1', () {
      final Map<String, dynamic> map = WeeklyGoal(
        id: 'x1',
        title: 't',
        isCompleted: true,
        weekKey: '2026-09-14',
        createdAt: DateTime(2026, 9, 14),
      ).toMap();

      expect(map['is_completed'], 1);
      expect(map['week_key'], '2026-09-14');
      expect(map['sort_order'], 0);
      expect(map.containsKey('created_at'), isTrue);
    });

    test('缺 sort_order 时按 0 兜底（旧数据可能没有这个字段）', () {
      final WeeklyGoal goal = WeeklyGoal.fromMap(<String, dynamic>{
        'id': 'x1',
        'title': 't',
        'is_completed': 0,
        'week_key': '2026-09-14',
        'created_at': DateTime(2026, 9, 14).toIso8601String(),
      });

      expect(goal.sortOrder, 0);
      expect(goal.isCompleted, isFalse);
    });
  });
}
