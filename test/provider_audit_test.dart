import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:time_way_pro/features/calendar/data/models/calendar_note.dart';
import 'package:time_way_pro/features/calendar/data/repositories/calendar_repository.dart';
import 'package:time_way_pro/features/calendar/providers/calendar_provider.dart';
import 'package:time_way_pro/features/daily/data/models/daily_task.dart';
import 'package:time_way_pro/features/daily/data/repositories/daily_repository.dart';
import 'package:time_way_pro/features/daily/providers/daily_provider.dart';
import 'package:time_way_pro/features/planning/data/repositories/plan_repository.dart';
import 'package:time_way_pro/features/weekly/data/models/weekly_goal.dart';
import 'package:time_way_pro/features/weekly/data/repositories/weekly_goal_repository.dart';
import 'package:time_way_pro/features/weekly/providers/weekly_provider.dart';
import 'package:time_way_pro/shared/database/database_helper.dart';

import 'support/app_harness.dart';

class _DeferredDailyRepository implements DailyRepository {
  final Map<String, Completer<List<DailyTask>>> requests = {};

  @override
  Future<List<DailyTask>> getTasksByDate(String dateKey) {
    final Completer<List<DailyTask>> request = Completer<List<DailyTask>>();
    requests[dateKey] = request;
    return request.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DeferredWeeklyRepository implements WeeklyGoalRepository {
  final Map<String, Completer<List<WeeklyGoal>>> requests = {};

  @override
  Future<List<WeeklyGoal>> getByWeek(String weekKey) {
    final Completer<List<WeeklyGoal>> request = Completer<List<WeeklyGoal>>();
    requests[weekKey] = request;
    return request.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DeferredCalendarRepository implements CalendarRepository {
  final Map<String, Completer<List<CalendarNote>>> requests = {};

  @override
  Future<List<CalendarNote>> getByMonth(String monthKey) {
    final Completer<List<CalendarNote>> request =
        Completer<List<CalendarNote>>();
    requests[monthKey] = request;
    return request.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> flushMicrotasks() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final DateTime now = DateTime.now();

  group('异步加载代际保护', () {
    test('每日快速切日后，旧日期结果不能覆盖新日期', () async {
      final _DeferredDailyRepository repository = _DeferredDailyRepository();
      final DailyProvider provider = DailyProvider(repository: repository);
      final DateTime oldDate = provider.selectedDate;
      final DateTime newDate = DateTime(
        now.year,
        now.month,
        oldDate.day == 1 ? 2 : 1,
      );

      final Future<void> staleLoad = provider.loadTasks();
      provider.setDate(newDate);
      final String oldKey =
          '${oldDate.year.toString().padLeft(4, '0')}-'
          '${oldDate.month.toString().padLeft(2, '0')}-'
          '${oldDate.day.toString().padLeft(2, '0')}';
      final String newKey =
          '${newDate.year.toString().padLeft(4, '0')}-'
          '${newDate.month.toString().padLeft(2, '0')}-'
          '${newDate.day.toString().padLeft(2, '0')}';
      repository.requests[newKey]!.complete(<DailyTask>[
        DailyTask(
          id: 'new',
          title: '新日期',
          timePeriod: TimePeriod.morning,
          dateKey: newKey,
          createdAt: now,
        ),
      ]);
      await flushMicrotasks();
      repository.requests[oldKey]!.complete(<DailyTask>[
        DailyTask(
          id: 'old',
          title: '旧日期',
          timePeriod: TimePeriod.morning,
          dateKey: oldKey,
          createdAt: now,
        ),
      ]);
      await staleLoad;
      await flushMicrotasks();

      expect(provider.tasks.single.id, 'new');
      expect(provider.isLoading, isFalse);
    });

    test('每周快速切周后，旧周结果不能覆盖新周', () async {
      final _DeferredWeeklyRepository repository = _DeferredWeeklyRepository();
      final WeeklyProvider provider = WeeklyProvider(repository: repository);
      final String oldKey = provider.selectedWeekKey;

      final Future<void> staleLoad = provider.loadGoals();
      provider.nextWeek();
      final String newKey = provider.selectedWeekKey;
      repository.requests[newKey]!.complete(<WeeklyGoal>[
        WeeklyGoal(id: 'new', title: '新周', weekKey: newKey, createdAt: now),
      ]);
      await flushMicrotasks();
      repository.requests[oldKey]!.complete(<WeeklyGoal>[
        WeeklyGoal(id: 'old', title: '旧周', weekKey: oldKey, createdAt: now),
      ]);
      await staleLoad;
      await flushMicrotasks();

      expect(provider.goals.single.id, 'new');
      expect(provider.isLoading, isFalse);
    });

    test('月历快速切月后，旧月结果不能覆盖新月', () async {
      final _DeferredCalendarRepository repository =
          _DeferredCalendarRepository();
      final CalendarProvider provider = CalendarProvider(
        repository: repository,
      );
      final String oldKey = provider.monthKey;

      final Future<void> staleLoad = provider.loadMonth();
      provider.nextMonth();
      final String newKey = provider.monthKey;
      repository.requests[newKey]!.complete(<CalendarNote>[
        CalendarNote(
          id: 'new',
          dateKey: '$newKey-01',
          text: '新月',
          createdAt: now,
        ),
      ]);
      await flushMicrotasks();
      repository.requests[oldKey]!.complete(<CalendarNote>[
        CalendarNote(
          id: 'old',
          dateKey: '$oldKey-01',
          text: '旧月',
          createdAt: now,
        ),
      ]);
      await staleLoad;
      await flushMicrotasks();

      expect(provider.notes.single.id, 'new');
      expect(provider.isLoading, isFalse);
    });
  });

  group('规划仓库容错与批量删除', () {
    late PlanRepository repository;

    setUp(() async {
      installPathProviderMock();
      repository = PlanRepository();
      await DatabaseHelper().importAll(seedData());
    });

    test('单条坏行不会让整页规划读取失败', () async {
      final Map<String, dynamic> data = await DatabaseHelper().exportAll();
      (data['plans'] as List).add(<String, dynamic>{
        'id': 'bad',
        'title': '坏行',
        'created_at': 'not a date',
      });

      await DatabaseHelper().importAll(data);

      final plans = await repository.getAllPlans();
      expect(plans.map((plan) => plan.id), orderedEquals(<String>['p1', 'p2']));
      expect((await repository.getRootPlans()).single.id, 'p1');
      expect((await repository.getChildPlans('p1')).single.id, 'p2');
      expect(await repository.getPlanById('bad'), isNull);
    });

    test('删除父规划一次移除整棵子树并保留无关规划', () async {
      final Map<String, dynamic> data = await DatabaseHelper().exportAll();
      (data['plans'] as List).add(<String, dynamic>{
        'id': 'unrelated',
        'title': '无关规划',
        'parent_id': null,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
      await DatabaseHelper().importAll(data);

      await repository.deletePlan('p1');

      expect(
        (await repository.getAllPlans()).map((plan) => plan.id),
        orderedEquals(<String>['unrelated']),
      );
    });

    test('循环父级不会导致子树删除无限递归', () async {
      final Map<String, dynamic> data = await DatabaseHelper().exportAll();
      (data['plans'] as List).add(<String, dynamic>{
        'id': 'cycle',
        'title': '循环规划',
        'parent_id': 'cycle',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
      await DatabaseHelper().importAll(data);

      await repository.deletePlan('cycle');

      expect(
        (await repository.getAllPlans()).map((plan) => plan.id),
        orderedEquals(<String>['p1', 'p2']),
      );
    });

    test('进度写入拒绝非有限值并限制在 0..1', () async {
      await repository.updateProgress('p1', double.nan);
      await repository.updateProgress('p1', double.infinity);
      expect((await repository.getPlanById('p1'))!.progress, 0.45);

      await repository.updateProgress('p1', 2);
      expect((await repository.getPlanById('p1'))!.progress, 1);
      await repository.updateProgress('p1', -2);
      expect((await repository.getPlanById('p1'))!.progress, 0);
    });
  });
}
