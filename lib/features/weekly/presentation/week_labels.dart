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
