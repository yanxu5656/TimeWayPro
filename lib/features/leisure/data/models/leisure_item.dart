/// 闲时清单条目：不紧急但想做的事（打一款新游戏、看某部片子…）。
class LeisureItem {
  final String id;
  final String title;
  final String? note;
  final bool isDone;
  final int sortOrder;
  final DateTime createdAt;

  LeisureItem({
    required this.id,
    required this.title,
    this.note,
    this.isDone = false,
    this.sortOrder = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'note': note,
      'is_done': isDone ? 1 : 0,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory LeisureItem.fromMap(Map<String, dynamic> map) {
    return LeisureItem(
      id: map['id'],
      title: map['title'],
      note: map['note'],
      isDone: map['is_done'] == 1,
      sortOrder: map['sort_order'] ?? 0,
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  LeisureItem copyWith({
    String? id,
    String? title,
    String? note,
    bool? isDone,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return LeisureItem(
      id: id ?? this.id,
      title: title ?? this.title,
      note: note ?? this.note,
      isDone: isDone ?? this.isDone,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}