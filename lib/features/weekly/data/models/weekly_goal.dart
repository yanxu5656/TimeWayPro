enum WeeklyProgressMode { stages, count }

class WeeklyMilestone {
  final String id;
  final String title;
  final bool isCompleted;
  final int sortOrder;

  const WeeklyMilestone({
    required this.id,
    required this.title,
    this.isCompleted = false,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'title': title,
    'is_completed': isCompleted ? 1 : 0,
    'sort_order': sortOrder,
  };

  factory WeeklyMilestone.fromMap(Map<String, dynamic> map) {
    return WeeklyMilestone(
      id: map['id'],
      title: map['title'],
      isCompleted: map['is_completed'] == 1,
      sortOrder: map['sort_order'] ?? 0,
    );
  }

  WeeklyMilestone copyWith({
    String? id,
    String? title,
    bool? isCompleted,
    int? sortOrder,
  }) {
    return WeeklyMilestone(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

/// 每周目标。
///
/// 与每日待办（DailyTask）的区别只有一个：按「周」归档而不是按「天」。
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
  final WeeklyProgressMode? progressMode;
  final List<WeeklyMilestone> milestones;

  WeeklyGoal({
    required this.id,
    required this.title,
    bool isCompleted = false,
    required this.weekKey,
    this.sortOrder = 0,
    required this.createdAt,
    WeeklyProgressMode? progressMode,
    List<WeeklyMilestone> milestones = const <WeeklyMilestone>[],
  }) : milestones = List<WeeklyMilestone>.unmodifiable(
         milestones.toList()..sort(
           (WeeklyMilestone a, WeeklyMilestone b) =>
               a.sortOrder.compareTo(b.sortOrder),
         ),
       ),
       progressMode = milestones.isEmpty
           ? null
           : (progressMode ?? WeeklyProgressMode.stages),
       isCompleted = milestones.isEmpty
           ? isCompleted
           : milestones.every(
               (WeeklyMilestone milestone) => milestone.isCompleted,
             );

  bool get hasMilestones => milestones.isNotEmpty;

  int get completedMilestones => milestones
      .where((WeeklyMilestone milestone) => milestone.isCompleted)
      .length;

  double get progress => hasMilestones
      ? completedMilestones / milestones.length
      : (isCompleted ? 1 : 0);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'is_completed': isCompleted ? 1 : 0,
      'week_key': weekKey,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
      'progress_mode': progressMode?.name,
      'milestones': milestones
          .map((WeeklyMilestone milestone) => milestone.toMap())
          .toList(),
    };
  }

  factory WeeklyGoal.fromMap(Map<String, dynamic> map) {
    final List<WeeklyMilestone> milestones = <WeeklyMilestone>[];
    final dynamic rawMilestones = map['milestones'];
    if (rawMilestones is List) {
      for (int i = 0; i < rawMilestones.length; i++) {
        final dynamic raw = rawMilestones[i];
        if (raw is! Map<String, dynamic>) continue;
        try {
          milestones.add(
            WeeklyMilestone.fromMap(<String, dynamic>{
              ...raw,
              'id': raw['id'] ?? '${map['id']}_milestone_$i',
              'sort_order': raw['sort_order'] ?? i,
            }),
          );
        } catch (_) {
          continue;
        }
      }
    }

    final WeeklyProgressMode? progressMode = switch (map['progress_mode']) {
      'stages' => WeeklyProgressMode.stages,
      'count' => WeeklyProgressMode.count,
      _ => null,
    };

    return WeeklyGoal(
      id: map['id'],
      title: map['title'],
      isCompleted: map['is_completed'] == 1,
      weekKey: map['week_key'],
      sortOrder: map['sort_order'] ?? 0,
      createdAt: DateTime.parse(map['created_at']),
      progressMode: progressMode,
      milestones: milestones,
    );
  }

  WeeklyGoal copyWith({
    String? id,
    String? title,
    bool? isCompleted,
    String? weekKey,
    int? sortOrder,
    DateTime? createdAt,
    WeeklyProgressMode? progressMode,
    List<WeeklyMilestone>? milestones,
  }) {
    return WeeklyGoal(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      weekKey: weekKey ?? this.weekKey,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      progressMode: progressMode ?? this.progressMode,
      milestones: milestones ?? this.milestones,
    );
  }

  WeeklyGoal toggleMilestone(String milestoneId) {
    final List<WeeklyMilestone> updated = milestones.toList();
    final int index = updated.indexWhere(
      (WeeklyMilestone milestone) => milestone.id == milestoneId,
    );
    if (index < 0) return this;
    updated[index] = updated[index].copyWith(
      isCompleted: !updated[index].isCompleted,
    );
    return copyWith(milestones: updated);
  }

  WeeklyGoal setAllCompleted(bool completed) {
    return copyWith(
      isCompleted: completed,
      milestones: <WeeklyMilestone>[
        for (final WeeklyMilestone milestone in milestones)
          milestone.copyWith(isCompleted: completed),
      ],
    );
  }
}
