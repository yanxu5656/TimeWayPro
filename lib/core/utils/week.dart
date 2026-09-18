/// 周的边界计算。
///
/// 统一规定：**周一为一周起点**（与 Dart 的 `DateTime.weekday` 一致，
/// Mon=1 … Sun=7）。这套算法原先在 `statistics_screen.dart` 里内联重复了
/// 4 处，本周目标功能要用第 5 次，因此抽出来。
///
/// 为什么用「周一的日期」而不是 ISO 周号做标识：ISO 周号有跨年边界问题
/// （12 月 31 日可能属于下一年的第 1 周），而周一日期既能正确排序，又能
/// 直接与项目里已有的 `date_key`（`yyyy-MM-dd`）风格对齐。
library;

/// 本周周一 00:00
DateTime startOfWeek(DateTime date) {
  final DateTime monday = date.subtract(Duration(days: date.weekday - 1));
  return DateTime(monday.year, monday.month, monday.day);
}

/// 本周周日 23:59:59 —— 用作区间查询的上界
///
/// 与 `statistics_screen` 里既有的 `_getDateRange()` 写法保持一致
/// （那里也是 `...day + 6, 23, 59, 59`）。
DateTime endOfWeek(DateTime date) {
  final DateTime monday = startOfWeek(date);
  return DateTime(monday.year, monday.month, monday.day + 6, 23, 59, 59);
}

/// 周标识，形如 `2026-09-14`（本周周一的日期）
///
/// 手工拼接而不是用 `DateFormat`：这是个底层工具，不想因此引入 intl 依赖，
/// 也不想受 locale / 日历设置影响。输出与 `DateFormat('yyyy-MM-dd')` 一致。
String weekKeyOf(DateTime date) {
  final DateTime monday = startOfWeek(date);
  final String y = monday.year.toString().padLeft(4, '0');
  final String m = monday.month.toString().padLeft(2, '0');
  final String d = monday.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// 某天 00:00
DateTime startOfDay(DateTime date) =>
    DateTime(date.year, date.month, date.day);

/// 次日 00:00 —— 与 [startOfDay] 一起构成**半开区间** `[start, end)`
///
/// 为什么不返回当天 `23:59:59`：`getRecordsByDateRange`
/// （`task_repository.dart`）的判定是
/// `!startTime.isBefore(start) && startTime.isBefore(end)`，
/// 半开区间正好与之匹配，而且**不会漏掉 `23:59:59.xxx` 的记录**。
/// 统计页 `_getDateRange()` 现在用的是闭区间 `23, 59, 59`，会漏掉最后一秒
/// 内的记录——不要照搬那个写法。
DateTime nextDayStart(DateTime date) =>
    DateTime(date.year, date.month, date.day + 1);
