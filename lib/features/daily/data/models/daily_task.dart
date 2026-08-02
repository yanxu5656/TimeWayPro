// 时间段
enum TimePeriod {
  morning, // 上午
  afternoon, // 下午
  evening, // 晚上
}

class DailyTask {
  final String id;
  final String title;
  final String? description;
  final TimePeriod timePeriod;
  final bool isCompleted;
  final String dateKey; // 格式: yyyy-MM-dd
  final int sortOrder;
  final DateTime createdAt;

  DailyTask({
    required this.id,
    required this.title,
    this.description,
    required this.timePeriod,
    this.isCompleted = false,
    required this.dateKey,
    this.sortOrder = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'time_period': timePeriod.index,
      'is_completed': isCompleted ? 1 : 0,
      'date_key': dateKey,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory DailyTask.fromMap(Map<String, dynamic> map) {
    return DailyTask(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      timePeriod: TimePeriod.values[map['time_period'] ?? 0],
      isCompleted: map['is_completed'] == 1,
      dateKey: map['date_key'],
      sortOrder: map['sort_order'] ?? 0,
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  DailyTask copyWith({
    String? id,
    String? title,
    String? description,
    TimePeriod? timePeriod,
    bool? isCompleted,
    String? dateKey,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return DailyTask(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      timePeriod: timePeriod ?? this.timePeriod,
      isCompleted: isCompleted ?? this.isCompleted,
      dateKey: dateKey ?? this.dateKey,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get timePeriodText {
    switch (timePeriod) {
      case TimePeriod.morning:
        return '上午';
      case TimePeriod.afternoon:
        return '下午';
      case TimePeriod.evening:
        return '晚上';
    }
  }
}
