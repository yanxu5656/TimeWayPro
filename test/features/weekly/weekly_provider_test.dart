import 'package:flutter_test/flutter_test.dart';
import 'package:time_way_pro/core/utils/week.dart';
import 'package:time_way_pro/features/weekly/data/models/weekly_goal.dart';
import 'package:time_way_pro/features/weekly/data/repositories/weekly_goal_repository.dart';
import 'package:time_way_pro/features/weekly/providers/weekly_provider.dart';

class _MemoryWeeklyRepository implements WeeklyGoalRepository {
  _MemoryWeeklyRepository(this.goals);

  List<WeeklyGoal> goals;
  bool failUpdates = false;

  @override
  Future<List<WeeklyGoal>> getByWeek(String weekKey) async => <WeeklyGoal>[
    for (final WeeklyGoal goal in goals)
      if (goal.weekKey == weekKey) goal,
  ];

  @override
  Future<String> add(WeeklyGoal goal) async {
    final WeeklyGoal stored = goal.id.isEmpty
        ? goal.copyWith(id: 'added')
        : goal;
    goals = <WeeklyGoal>[...goals, stored];
    return stored.id;
  }

  @override
  Future<void> update(WeeklyGoal goal) async {
    if (failUpdates) throw StateError('write failed');
    final int index = goals.indexWhere((WeeklyGoal item) => item.id == goal.id);
    if (index >= 0) goals[index] = goal;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final String weekKey = weekKeyOf(DateTime.now());
  final DateTime now = DateTime.now();

  WeeklyGoal goal(
    String id, {
    bool completed = false,
    List<WeeklyMilestone> milestones = const <WeeklyMilestone>[],
  }) => WeeklyGoal(
    id: id,
    title: id,
    weekKey: weekKey,
    createdAt: now,
    isCompleted: completed,
    milestones: milestones,
  );

  test('新增分段目标会保留打卡点与模式', () async {
    final _MemoryWeeklyRepository repository = _MemoryWeeklyRepository(
      <WeeklyGoal>[],
    );
    final WeeklyProvider provider = WeeklyProvider(repository: repository);

    await provider.addGoal(
      '跑步',
      progressMode: WeeklyProgressMode.count,
      milestones: const <WeeklyMilestone>[
        WeeklyMilestone(id: 'run-1', title: '第 1 次'),
        WeeklyMilestone(id: 'run-2', title: '第 2 次', sortOrder: 1),
      ],
    );

    expect(provider.goals.single.progressMode, WeeklyProgressMode.count);
    expect(provider.goals.single.milestones, hasLength(2));
  });

  test('周完成度按打卡点加权，整目标数仍只统计全部完成', () async {
    final _MemoryWeeklyRepository repository = _MemoryWeeklyRepository(
      <WeeklyGoal>[
        goal('done', completed: true),
        goal(
          'staged',
          milestones: const <WeeklyMilestone>[
            WeeklyMilestone(id: 's1', title: '阶段 1', isCompleted: true),
            WeeklyMilestone(id: 's2', title: '阶段 2', sortOrder: 1),
          ],
        ),
        goal('todo'),
      ],
    );
    final WeeklyProvider provider = WeeklyProvider(repository: repository);

    await provider.loadGoals();

    expect(provider.total, 3);
    expect(provider.completed, 1);
    expect(provider.progress, 0.5);
  });

  test('逐点打卡自动完成目标，取消一个点会重新打开', () async {
    final _MemoryWeeklyRepository repository = _MemoryWeeklyRepository(
      <WeeklyGoal>[
        goal(
          'staged',
          milestones: const <WeeklyMilestone>[
            WeeklyMilestone(id: 's1', title: '阶段 1'),
            WeeklyMilestone(id: 's2', title: '阶段 2', sortOrder: 1),
          ],
        ),
      ],
    );
    final WeeklyProvider provider = WeeklyProvider(repository: repository);
    await provider.loadGoals();

    await provider.toggleMilestone('staged', 's1');
    expect(provider.goals.single.isCompleted, isFalse);
    expect(provider.progress, 0.5);

    await provider.toggleMilestone('staged', 's2');
    expect(provider.goals.single.isCompleted, isTrue);
    expect(provider.completed, 1);
    expect(provider.progress, 1);

    await provider.toggleMilestone('staged', 's1');
    expect(provider.goals.single.isCompleted, isFalse);
    expect(provider.completed, 0);
    expect(provider.progress, 0.5);
  });

  test('打卡写盘失败时恢复勾选前的状态', () async {
    final _MemoryWeeklyRepository repository = _MemoryWeeklyRepository(
      <WeeklyGoal>[
        goal(
          'staged',
          milestones: const <WeeklyMilestone>[
            WeeklyMilestone(id: 's1', title: '阶段 1'),
          ],
        ),
      ],
    );
    final WeeklyProvider provider = WeeklyProvider(repository: repository);
    await provider.loadGoals();
    repository.failUpdates = true;

    await expectLater(
      provider.toggleMilestone('staged', 's1'),
      throwsStateError,
    );

    expect(provider.goals.single.completedMilestones, 0);
    expect(provider.goals.single.isCompleted, isFalse);
  });
}
