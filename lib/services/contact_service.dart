import '../data/models/inquiry_type.dart';
import '../core/utils/api_client.dart';

/// お問い合わせサービス
class ContactService {
  final ApiClient _apiClient = ApiClient();

  /// お問い合わせを送信
  Future<bool> submitInquiry({
    required String userId,
    required InquiryType type,
    required String message,
  }) async {
    try {
      final result = await _apiClient.callFunction(
        functionName: 'submit-contact-inquiry',
        body: {
          'user_id': userId,
          'inquiry_type': type.value,
          'message': message,
        },
      );

      return result['success'] == true;
    } catch (e) {
      return false;
    }
  }
}
