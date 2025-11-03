/// グループ招待モデル
class GroupInvitationModel {
  final String id;
  final String groupId;
  final String inviterId;
  final String invitedUserId;
  final String invitedRole; // 'owner' or 'member'
  final String status; // 'pending', 'accepted', 'rejected'
  final DateTime invitedAt;
  final DateTime? respondedAt;
  // 追加フィールド（get-pending-invitations API用）
  final String? groupName;
  final String? groupIconUrl;
  final String? inviterName;
  final String? inviterIconUrl;

  GroupInvitationModel({
    required this.id,
    required this.groupId,
    required this.inviterId,
    required this.invitedUserId,
    required this.invitedRole,
    required this.status,
    required this.invitedAt,
    this.respondedAt,
    this.groupName,
    this.groupIconUrl,
    this.inviterName,
    this.inviterIconUrl,
  });

  /// JSONからモデル生成
  factory GroupInvitationModel.fromJson(Map<String, dynamic> json) {
    return GroupInvitationModel(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      inviterId: json['inviter_id'] as String,
      invitedUserId: json['invited_user_id'] as String? ?? '',
      invitedRole: json['invited_role'] as String,
      status: json['status'] as String? ?? 'pending',
      invitedAt: DateTime.parse(json['invited_at'] as String),
      respondedAt: json['responded_at'] != null
          ? DateTime.parse(json['responded_at'] as String)
          : null,
      groupName: json['group_name'] as String?,
      groupIconUrl: json['group_icon_url'] as String?,
      inviterName: json['inviter_name'] as String?,
      inviterIconUrl: json['inviter_icon_url'] as String?,
    );
  }

  /// モデルをJSONに変換
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'group_id': groupId,
      'inviter_id': inviterId,
      'invited_user_id': invitedUserId,
      'invited_role': invitedRole,
      'status': status,
      'invited_at': invitedAt.toIso8601String(),
      'responded_at': respondedAt?.toIso8601String(),
      'group_name': groupName,
      'group_icon_url': groupIconUrl,
      'inviter_name': inviterName,
      'inviter_icon_url': inviterIconUrl,
    };
  }

  /// コピーメソッド
  GroupInvitationModel copyWith({
    String? id,
    String? groupId,
    String? inviterId,
    String? invitedUserId,
    String? invitedRole,
    String? status,
    DateTime? invitedAt,
    DateTime? respondedAt,
    String? groupName,
    String? groupIconUrl,
    String? inviterName,
    String? inviterIconUrl,
  }) {
    return GroupInvitationModel(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      inviterId: inviterId ?? this.inviterId,
      invitedUserId: invitedUserId ?? this.invitedUserId,
      invitedRole: invitedRole ?? this.invitedRole,
      status: status ?? this.status,
      invitedAt: invitedAt ?? this.invitedAt,
      respondedAt: respondedAt ?? this.respondedAt,
      groupName: groupName ?? this.groupName,
      groupIconUrl: groupIconUrl ?? this.groupIconUrl,
      inviterName: inviterName ?? this.inviterName,
      inviterIconUrl: inviterIconUrl ?? this.inviterIconUrl,
    );
  }
}
