enum TimerType {
  countUp, // 正计时
  countDown, // 倒计时
}

enum RepeatType {
  none, // 不可重复
  daily, // 每天
  weekly, // 每周
  monthly, // 每月
}

class Task {
  final String id;
  final String title;
  final String? description;
  final TimerType timerType;
  final int? duration; // 倒计时时长（秒）
  final RepeatType repeatType;
  final int repeatCount; // 每天重复次数
  final DateTime? dueDate;
  final int? reminderMinutes; // 提前提醒分钟数
  final bool isCompleted;
  final int completedCount; // 已完成次数
  final DateTime? lastCompletedDate; // 上次完成日期（用于每日重置）
  final DateTime createdAt;
  final DateTime updatedAt;

  Task({
    required this.id,
    required this.title,
    this.description,
    this.timerType = TimerType.countUp,
    this.duration,
    this.repeatType = RepeatType.none,
    this.repeatCount = 1,
    this.dueDate,
    this.reminderMinutes,
    this.isCompleted = false,
    this.completedCount = 0,
    this.lastCompletedDate,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'timer_type': timerType.index,
      'duration': duration,
      'repeat_type': repeatType.index,
      'repeat_count': repeatCount,
      'due_date': dueDate?.toIso8601String(),
      'reminder_minutes': reminderMinutes,
      'is_completed': isCompleted ? 1 : 0,
      'completed_count': completedCount,
      'last_completed_date': lastCompletedDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    // 安全的枚举值解析
    TimerType parseTimerType(dynamic value) {
      if (value == null || value is! int || value >= TimerType.values.length) {
        return TimerType.countUp;
      }
      return TimerType.values[value];
    }

    RepeatType parseRepeatType(dynamic value) {
      if (value == null || value is! int || value >= RepeatType.values.length) {
        return RepeatType.none;
      }
      return RepeatType.values[value];
    }

    return Task(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      timerType: parseTimerType(map['timer_type']),
      duration: map['duration'],
      repeatType: parseRepeatType(map['repeat_type']),
      repeatCount: map['repeat_count'] ?? 1,
      dueDate: map['due_date'] != null ? DateTime.parse(map['due_date']) : null,
      reminderMinutes: map['reminder_minutes'],
      isCompleted: map['is_completed'] == 1,
      completedCount: map['completed_count'] ?? 0,
      lastCompletedDate: map['last_completed_date'] != null
          ? DateTime.parse(map['last_completed_date'])
          : null,
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  Task copyWith({
    String? id,
    String? title,
    String? description,
    TimerType? timerType,
    int? duration,
    RepeatType? repeatType,
    int? repeatCount,
    DateTime? dueDate,
    int? reminderMinutes,
    bool? isCompleted,
    int? completedCount,
    DateTime? lastCompletedDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      timerType: timerType ?? this.timerType,
      duration: duration ?? this.duration,
      repeatType: repeatType ?? this.repeatType,
      repeatCount: repeatCount ?? this.repeatCount,
      dueDate: dueDate ?? this.dueDate,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      isCompleted: isCompleted ?? this.isCompleted,
      completedCount: completedCount ?? this.completedCount,
      lastCompletedDate: lastCompletedDate ?? this.lastCompletedDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isRepeatable => repeatType != RepeatType.none;

  // 检查是否需要重置每日完成次数
  bool get needsDailyReset {
    if (!isRepeatable) return false;
    if (lastCompletedDate == null) return false;
    final now = DateTime.now();
    final lastDate = lastCompletedDate!;
    return now.year != lastDate.year ||
        now.month != lastDate.month ||
        now.day != lastDate.day;
  }

  String get repeatTypeText {
    switch (repeatType) {
      case RepeatType.none:
        return '不重复';
      case RepeatType.daily:
        return '每天';
      case RepeatType.weekly:
        return '每周';
      case RepeatType.monthly:
        return '每月';
    }
  }

  String get timerTypeText {
    switch (timerType) {
      case TimerType.countUp:
        return '正计时';
      case TimerType.countDown:
        return '倒计时';
    }
  }

  String get durationText {
    if (duration == null) return '';
    final hours = duration! ~/ 3600;
    final minutes = (duration! % 3600) ~/ 60;
    final seconds = duration! % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }
}
