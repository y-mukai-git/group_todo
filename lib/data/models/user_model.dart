/// ユーザーモデル
class UserModel {
  final String id;
  final String deviceId;
  final String displayName;
  final String displayId; // 8桁英数字ランダムID（表示・引き継ぎ用）
  final String? avatarUrl; // プロフィール画像URL（Supabase Storage）
  final String? personalGroupId; // 個人用グループID
  final String? transferCode;
  final DateTime? transferCodeExpiresAt;
  final bool notificationDeadline;
  final bool notificationNewTodo;
  final bool notificationAssigned;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.id,
    required this.deviceId,
    required this.displayName,
    required this.displayId,
    this.avatarUrl,
    this.personalGroupId,
    this.transferCode,
    this.transferCodeExpiresAt,
    required this.notificationDeadline,
    required this.notificationNewTodo,
    required this.notificationAssigned,
    required this.createdAt,
    required this.updatedAt,
  });

  /// JSONからモデル生成
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      deviceId: json['device_id'] as String,
      displayName: json['display_name'] as String,
      displayId: json['display_id'] as String,
      avatarUrl: json['avatar_url'] as String?,
      personalGroupId: json['personal_group_id'] as String?,
      transferCode: json['transfer_code'] as String?,
      transferCodeExpiresAt: json['transfer_code_expires_at'] != null
          ? DateTime.parse(json['transfer_code_expires_at'] as String)
          : null,
      notificationDeadline: json['notification_deadline'] as bool,
      notificationNewTodo: json['notification_new_todo'] as bool,
      notificationAssigned: json['notification_assigned'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// モデルをJSONに変換
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'device_id': deviceId,
      'display_name': displayName,
      'display_id': displayId,
      'avatar_url': avatarUrl,
      'personal_group_id': personalGroupId,
      'transfer_code': transferCode,
      'transfer_code_expires_at': transferCodeExpiresAt?.toIso8601String(),
      'notification_deadline': notificationDeadline,
      'notification_new_todo': notificationNewTodo,
      'notification_assigned': notificationAssigned,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// コピーメソッド
  UserModel copyWith({
    String? id,
    String? deviceId,
    String? displayName,
    String? displayId,
    String? avatarUrl,
    String? personalGroupId,
    String? transferCode,
    DateTime? transferCodeExpiresAt,
    bool? notificationDeadline,
    bool? notificationNewTodo,
    bool? notificationAssigned,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      displayName: displayName ?? this.displayName,
      displayId: displayId ?? this.displayId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      personalGroupId: personalGroupId ?? this.personalGroupId,
      transferCode: transferCode ?? this.transferCode,
      transferCodeExpiresAt:
          transferCodeExpiresAt ?? this.transferCodeExpiresAt,
      notificationDeadline: notificationDeadline ?? this.notificationDeadline,
      notificationNewTodo: notificationNewTodo ?? this.notificationNewTodo,
      notificationAssigned: notificationAssigned ?? this.notificationAssigned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
