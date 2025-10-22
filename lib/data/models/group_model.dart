/// グループモデル
class GroupModel {
  final String id;
  final String name;
  final String? description;
  final String? category; // カテゴリ (shopping/housework/work/hobby/other)
  final String? iconUrl; // グループアイコン画像URL（Supabase Storage）
  final String? signedIconUrl; // 署名付き一時URL（Edge Functionから取得）
  final String ownerId;
  final int displayOrder; // ユーザーごとの表示順序
  final DateTime? createdAt;
  final DateTime? updatedAt;

  GroupModel({
    required this.id,
    required this.name,
    this.description,
    this.category,
    this.iconUrl,
    this.signedIconUrl,
    required this.ownerId,
    this.displayOrder = 0,
    this.createdAt,
    this.updatedAt,
  });

  /// JSONからモデル生成
  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      category: json['category'] as String?,
      iconUrl: json['icon_url'] as String?,
      signedIconUrl: json['signed_icon_url'] as String?,
      ownerId: json['owner_id'] as String,
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// モデルをJSONに変換
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'icon_url': iconUrl,
      'owner_id': ownerId,
      'display_order': displayOrder,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// コピーメソッド
  GroupModel copyWith({
    String? id,
    String? name,
    String? description,
    String? category,
    String? iconUrl,
    String? signedIconUrl,
    String? ownerId,
    int? displayOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GroupModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      iconUrl: iconUrl ?? this.iconUrl,
      signedIconUrl: signedIconUrl ?? this.signedIconUrl,
      ownerId: ownerId ?? this.ownerId,
      displayOrder: displayOrder ?? this.displayOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
