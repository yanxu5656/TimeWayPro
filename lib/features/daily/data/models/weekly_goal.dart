/// 本周目标。
///
/// 与 [DailyTask] 的区别只有一个：按「周」归档而不是按「天」。
/// 序列化风格与项目里其它模型一致——Map key 用 snake_case、bool 存 0/1、
/// 日期存 ISO8601。
class WeeklyGoal {
  final String id;
  final String title;
  final bool isCompleted;

  /// 所属周，形如 `2026-09-14`（该周周一的日期）。
  ///
  /// 不用 ISO 周号的理由见 `lib/core/utils/week.dart`：周号有跨年边界问题，
  /// 而周一日期既能正确排序，又与项目里已有的 `date_key` 风格对齐。
  final String weekKey;

  final int sortOrder;
  final DateTime createdAt;

  WeeklyGoal({
    required this.id,
    required this.title,
    this.isCompleted = false,
    required this.weekKey,
    this.sortOrder = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'is_completed': isCompleted ? 1 : 0,
      'week_key': weekKey,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory WeeklyGoal.fromMap(Map<String, dynamic> map) {
    return WeeklyGoal(
      id: map['id'],
      title: map['title'],
      isCompleted: map['is_completed'] == 1,
      weekKey: map['week_key'],
      sortOrder: map['sort_order'] ?? 0,
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  WeeklyGoal copyWith({
    String? id,
    String? title,
    bool? isCompleted,
    String? weekKey,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return WeeklyGoal(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      weekKey: weekKey ?? this.weekKey,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
