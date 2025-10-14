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

      if (response['success'] == true && response['announcements'] != null) {
        final List<dynamic> announcementsJson = response['announcements'];
        final announcements = announcementsJson
            .map((json) => AnnouncementModel.fromJson(json))
            .toList();

        debugPrint(
          '[AnnouncementService] ✅ お知らせ取得成功: ${announcements.length}件',
        );
        return announcements;
      } else {
        debugPrint('[AnnouncementService] ❌ お知らせ取得失敗: ${response['error']}');
        throw Exception('お知らせの取得に失敗しました');
      }
    } catch (e) {
      debugPrint('[AnnouncementService] ❌ 例外発生: $e');
      rethrow;
    }
  }
}
