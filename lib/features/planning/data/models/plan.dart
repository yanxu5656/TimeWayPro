class Plan {
  final String id;
  final String title;
  final String? description;
  final String? parentId;
  final double progress; // 0.0 - 1.0
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  Plan({
    required this.id,
    required this.title,
    this.description,
    this.parentId,
    this.progress = 0.0,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'parent_id': parentId,
      'progress': progress,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Plan.fromMap(Map<String, dynamic> map) {
    return Plan(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      parentId: map['parent_id'],
      progress: (map['progress'] as num).toDouble(),
      sortOrder: map['sort_order'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  Plan copyWith({
    String? id,
    String? title,
    String? description,
    String? parentId,
    double? progress,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Plan(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      parentId: parentId ?? this.parentId,
      progress: progress ?? this.progress,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get progressText => '${(progress * 100).toInt()}%';
}
