import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import '../data/models/error_log_model.dart';
import '../core/utils/api_client.dart';

/// エラーログ管理Service
class ErrorLogService {
  static const String _errorLogsKey = 'error_logs';

  /// エラーログ記録（メインメソッド）
  ///
  /// 1. ローカルに保存
  /// 2. Edge Function経由でDB送信試行
  /// 3. DB送信成功 → ローカル削除、失敗 → ローカル保持
  Future<ErrorLogModel> logError({
    String? userId,
    required String errorType,
    required String errorMessage,
    String? stackTrace,
    String? screenName,
  }) async {
    try {
      // デバイス情報取得
      final deviceInfo = await _getDeviceInfo();

      // エラーログモデル作成
      final errorLog = ErrorLogModel.create(
        userId: userId,
        errorType: errorType,
        errorMessage: errorMessage,
        stackTrace: stackTrace,
        screenName: screenName,
        deviceInfo: deviceInfo,
      );

      // ローカルに保存
      await _saveErrorLocally(errorLog);

      // Edge Function経由でDB送信試行
      final sent = await _sendToDatabase(errorLog);

      if (sent) {
        // 送信成功 → ローカルから削除
        await _removeErrorLocally(errorLog.id);
        return errorLog.markAsSent();
      }

      return errorLog;
    } catch (e) {
      debugPrint('[ErrorLogService] ❌ エラーログ記録失敗: $e');
      rethrow;
    }
  }

  /// 未送信エラーログを一括送信
  Future<void> sendPendingErrors() async {
    try {
      final errorLogs = await _loadErrorsLocally();
      if (errorLogs.isEmpty) return;

      debugPrint('[ErrorLogService] 未送信エラーログ: ${errorLogs.length}件');

      for (final errorLog in errorLogs) {
        final sent = await _sendToDatabase(errorLog);
        if (sent) {
          await _removeErrorLocally(errorLog.id);
        }
      }
    } catch (e) {
      debugPrint('[ErrorLogService] ❌ 未送信エラーログ送信失敗: $e');
    }
  }

  /// Edge Function経由でDB送信
  Future<bool> _sendToDatabase(ErrorLogModel errorLog) async {
    try {
      final response = await ApiClient().callFunction(
        functionName: 'log-error',
        body: errorLog.toJson(),
        timeout: const Duration(seconds: 10),
      );

      if (response['success'] != true) {
        debugPrint('[ErrorLogService] ❌ DB送信失敗: ${response['error']}');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('[ErrorLogService] ❌ DB送信エラー: $e');
      return false;
    }
  }

  /// エラーログをローカル保存
  Future<void> _saveErrorLocally(ErrorLogModel errorLog) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final errorLogs = await _loadErrorsLocally();
      errorLogs.add(errorLog);

      final jsonList = errorLogs.map((e) => e.toJson()).toList();
      await prefs.setString(_errorLogsKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('[ErrorLogService] ❌ ローカル保存失敗: $e');
      rethrow;
    }
  }

  /// ローカルからエラーログ削除
  Future<void> _removeErrorLocally(String errorId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final errorLogs = await _loadErrorsLocally();
      errorLogs.removeWhere((e) => e.id == errorId);

      final jsonList = errorLogs.map((e) => e.toJson()).toList();
      await prefs.setString(_errorLogsKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('[ErrorLogService] ❌ ローカル削除失敗: $e');
    }
  }

  /// ローカルからエラーログ読み込み
  Future<List<ErrorLogModel>> _loadErrorsLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_errorLogsKey);

      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map((json) => ErrorLogModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[ErrorLogService] ❌ ローカル読み込み失敗: $e');
      return [];
    }
  }

  /// デバイス情報取得
  Future<Map<String, dynamic>> _getDeviceInfo() async {
    try {
      final deviceInfoPlugin = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        return {
          'platform': 'android',
          'model': androidInfo.model,
          'version': androidInfo.version.release,
          'sdkInt': androidInfo.version.sdkInt,
        };
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        return {
          'platform': 'ios',
          'model': iosInfo.model,
          'systemName': iosInfo.systemName,
          'systemVersion': iosInfo.systemVersion,
        };
      }

      return {'platform': 'unknown'};
    } catch (e) {
      debugPrint('[ErrorLogService] ❌ デバイス情報取得失敗: $e');
      return {'platform': 'error'};
    }
  }
}
