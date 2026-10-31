import '../../../core/utils/week.dart';

/// 周的相对简称：上上周 / 上周 / 本周 / 下周 / 下下周。
///
/// 只覆盖 ±2 周——再远的周相对称呼没有意义，返回 null 让调用方
/// 退回 `weekRangeLabel()` 的日期区间文本。
String? weekShortLabel(DateTime monday) {
  final int offset =
      monday.difference(startOfWeek(DateTime.now())).inDays ~/ 7;
  return switch (offset) {
    -2 => '上上周',
    -1 => '上周',
    0 => '本周',
    1 => '下周',
    2 => '下下周',
    _ => null,
  };
}

// ── 编排精修（v1.6.0）：英文大写日期，与刊头眉题同一套编辑语言 ──

const List<String> _monthsEn = <String>[
  'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
  'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
];

/// `OCT 24`
String monthDayCaps(DateTime d) => '${_monthsEn[d.month - 1]} ${d.day}';

/// `OCT 19 — OCT 25`（周一到周日）
String weekRangeCaps(DateTime date) {
  final DateTime monday = startOfWeek(date);
  final DateTime sunday = monday.add(const Duration(days: 6));
  return '${monthDayCaps(monday)} — ${monthDayCaps(sunday)}';
}
