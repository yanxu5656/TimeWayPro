/// 月历上某一天的简单标注（「9-11 高数期末考试」「抢回家的车票」）。
/// 时间是自由文本的一部分，不做结构化字段——标注要够轻。
class CalendarNote {
  final String id;
  final String dateKey; // 格式: yyyy-MM-dd
  final String text;
  final int sortOrder;
  final DateTime createdAt;

  CalendarNote({
    required this.id,
    required this.dateKey,
    required this.text,
    this.sortOrder = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date_key': dateKey,
      'text': text,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory CalendarNote.fromMap(Map<String, dynamic> map) {
    return CalendarNote(
      id: map['id'],
      dateKey: map['date_key'],
      text: map['text'],
      sortOrder: map['sort_order'] ?? 0,
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  CalendarNote copyWith({
    String? id,
    String? dateKey,
    String? text,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return CalendarNote(
      id: id ?? this.id,
      dateKey: dateKey ?? this.dateKey,
      text: text ?? this.text,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}