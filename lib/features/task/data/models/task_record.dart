class TaskRecord {
  final String id;
  final String taskId;
  final DateTime startTime;
  final DateTime? endTime;
  final int duration; // 实际用时（秒）
  final DateTime? completedAt;

  TaskRecord({
    required this.id,
    required this.taskId,
    required this.startTime,
    this.endTime,
    this.duration = 0,
    this.completedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'task_id': taskId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'duration': duration,
      'completed_at': completedAt?.toIso8601String(),
    };
  }

  factory TaskRecord.fromMap(Map<String, dynamic> map) {
    return TaskRecord(
      id: map['id'],
      taskId: map['task_id'],
      startTime: DateTime.parse(map['start_time']),
      endTime: map['end_time'] != null ? DateTime.parse(map['end_time']) : null,
      duration: map['duration'] ?? 0,
      completedAt: map['completed_at'] != null ? DateTime.parse(map['completed_at']) : null,
    );
  }

  TaskRecord copyWith({
    String? id,
    String? taskId,
    DateTime? startTime,
    DateTime? endTime,
    int? duration,
    DateTime? completedAt,
  }) {
    return TaskRecord(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      duration: duration ?? this.duration,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  String get durationText {
    final hours = duration ~/ 3600;
    final minutes = (duration % 3600) ~/ 60;
    final seconds = duration % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }
}
