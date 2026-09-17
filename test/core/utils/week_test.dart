import 'package:flutter_test/flutter_test.dart';
import 'package:time_way_pro/core/utils/week.dart';

void main() {
  group('startOfWeek —— 周一为起点', () {
    test('周一返回当天 00:00', () {
      expect(startOfWeek(DateTime(2026, 9, 14, 15, 30)), DateTime(2026, 9, 14));
    });

    test('周中返回本周一', () {
      // 2026-09-17 是周四
      expect(startOfWeek(DateTime(2026, 9, 17, 9)), DateTime(2026, 9, 14));
    });

    test('周日返回的是本周一，不是下周一', () {
      // 这是最容易写错的一处：Dart 的 weekday 里周日是 7，不是 0
      expect(startOfWeek(DateTime(2026, 9, 20, 23, 59)), DateTime(2026, 9, 14));
    });

    test('跨月：周日在 9 月、周一在 8 月', () {
      expect(startOfWeek(DateTime(2026, 9, 6)), DateTime(2026, 8, 31));
    });

    test('跨年：元旦所在的周，周一落在上一年', () {
      // 2027-01-01 是周五
      expect(startOfWeek(DateTime(2027, 1, 1)), DateTime(2026, 12, 28));
    });

    test('跨年：另一侧，2026-01-01 的周一在 2025 年', () {
      expect(startOfWeek(DateTime(2026, 1, 1)), DateTime(2025, 12, 29));
    });

    test('跨月：3 月 1 日的周一在 2 月', () {
      expect(startOfWeek(DateTime(2026, 3, 1)), DateTime(2026, 2, 23));
    });

    test('结果一定是周一，且 00:00:00', () {
      for (int day = 1; day <= 28; day++) {
        final DateTime d = DateTime(2026, 2, day, 13, 45, 30);
        final DateTime monday = startOfWeek(d);
        expect(monday.weekday, DateTime.monday, reason: '$d 的周一算错了');
        expect(monday.hour, 0);
        expect(monday.minute, 0);
        expect(monday.second, 0);
        expect(monday.millisecond, 0);
      }
    });

    test('不晚于传入日期，且相差不超过 6 天', () {
      for (int day = 1; day <= 28; day++) {
        final DateTime d = DateTime(2026, 7, day, 8);
        final DateTime monday = startOfWeek(d);
        expect(monday.isAfter(d), isFalse);
        expect(d.difference(monday).inDays, lessThan(7));
      }
    });

    test('幂等：对已经是周一的值再取一次不变', () {
      final DateTime monday = startOfWeek(DateTime(2026, 9, 17));
      expect(startOfWeek(monday), monday);
    });
  });

  group('endOfWeek', () {
    test('是周一 + 6 天的 23:59:59', () {
      final DateTime end = endOfWeek(DateTime(2026, 9, 17));
      expect(end, DateTime(2026, 9, 20, 23, 59, 59));
      expect(end.weekday, DateTime.sunday);
    });

    test('与 startOfWeek 相隔 6 天', () {
      for (int day = 1; day <= 28; day++) {
        final DateTime d = DateTime(2026, 11, day);
        final int diff = endOfWeek(d).difference(startOfWeek(d)).inDays;
        expect(diff, 6);
      }
    });
  });

  group('weekKeyOf', () {
    test('格式是 yyyy-MM-dd，取的是周一那天', () {
      expect(weekKeyOf(DateTime(2026, 9, 17)), '2026-09-14');
      expect(weekKeyOf(DateTime(2026, 9, 14)), '2026-09-14');
      expect(weekKeyOf(DateTime(2026, 9, 20)), '2026-09-14');
    });

    test('月与日补零', () {
      expect(weekKeyOf(DateTime(2026, 3, 1)), '2026-02-23');
    });

    test('同一周的七天 key 相同', () {
      final Set<String> keys = <String>{
        for (int i = 14; i <= 20; i++) weekKeyOf(DateTime(2026, 9, i)),
      };
      expect(keys, <String>{'2026-09-14'});
    });

    test('相邻两周的 key 不同', () {
      expect(
        weekKeyOf(DateTime(2026, 9, 20)),
        isNot(weekKeyOf(DateTime(2026, 9, 21))),
      );
    });

    test('跨年时 key 按周一所在年份，不是按被查询的日期', () {
      // 2027-01-01 属于 2026-12-28 那一周
      expect(weekKeyOf(DateTime(2027, 1, 1)), '2026-12-28');
      expect(weekKeyOf(DateTime(2026, 12, 28)), '2026-12-28');
    });

    test('字典序即时间序（key 可直接用于排序）', () {
      final List<String> keys = <String>[
        weekKeyOf(DateTime(2026, 9, 17)),
        weekKeyOf(DateTime(2026, 9, 3)),
        weekKeyOf(DateTime(2027, 1, 1)),
        weekKeyOf(DateTime(2026, 12, 1)),
      ]..sort();
      expect(keys, <String>[
        '2026-08-31',
        '2026-09-14',
        '2026-11-30',
        '2026-12-28',
      ]);
    });
  });
}
