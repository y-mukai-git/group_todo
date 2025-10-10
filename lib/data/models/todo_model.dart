/// TODOモデル
class TodoModel {
  final String id;
  final String groupId;
  final String? groupName; // グループ名（APIから取得）
  final String title;
  final String? description;
  final DateTime? dueDate;
  final bool isCompleted;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<String>? assignedUserIds;

  TodoModel({
    required this.id,
    required this.groupId,
    this.groupName,
    required this.title,
    this.description,
    this.dueDate,
    required this.isCompleted,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
    this.assignedUserIds,
  });

  /// JSONからモデル生成
  factory TodoModel.fromJson(Map<String, dynamic> json) {
    // APIが`deadline`と`due_date`両方の可能性があるため両方チェック
    final dueDateStr = json['deadline'] ?? json['due_date'];

    // assigneesから user_id リストを抽出（APIレスポンス形式対応）
    List<String>? assignedUserIds;
    if (json['assignees'] != null) {
      final assignees = json['assignees'] as List<dynamic>;
      assignedUserIds = assignees
          .map((a) => (a as Map<String, dynamic>)['user_id'] as String)
          .toList();
    } else if (json['assigned_users'] != null) {
      assignedUserIds = List<String>.from(
        json['assigned_users'] as List<dynamic>,
      );
    } else if (json['assigned_user_ids'] != null) {
      assignedUserIds = List<String>.from(
        json['assigned_user_ids'] as List<dynamic>,
      );
    }

    return TodoModel(
      id: json['id'] as String,
      groupId: (json['group_id'] ?? '') as String, // group_idがない場合は空文字
      groupName: json['group_name'] as String?, // グループ名（APIから取得）
      title: json['title'] as String,
      description: json['description'] as String?,
      dueDate: dueDateStr != null ? DateTime.parse(dueDateStr as String) : null,
      isCompleted: json['is_completed'] as bool,
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
      'due_date': dueDate?.toIso8601String(),
      'is_completed': isCompleted,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'assigned_user_ids': assignedUserIds,
    };
  }

  /// コピーメソッド
  TodoModel copyWith({
    String? id,
    String? groupId,
    String? title,
    String? description,
    DateTime? dueDate,
    bool? isCompleted,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? assignedUserIds,
  }) {
    return TodoModel(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      isCompleted: isCompleted ?? this.isCompleted,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      assignedUserIds: assignedUserIds ?? this.assignedUserIds,
    );
  }
}
