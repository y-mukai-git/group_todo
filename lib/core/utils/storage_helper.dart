import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ローカルストレージ管理ヘルパー（SharedPreferences）
/// 認証情報・アプリ設定のみを保存（軽量データ専用）
class StorageHelper {
  static const String _keyUserId = 'user_id';
  static const String _keyDisplayName = 'display_name';
  static const String _keyLastSyncTime = 'last_sync_time';

  /// ユーザーID保存
  static Future<void> saveUserId(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUserId, userId);
    } catch (e) {
      debugPrint('[StorageHelper] ❌ ユーザーID保存エラー: $e');
      rethrow;
    }
  }

  /// ユーザーID取得
  static Future<String?> getUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString(_keyUserId);
      if (userId == null) {
        debugPrint('[StorageHelper] ℹ️ ユーザーID未登録');
      }
      return userId;
    } catch (e) {
      debugPrint('[StorageHelper] ❌ ユーザーID取得エラー: $e');
      return null;
    }
  }

  /// ユーザー表示名保存
  static Future<void> saveDisplayName(String displayName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyDisplayName, displayName);
    } catch (e) {
      debugPrint('[StorageHelper] ❌ 表示名保存エラー: $e');
      rethrow;
    }
  }

  /// ユーザー表示名取得
  static Future<String?> getDisplayName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyDisplayName);
    } catch (e) {
      debugPrint('[StorageHelper] ❌ 表示名取得エラー: $e');
      return null;
    }
  }

  /// 最終同期日時保存
  static Future<void> saveLastSyncTime(DateTime syncTime) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLastSyncTime, syncTime.toIso8601String());
    } catch (e) {
      debugPrint('[StorageHelper] ❌ 最終同期日時保存エラー: $e');
      rethrow;
    }
  }

  /// 最終同期日時取得
  static Future<DateTime?> getLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final syncTimeStr = prefs.getString(_keyLastSyncTime);
      if (syncTimeStr != null) {
        return DateTime.parse(syncTimeStr);
      }
      return null;
    } catch (e) {
      debugPrint('[StorageHelper] ❌ 最終同期日時取得エラー: $e');
      return null;
    }
  }

  /// 全データクリア（ログアウト・データ引き継ぎ時）
  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      debugPrint('[StorageHelper] ❌ 全データクリアエラー: $e');
      rethrow;
    }
  }

  /// ユーザー登録済みチェック
  static Future<bool> isUserRegistered() async {
    final userId = await getUserId();
    return userId != null && userId.isNotEmpty;
  }
}
