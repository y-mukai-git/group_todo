/// グループモデル
class GroupModel {
  final String id;
  final String name;
  final String? description;
  final String iconColor;
  final String ownerId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  GroupModel({
    required this.id,
    required this.name,
    this.description,
    required this.iconColor,
    required this.ownerId,
    this.createdAt,
    this.updatedAt,
  });

  /// JSONからモデル生成
  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      iconColor: json['icon_color'] as String,
      ownerId: json['owner_id'] as String,
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
      'icon_color': iconColor,
      'owner_id': ownerId,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// コピーメソッド
  GroupModel copyWith({
    String? id,
    String? name,
    String? description,
    String? iconColor,
    String? ownerId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GroupModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconColor: iconColor ?? this.iconColor,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
