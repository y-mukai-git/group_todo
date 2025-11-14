/// クイックアクションモデル
class QuickActionModel {
  final String id;
  final String groupId;
  final String name;
  final String? description;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int displayOrder;
  final List<QuickActionTemplateModel>? templates; // テンプレート一覧

  QuickActionModel({
    required this.id,
    required this.groupId,
    required this.name,
    this.description,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
    required this.displayOrder,
    this.templates,
  });

  /// JSONからモデル生成
  factory QuickActionModel.fromJson(Map<String, dynamic> json) {
    // templatesの処理（APIレスポンス形式対応）
    List<QuickActionTemplateModel>? templates;
    if (json['templates'] != null) {
      final templatesList = json['templates'] as List<dynamic>;
      templates = templatesList
          .map(
            (t) => QuickActionTemplateModel.fromJson(t as Map<String, dynamic>),
          )
          .toList();
    } else if (json['quick_action_templates'] != null) {
      final templatesList = json['quick_action_templates'] as List<dynamic>;
      templates = templatesList
          .map(
            (t) => QuickActionTemplateModel.fromJson(t as Map<String, dynamic>),
          )
          .toList();
    }

    return QuickActionModel(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      displayOrder: json['display_order'] as int? ?? 0,
      templates: templates,
    );
  }

  /// モデルをJSONに変換
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'group_id': groupId,
      'name': name,
      'description': description,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'display_order': displayOrder,
      if (templates != null)
        'templates': templates!.map((t) => t.toJson()).toList(),
    };
  }

  /// コピーメソッド
  QuickActionModel copyWith({
    String? id,
    String? groupId,
    String? name,
    String? description,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? displayOrder,
    List<QuickActionTemplateModel>? templates,
  }) {
    return QuickActionModel(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      name: name ?? this.name,
      description: description ?? this.description,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      displayOrder: displayOrder ?? this.displayOrder,
      templates: templates ?? this.templates,
    );
  }
}

/// クイックアクションテンプレートモデル
class QuickActionTemplateModel {
  final String id;
  final String quickActionId;
  final String title;
  final String? description;
  final int? deadlineDaysAfter; // 生成から何日後に期限を設定するか（null = 期限なし）
  final List<String>? assignedUserIds; // 担当者のUUID配列
  final int displayOrder;
  final DateTime createdAt;

  QuickActionTemplateModel({
    required this.id,
    required this.quickActionId,
    required this.title,
    this.description,
    this.deadlineDaysAfter,
    this.assignedUserIds,
    required this.displayOrder,
    required this.createdAt,
  });

  /// JSONからモデル生成
  factory QuickActionTemplateModel.fromJson(Map<String, dynamic> json) {
    // assigned_user_idsの処理
    List<String>? assignedUserIds;
    if (json['assigned_user_ids'] != null) {
      assignedUserIds = List<String>.from(
        json['assigned_user_ids'] as List<dynamic>,
      );
    }

    return QuickActionTemplateModel(
      id: json['id'] as String,
      quickActionId: json['quick_action_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      deadlineDaysAfter: json['deadline_days_after'] as int?,
      assignedUserIds: assignedUserIds,
      displayOrder: json['display_order'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// モデルをJSONに変換
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'quick_action_id': quickActionId,
      'title': title,
      'description': description,
      'deadline_days_after': deadlineDaysAfter,
      'assigned_user_ids': assignedUserIds,
      'display_order': displayOrder,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// コピーメソッド
  QuickActionTemplateModel copyWith({
    String? id,
    String? quickActionId,
    String? title,
    String? description,
    int? deadlineDaysAfter,
    List<String>? assignedUserIds,
    int? displayOrder,
    DateTime? createdAt,
  }) {
    return QuickActionTemplateModel(
      id: id ?? this.id,
      quickActionId: quickActionId ?? this.quickActionId,
      title: title ?? this.title,
      description: description ?? this.description,
      deadlineDaysAfter: deadlineDaysAfter ?? this.deadlineDaysAfter,
      assignedUserIds: assignedUserIds ?? this.assignedUserIds,
      displayOrder: displayOrder ?? this.displayOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
