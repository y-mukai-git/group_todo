import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../config/environment_config.dart';

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
  }) async {
    try {
      final url = Uri.parse(
        '${_config.supabaseUrl}/functions/v1/$functionName',
      );

      debugPrint('[ApiClient] 🌐 API呼び出し: $functionName');
      debugPrint('[ApiClient] 📤 リクエストボディ: ${jsonEncode(body)}');

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

      debugPrint('[ApiClient] 📥 レスポンスステータス: ${response.statusCode}');
      debugPrint('[ApiClient] 📥 レスポンスボディ: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
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

  /// GET リクエスト（直接データベースアクセス用）
  Future<Map<String, dynamic>> get({
    required String endpoint,
    Map<String, String>? queryParameters,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      final uri = Uri.parse(
        '${_config.supabaseUrl}/rest/v1/$endpoint',
      ).replace(queryParameters: queryParameters);

      debugPrint('[ApiClient] 🌐 GET: $endpoint');

      final response = await http
          .get(
            uri,
            headers: {
              'apikey': _config.supabaseAnonKey,
              'Authorization': 'Bearer ${_config.supabaseAnonKey}',
              'Content-Type': 'application/json',
            },
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw ApiException(
          message: 'データ取得に失敗しました',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('[ApiClient] ❌ GETエラー: $e');
      if (e is ApiException) {
        rethrow;
      }
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
