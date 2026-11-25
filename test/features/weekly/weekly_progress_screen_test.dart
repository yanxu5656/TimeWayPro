import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:time_way_pro/core/ui/paper.dart';
import 'package:time_way_pro/core/utils/week.dart';
import 'package:time_way_pro/features/weekly/data/models/weekly_goal.dart';
import 'package:time_way_pro/features/weekly/data/repositories/weekly_goal_repository.dart';
import 'package:time_way_pro/features/weekly/presentation/screens/weekly_screen.dart';
import 'package:time_way_pro/features/weekly/providers/weekly_provider.dart';

class _MemoryWeeklyRepository implements WeeklyGoalRepository {
  final List<WeeklyGoal> goals = <WeeklyGoal>[];

  @override
  Future<List<WeeklyGoal>> getByWeek(String weekKey) async =>
      goals.where((WeeklyGoal goal) => goal.weekKey == weekKey).toList();

  @override
  Future<String> add(WeeklyGoal goal) async {
    final WeeklyGoal stored = goal.id.isEmpty
        ? goal.copyWith(id: 'goal-${goals.length}')
        : goal;
    goals.add(stored);
    return stored.id;
  }

  @override
  Future<void> update(WeeklyGoal goal) async {
    final int index = goals.indexWhere((WeeklyGoal item) => item.id == goal.id);
    if (index >= 0) goals[index] = goal;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _MemoryWeeklyRepository repository;
  late WeeklyProvider provider;

  setUp(() {
    final DateTime now = DateTime.now();
    repository = _MemoryWeeklyRepository();
    repository.goals.addAll(<WeeklyGoal>[
      for (int i = 0; i < 3; i++)
        WeeklyGoal(
          id: 'w$i',
          title: '本周目标 $i',
          isCompleted: i == 0,
          weekKey: weekKeyOf(now),
          sortOrder: i,
          createdAt: now,
        ),
    ]);
    provider = WeeklyProvider(repository: repository);
  });

  Future<void> pumpWeeklyScreen(
    WidgetTester tester, {
    Size size = const Size(390, 900),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ChangeNotifierProvider<WeeklyProvider>.value(
        value: provider,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const WeeklyScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  Future<void> openAddGoalSheet(
    WidgetTester tester, {
    Size size = const Size(390, 900),
  }) async {
    await pumpWeeklyScreen(tester, size: size);
    await tester.tap(find.byType(PaperFab));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  Future<void> tapAndFlush(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('可创建阶段目标，逐点打卡后自动完成', (tester) async {
    await openAddGoalSheet(tester);
    await tester.enterText(find.byKey(const Key('weekly_goal_title')), '写完论文');
    await tester.tap(find.byKey(const Key('weekly_progress_switch')));
    await tester.pump();
    expect(find.text('阶段 1'), findsOneWidget);
    expect(find.text('阶段 3'), findsOneWidget);
    await tapAndFlush(tester, find.text('添加'));

    final WeeklyGoal created = provider.goals.last;
    expect(created.title, '写完论文');
    expect(created.progressMode, WeeklyProgressMode.stages);
    expect(created.milestones, hasLength(3));

    for (final String label in const <String>['阶段 1', '阶段 2', '阶段 3']) {
      await tapAndFlush(tester, find.text(label));
    }

    expect(provider.goals.last.completedMilestones, 3);
    expect(provider.goals.last.isCompleted, isTrue);
    expect(provider.completed, 2, reason: '原 w0 加新目标全部完成');

    await tapAndFlush(tester, find.text('阶段 1'));
    expect(provider.goals.last.completedMilestones, 2);
    expect(provider.goals.last.isCompleted, isFalse);
  });

  testWidgets('可按次数生成数字打卡点', (tester) async {
    await openAddGoalSheet(tester);
    await tester.enterText(find.byKey(const Key('weekly_goal_title')), '跑步五次');
    await tester.tap(find.byKey(const Key('weekly_progress_switch')));
    await tester.pump();
    await tester.tap(find.text('按次数'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('weekly_milestone_count')),
      '5',
    );
    await tapAndFlush(tester, find.text('添加'));

    final WeeklyGoal created = provider.goals.last;
    expect(created.progressMode, WeeklyProgressMode.count);
    expect(
      created.milestones.map((WeeklyMilestone milestone) => milestone.title),
      <String>['第 1 次', '第 2 次', '第 3 次', '第 4 次', '第 5 次'],
    );
  });

  testWidgets('编辑数量保留对应打卡状态，切换类型重新开始', (tester) async {
    await openAddGoalSheet(tester);
    await tester.enterText(find.byKey(const Key('weekly_goal_title')), '复习英语');
    await tester.tap(find.byKey(const Key('weekly_progress_switch')));
    await tester.pump();
    await tapAndFlush(tester, find.text('添加'));

    await tapAndFlush(tester, find.text('阶段 1'));
    expect(provider.goals.last.completedMilestones, 1);

    await tapAndFlush(tester, find.text('复习英语'));
    await tester.enterText(
      find.byKey(const Key('weekly_milestone_count')),
      '5',
    );
    await tapAndFlush(tester, find.text('保存'));

    WeeklyGoal edited = provider.goals.last;
    expect(edited.milestones, hasLength(5));
    expect(edited.completedMilestones, 1);
    expect(edited.milestones.first.isCompleted, isTrue);

    await tapAndFlush(tester, find.text('复习英语'));
    await tester.tap(find.text('按次数'));
    await tester.pump();
    await tapAndFlush(tester, find.text('保存'));

    edited = provider.goals.last;
    expect(edited.progressMode, WeeklyProgressMode.count);
    expect(edited.milestones.first.title, '第 1 次');
    expect(edited.completedMilestones, 0);
    expect(edited.isCompleted, isFalse);
  });

  testWidgets('窄屏与最大打卡点数量下表单可滚动且不溢出', (tester) async {
    await openAddGoalSheet(tester, size: const Size(320, 640));
    await tester.enterText(find.byKey(const Key('weekly_goal_title')), '长期练习');
    await tester.tap(find.byKey(const Key('weekly_progress_switch')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('weekly_milestone_count')),
      '30',
    );
    await tester.pump();

    expect(find.text('等 30 个打卡点'), findsOneWidget);
    await tapAndFlush(tester, find.text('添加'));
    expect(provider.goals.last.milestones, hasLength(30));
    expect(tester.takeException(), isNull);
  });

  testWidgets('打卡点数量超出范围时阻止保存并给出提示', (tester) async {
    await openAddGoalSheet(tester);
    await tester.enterText(find.byKey(const Key('weekly_goal_title')), '无效目标');
    await tester.tap(find.byKey(const Key('weekly_progress_switch')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('weekly_milestone_count')),
      '0',
    );
    await tapAndFlush(tester, find.text('添加'));

    expect(find.text('请输入 1–30'), findsOneWidget);
    expect(find.text('添加目标'), findsNWidgets(2), reason: '表单应保持打开');
    expect(provider.total, 3);
  });
}
