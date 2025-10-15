/// 定期TODOモデル
class RecurringTodoModel {
  final String id;
  final String groupId;
  final String title;
  final String? description;
  final String category; // 'shopping', 'housework', 'other'
  final String recurrencePattern; // 'daily', 'weekly', 'monthly'
  final List<int>? recurrenceDays; // weekly: 0-6 (0=日曜), monthly: 1-31 (-1=月末)
  final String generationTime; // 'HH:mm:ss'
  final DateTime nextGenerationAt;
  final bool isActive;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<String>? assignedUserIds; // recurring_todo_assignmentsから取得

  RecurringTodoModel({
    required this.id,
    required this.groupId,
    required this.title,
    this.description,
    required this.category,
    required this.recurrencePattern,
    this.recurrenceDays,
    required this.generationTime,
    required this.nextGenerationAt,
    required this.isActive,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
    this.assignedUserIds,
  });

  /// JSONからモデル生成
  factory RecurringTodoModel.fromJson(Map<String, dynamic> json) {
    // recurrence_daysの処理（INTEGER[]）
    List<int>? recurrenceDays;
    if (json['recurrence_days'] != null) {
      recurrenceDays = List<int>.from(json['recurrence_days'] as List<dynamic>);
    }

    // assigned_user_idsの処理（APIレスポンス形式対応）
    List<String>? assignedUserIds;
    if (json['assignees'] != null) {
      final assignees = json['assignees'] as List<dynamic>;
      assignedUserIds = assignees
          .map((a) => (a as Map<String, dynamic>)['user_id'] as String)
          .toList();
    } else if (json['recurring_todo_assignments'] != null) {
      final assignments = json['recurring_todo_assignments'] as List<dynamic>;
      assignedUserIds = assignments
          .map((a) => (a as Map<String, dynamic>)['user_id'] as String)
          .toList();
    } else if (json['assigned_user_ids'] != null) {
      assignedUserIds = List<String>.from(
        json['assigned_user_ids'] as List<dynamic>,
      );
    }

    return RecurringTodoModel(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      category: json['category'] as String,
      recurrencePattern: json['recurrence_pattern'] as String,
      recurrenceDays: recurrenceDays,
      generationTime: json['generation_time'] as String,
      nextGenerationAt: DateTime.parse(json['next_generation_at'] as String),
      isActive: json['is_active'] as bool,
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      assignedUserIds: assignedUserIds,
    );
  }

  /// モデルをJSONに変換
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'group_id': groupId,
      'title': title,
      'description': description,
      'category': category,
      'recurrence_pattern': recurrencePattern,
      'recurrence_days': recurrenceDays,
      'generation_time': generationTime,
      'next_generation_at': nextGenerationAt.toIso8601String(),
      'is_active': isActive,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'assigned_user_ids': assignedUserIds,
    };
  }

  /// コピーメソッド
  RecurringTodoModel copyWith({
    String? id,
    String? groupId,
    String? title,
    String? description,
    String? category,
    String? recurrencePattern,
    List<int>? recurrenceDays,
    String? generationTime,
    DateTime? nextGenerationAt,
    bool? isActive,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? assignedUserIds,
  }) {
    return RecurringTodoModel(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      recurrencePattern: recurrencePattern ?? this.recurrencePattern,
      recurrenceDays: recurrenceDays ?? this.recurrenceDays,
      generationTime: generationTime ?? this.generationTime,
      nextGenerationAt: nextGenerationAt ?? this.nextGenerationAt,
      isActive: isActive ?? this.isActive,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      assignedUserIds: assignedUserIds ?? this.assignedUserIds,
    );
  }
}
