import 'package:flutter/foundation.dart';
import '../data/models/inquiry_type.dart';
import '../core/utils/api_client.dart';

/// お問い合わせサービス
class ContactService {
  final ApiClient _apiClient = ApiClient();

  /// お問い合わせを送信
  Future<void> submitInquiry({
    required String userId,
    required InquiryType type,
    required String message,
  }) async {
    try {
      final response = await _apiClient.callFunction(
        functionName: 'submit-contact-inquiry',
        body: {
          'user_id': userId,
          'inquiry_type': type.value,
          'message': message,
        },
      );

      if (response['success'] != true) {
        final errorMessage = response['error'] as String? ?? 'お問い合わせの送信に失敗しました';
        throw ApiException(message: errorMessage, statusCode: 200);
      }
    } catch (e) {
      debugPrint('[ContactService] ❌ お問い合わせ送信エラー: $e');
      rethrow;
    }
  }
}
