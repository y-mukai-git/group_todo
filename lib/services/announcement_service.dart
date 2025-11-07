import 'package:flutter/foundation.dart';
import '../data/models/announcement_model.dart';
import '../core/utils/api_client.dart';

/// お知らせサービス
class AnnouncementService {
  final ApiClient _apiClient = ApiClient();

  /// お知らせ一覧取得
  Future<List<AnnouncementModel>> getAnnouncements() async {
    try {
      debugPrint('[AnnouncementService] お知らせ取得開始');

      final response = await _apiClient.callFunction(
        functionName: 'get-announcements',
        body: {},
      );

      debugPrint('[AnnouncementService] レスポンス取得完了');

      if (response['success'] != true) {
        final errorMessage = response['error'] as String? ?? 'お知らせ一覧の取得に失敗しました';
        throw ApiException(message: errorMessage, statusCode: 200);
      }

      final List<dynamic> announcementsJson =
          response['announcements'] as List<dynamic>;
      final announcements = announcementsJson
          .map(
            (json) => AnnouncementModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();

      debugPrint('[AnnouncementService] ✅ お知らせ取得成功: ${announcements.length}件');
      return announcements;
    } catch (e) {
      debugPrint('[AnnouncementService] ❌ お知らせ取得エラー: $e');
      rethrow;
    }
  }
}
