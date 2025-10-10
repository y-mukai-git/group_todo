import 'package:flutter/foundation.dart';
import '../core/utils/api_client.dart';
import '../core/utils/device_id_helper.dart';
import '../data/models/user_model.dart';

/// ユーザー管理サービス
class UserService {
  final ApiClient _apiClient = ApiClient();

  /// 新規ユーザー作成
  Future<UserModel> createUser() async {
    try {
      final deviceId = await DeviceIdHelper.getDeviceId();

      final response = await _apiClient.callFunction(
        functionName: 'create-user',
        body: {'device_id': deviceId},
      );

      debugPrint('[UserService] ✅ ユーザー作成成功');
      return UserModel.fromJson(response['user'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[UserService] ❌ ユーザー作成エラー: $e');
      rethrow;
    }
  }

  /// デバイスIDでユーザー取得
  Future<UserModel?> getUserByDevice() async {
    try {
      final deviceId = await DeviceIdHelper.getDeviceId();

      final response = await _apiClient.callFunction(
        functionName: 'get-user-by-device',
        body: {'device_id': deviceId},
      );

      if (response['user'] == null) {
        debugPrint('[UserService] ⚠️ ユーザー未登録');
        return null;
      }

      debugPrint('[UserService] ✅ ユーザー取得成功');
      return UserModel.fromJson(response['user'] as Map<String, dynamic>);
    } catch (e) {
      // 404エラーは新規ユーザーとして扱う（エラーではなくnullを返す）
      if (e is ApiException && e.statusCode == 404) {
        debugPrint('[UserService] ⚠️ ユーザー未登録（新規ユーザー）');
        return null;
      }
      // その他のエラーは再スロー
      debugPrint('[UserService] ❌ ユーザー取得エラー: $e');
      rethrow;
    }
  }

  /// ユーザープロフィール更新
  Future<UserModel> updateUserProfile({
    required String userId,
    required String displayName,
  }) async {
    try {
      final response = await _apiClient.callFunction(
        functionName: 'update-user-profile',
        body: {'user_id': userId, 'display_name': displayName},
      );

      debugPrint('[UserService] ✅ プロフィール更新成功');
      return UserModel.fromJson(response['user'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[UserService] ❌ プロフィール更新エラー: $e');
      rethrow;
    }
  }

  /// 引き継ぎ用パスワード設定
  Future<Map<String, String>> setTransferPassword({
    required String userId,
    required String password,
  }) async {
    try {
      final response = await _apiClient.callFunction(
        functionName: 'set-transfer-password',
        body: {'user_id': userId, 'password': password},
      );

      final result = {
        'display_id': response['display_id'] as String, // 8桁displayIdを返す
        'password': password,
      };
      debugPrint('[UserService] ✅ 引き継ぎ用パスワード設定成功');
      return result;
    } catch (e) {
      debugPrint('[UserService] ❌ 引き継ぎ用パスワード設定エラー: $e');
      rethrow;
    }
  }

  /// データ引き継ぎ実行（8桁ユーザーID + パスワード）
  Future<UserModel> transferUserData({
    required String userId, // 8桁displayId
    required String password,
  }) async {
    try {
      final newDeviceId = await DeviceIdHelper.getDeviceId();

      final response = await _apiClient.callFunction(
        functionName: 'transfer-user-data',
        body: {
          'display_id': userId, // 8桁displayIdをパラメータとして送信
          'password': password,
          'new_device_id': newDeviceId,
        },
      );

      debugPrint('[UserService] ✅ データ引き継ぎ成功');
      return UserModel.fromJson(response['user'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[UserService] ❌ データ引き継ぎエラー: $e');
      rethrow;
    }
  }
}
