import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../config/environment_config.dart';
import '../constants/error_messages.dart';
import '../../services/error_log_service.dart';
import '../../presentation/widgets/maintenance_dialog.dart';

/// API呼び出し共通クラス
/// Supabase Edge Functionsへのリクエストを統一管理
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  final _config = EnvironmentConfig.instance;

  // 管理者フラグ（メンテナンスモードスキップ用）
  bool _isAdmin = false;
  // メンテナンス状態（管理者用アイコン表示用）
  bool _isMaintenance = false;

  /// 管理者フラグを設定
  void setAdminStatus(bool isAdmin) {
    _isAdmin = isAdmin;
    debugPrint('[ApiClient] 管理者フラグ設定: $_isAdmin');
  }

  /// メンテナンス状態を設定
  void setMaintenanceStatus(bool isMaintenance) {
    _isMaintenance = isMaintenance;
    debugPrint('[ApiClient] メンテナンス状態設定: $_isMaintenance');
  }

  /// 管理者フラグを取得
  bool get isAdmin => _isAdmin;

  /// メンテナンス状態を取得
  bool get isMaintenance => _isMaintenance;

  /// Edge Function呼び出し
  Future<Map<String, dynamic>> callFunction({
    required String functionName,
    required Map<String, dynamic> body,
    Duration timeout = const Duration(seconds: 30),
    BuildContext? context,
  }) async {
    try {
      // 未送信エラーログを送信試行（空チェックで即return）
      // log-error API呼び出し時はスキップ（無限ループ防止）
      if (functionName != 'log-error') {
        await ErrorLogService().sendPendingErrors();
      }

      final url = Uri.parse(
        '${_config.supabaseUrl}/functions/v1/$functionName',
      );

      // ヘッダー構築（管理者の場合はメンテナンススキップヘッダーを付与）
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${_config.supabaseAnonKey}',
      };
      if (_isAdmin) {
        headers['x-admin-skip-maintenance'] = 'true';
      }

      final response = await http
          .post(url, headers: headers, body: jsonEncode(body))
          .timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        // メンテナンスモードチェック（statusはメンテナンス判定のみで使用）
        if (data['status'] == 'maintenance') {
          // 終了予定時刻を解析
          DateTime? endTime;
          final endTimeStr = data['end_time'] as String?;
          if (endTimeStr != null) {
            try {
              endTime = DateTime.parse(endTimeStr);
            } catch (e) {
              debugPrint('[ApiClient] ⚠️ end_time解析エラー: $e');
            }
          }

          // メッセージを固定形式で生成
          final message = ErrorMessages.buildMaintenanceMessage(endTime);

          if (context != null && context.mounted) {
            await MaintenanceDialog.show(context: context, message: message);
            throw MaintenanceException(message: message, endTime: endTime);
          } else {
            throw MaintenanceException(message: message, endTime: endTime);
          }
        }

        return data;
      } else {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        final errorMessage = errorData['error'] ?? 'APIエラーが発生しました';

        // 404は情報ログ（ユーザー未登録等の正常なケース）
        if (response.statusCode == 404) {
          debugPrint('[ApiClient] ℹ️ リソース未検出: $errorMessage');
        } else {
          debugPrint(
            '[ApiClient] ❌ APIエラー: $errorMessage (status: ${response.statusCode})',
          );
        }

        throw ApiException(
          message: errorMessage,
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      debugPrint('[ApiClient] ❌ ネットワークエラー: $e');
      throw ApiException(message: 'ネットワークエラーが発生しました', statusCode: 0);
    }
  }
}

/// API例外クラス
class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException({required this.message, required this.statusCode});

  @override
  String toString() => 'ApiException: $message (status: $statusCode)';
}

/// メンテナンス例外クラス
class MaintenanceException implements Exception {
  final String message;
  final DateTime? endTime;

  MaintenanceException({required this.message, this.endTime});

  @override
  String toString() => 'MaintenanceException: $message';
}

/// システムエラー例外クラス
class SystemErrorException implements Exception {
  final String message;

  SystemErrorException({required this.message});

  @override
  String toString() => 'SystemErrorException: $message';
}
