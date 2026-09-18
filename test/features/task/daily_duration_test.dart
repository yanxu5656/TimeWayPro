import 'package:flutter_test/flutter_test.dart';
import 'package:time_way_pro/features/task/providers/task_provider.dart';
import 'package:time_way_pro/shared/database/database_helper.dart';

/// 任务页「当日累计时长」的按日聚合测试。
///
/// 这一组守的是 v1.3.3 的核心改动：`getAllTaskDailyDurations` 原先把
/// `DateTime.now()` 写死在方法体里，所以任务页翻日期时标题变了、数字不变。
/// 现在它接受一个日期，这里验证「真的按传入的那天算」。
///
/// 用普通 `test()` 而非 `testWidgets()`：要真实读写文件，而 FakeAsync 区里
/// `dart:io` 的 Future 永不完成。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final DatabaseHelper db = DatabaseHelper();
  final TaskProvider provider = TaskProvider();

  /// 造一条计时记录
  Map<String, dynamic> record(String id, String taskId, DateTime start) =>
      <String, dynamic>{
        'id': id,
        'task_id': taskId,
        'start_time': start.toIso8601String(),
        'end_time': start.add(const Duration(minutes: 30)).toIso8601String(),
        'duration': 1800,
        'completed_at': null,
      };

  Map<String, dynamic> seed(List<Map<String, dynamic>> records) =>
      <String, dynamic>{
        'tasks': <dynamic>[],
        'task_records': records,
        'plans': <dynamic>[],
        'daily_tasks': <dynamic>[],
        'weekly_goals': <dynamic>[],
        'sync_config': <dynamic>[],
      };

  final DateTime day18 = DateTime(2026, 9, 18);

  setUp(() async {
    await db.importAll(
      seed(<Map<String, dynamic>>[
        // 9/18 那天，任务 A 两次、任务 B 一次
        record('r1', 'A', DateTime(2026, 9, 18, 9, 0)),
        record('r2', 'A', DateTime(2026, 9, 18, 14, 0)),
        record('r3', 'B', DateTime(2026, 9, 18, 20, 0)),
        // 9/17 那天，任务 A 一次——不该串到 18 号
        record('r4', 'A', DateTime(2026, 9, 17, 9, 0)),
        // 9/19 那天，任务 C 一次——也不该串到 18 号
        record('r5', 'C', DateTime(2026, 9, 19, 9, 0)),
        // 边界：18 号最后一毫秒
        record('r6', 'D', DateTime(2026, 9, 18, 23, 59, 59, 999)),
      ]),
    );
  });

  group('按传入的日期聚合', () {
    test('只统计那一天的记录', () async {
      final Map<String, int> durations = await provider
          .getAllTaskDailyDurations(day: day18);

      expect(durations.keys.toSet(), <String>{'A', 'B', 'D'});
    });

    test('同一任务的多条记录会求和', () async {
      final Map<String, int> durations = await provider
          .getAllTaskDailyDurations(day: day18);

      // A 在 18 号有两条，各 1800 秒
      expect(durations['A'], 3600);
      expect(durations['B'], 1800);
    });

    test('相邻日期的记录不会串进来', () async {
      final Map<String, int> durations = await provider
          .getAllTaskDailyDurations(day: day18);

      // C 只在 19 号有记录，不该出现在 18 号的结果里
      expect(durations.containsKey('C'), isFalse);
      // A 在 17 号也有一条，若区间算错 A 会变成 5400
      expect(durations['A'], 3600, reason: '17 号那条被算进来了，说明区间下界不对');
    });

    test('23:59:59.999 的记录算在当天', () async {
      final Map<String, int> durations = await provider
          .getAllTaskDailyDurations(day: day18);

      expect(
        durations.containsKey('D'),
        isTrue,
        reason: '最后一毫秒的记录被漏掉了——闭区间 23:59:59 就是这个毛病',
      );
    });

    test('次日的 00:00 不算在当天', () async {
      final Map<String, int> durations = await provider
          .getAllTaskDailyDurations(day: DateTime(2026, 9, 17));

      expect(durations.containsKey('C'), isFalse);
      expect(durations['A'], 1800);
    });

    test('不传日期时按今天算（保持旧调用点的行为）', () async {
      // 不要断言"应为空"——种子数据的日期可能正好就是今天。
      // 这里比较的是「省略日期」与「显式传今天」的结果一致。
      final Map<String, int> withDefault = await provider
          .getAllTaskDailyDurations();
      final Map<String, int> explicitToday = await provider
          .getAllTaskDailyDurations(day: DateTime.now());

      expect(withDefault, explicitToday);
    });

    test('查一个没有任何记录的日子返回空', () async {
      final Map<String, int> durations = await provider
          .getAllTaskDailyDurations(day: DateTime(2020, 1, 1));

      expect(durations, isEmpty);
    });

    test('传入带时刻的 DateTime 也能正确取整到当天', () async {
      // 任务页传的是 _selectedDate，它的时刻部分通常不是 00:00
      final Map<String, int> durations = await provider
          .getAllTaskDailyDurations(day: DateTime(2026, 9, 18, 16, 42, 7));

      expect(durations['A'], 3600);
      expect(durations.keys.toSet(), <String>{'A', 'B', 'D'});
    });
  });

  group('单任务版本', () {
    test('getTaskDailyDuration 也接受日期', () async {
      expect(await provider.getTaskDailyDuration('A', day: day18), 3600);
      expect(
        await provider.getTaskDailyDuration('A', day: DateTime(2026, 9, 17)),
        1800,
      );
    });

    test('没有记录的任务返回 0', () async {
      expect(await provider.getTaskDailyDuration('Z', day: day18), 0);
    });
  });
}
