/// ユーザーモデル
class UserModel {
  final String id;
  final String deviceId;
  final String displayName;
  final String displayId; // 8桁英数字ランダムID（表示・引き継ぎ用）
  final String? avatarUrl; // プロフィール画像URL（Supabase Storage）
  final String? signedAvatarUrl; // 署名付き一時URL（Edge Functionから取得）
  final bool notificationDeadline;
  final bool notificationNewTodo;
  final bool notificationAssigned;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? role; // 'owner' | 'member' | null(招待中)
  final bool isPending; // 承諾待ちフラグ

  UserModel({
    required this.id,
    required this.deviceId,
    required this.displayName,
    required this.displayId,
    this.avatarUrl,
    this.signedAvatarUrl,
    required this.notificationDeadline,
    required this.notificationNewTodo,
    required this.notificationAssigned,
    required this.createdAt,
    required this.updatedAt,
    this.role,
    this.isPending = false,
  });

  /// JSONからモデル生成
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      deviceId: json['device_id'] as String,
      displayName: json['display_name'] as String,
      displayId: json['display_id'] as String,
      avatarUrl: json['avatar_url'] as String?,
      signedAvatarUrl: json['signed_avatar_url'] as String?,
      notificationDeadline: json['notification_deadline'] as bool,
      notificationNewTodo: json['notification_new_todo'] as bool,
      notificationAssigned: json['notification_assigned'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      role: json['role'] as String?,
      isPending: json['is_pending'] as bool? ?? false,
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
    String? signedAvatarUrl,
    bool? notificationDeadline,
    bool? notificationNewTodo,
    bool? notificationAssigned,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? role,
    bool? isPending,
  }) {
    return UserModel(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      displayName: displayName ?? this.displayName,
      displayId: displayId ?? this.displayId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      signedAvatarUrl: signedAvatarUrl ?? this.signedAvatarUrl,
      notificationDeadline: notificationDeadline ?? this.notificationDeadline,
      notificationNewTodo: notificationNewTodo ?? this.notificationNewTodo,
      notificationAssigned: notificationAssigned ?? this.notificationAssigned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      role: role ?? this.role,
      isPending: isPending ?? this.isPending,
    );
  }
}
