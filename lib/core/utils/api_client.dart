import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../config/environment_config.dart';
import '../../services/error_log_service.dart';
import '../../presentation/widgets/maintenance_dialog.dart';

/// API呼び出し共通クラス
/// Supabase Edge Functionsへのリクエストを統一管理
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  final _config = EnvironmentConfig.instance;

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

      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${_config.supabaseAnonKey}',
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        // メンテナンスモード・エラーチェック
        if (data['status'] == 'maintenance') {
          final message = data['message'] as String? ?? 'システムメンテナンス中です';

          if (context != null && context.mounted) {
            await MaintenanceDialog.show(context: context, message: message);
            throw MaintenanceException(message: message);
          } else {
            throw MaintenanceException(message: message);
          }
        }

        if (data['status'] == 'error') {
          final message = data['message'] as String? ?? 'システムエラーが発生しました';

          if (context != null && context.mounted) {
            await MaintenanceDialog.show(context: context, message: message);
            throw SystemErrorException(message: message);
          } else {
            throw SystemErrorException(message: message);
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

  MaintenanceException({required this.message});

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
