/// お知らせモデル
class AnnouncementModel {
  final String id;
  final String version;
  final String title;
  final String content;
  final DateTime publishedAt;
  final DateTime createdAt;

  AnnouncementModel({
    required this.id,
    required this.version,
    required this.title,
    required this.content,
    required this.publishedAt,
    required this.createdAt,
  });

  /// JSONからAnnouncementModelを生成
  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    return AnnouncementModel(
      id: json['id'] as String,
      version: json['version'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      publishedAt: DateTime.parse(json['published_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// AnnouncementModelをJSONに変換
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'version': version,
      'title': title,
      'content': content,
      'published_at': publishedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
