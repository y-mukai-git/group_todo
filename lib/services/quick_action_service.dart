import 'package:flutter/foundation.dart';
import '../core/utils/api_client.dart';
import '../data/models/quick_action_model.dart';
import '../data/models/todo_model.dart';

/// クイックアクション管理サービス
class QuickActionService {
  final ApiClient _apiClient = ApiClient();

  /// クイックアクション作成
  Future<QuickActionModel> createQuickAction({
    required String userId,
    required String groupId,
    required String name,
    String? description,
    required List<QuickActionTemplateModel> templates,
  }) async {
    try {
      final response = await _apiClient.callFunction(
        functionName: 'create-quick-action',
        body: {
          'group_id': groupId,
          'name': name,
          'description': description,
          'created_by': userId,
          'templates': templates
              .map(
                (t) => {
                  'title': t.title,
                  'description': t.description,
                  'deadline_days_after': t.deadlineDaysAfter,
                  'assigned_user_ids': t.assignedUserIds ?? [],
                  'display_order': t.displayOrder,
                },
              )
              .toList(),
        },
      );

      if (response['success'] != true) {
        final errorMessage =
            response['error'] as String? ?? 'セットTODOの作成に失敗しました';
        throw ApiException(message: errorMessage, statusCode: 200);
      }

      return QuickActionModel.fromJson(
        response['quick_action'] as Map<String, dynamic>,
      );
    } catch (e) {
      debugPrint('[QuickActionService] ❌ クイックアクション作成エラー: $e');
      rethrow;
    }
  }

  /// クイックアクション一覧取得
  Future<List<QuickActionModel>> getQuickActions({
    required String userId,
    required String groupId,
  }) async {
    try {
      final response = await _apiClient.callFunction(
        functionName: 'get-quick-actions',
        body: {'group_id': groupId, 'user_id': userId},
      );

      if (response['success'] != true) {
        final errorMessage =
            response['error'] as String? ?? 'セットTODO一覧の取得に失敗しました';
        throw ApiException(message: errorMessage, statusCode: 200);
      }

      final quickActions = (response['quick_actions'] as List<dynamic>)
          .map(
            (item) => QuickActionModel.fromJson(item as Map<String, dynamic>),
          )
          .toList();

      debugPrint(
        '[QuickActionService] ✅ クイックアクション一覧取得成功: ${quickActions.length}件',
      );
      return quickActions;
    } catch (e) {
      debugPrint('[QuickActionService] ❌ クイックアクション一覧取得エラー: $e');
      rethrow;
    }
  }

  /// クイックアクション更新
  Future<QuickActionModel> updateQuickAction({
    required String userId,
    required String quickActionId,
    String? name,
    String? description,
    List<QuickActionTemplateModel>? templates,
  }) async {
    try {
      final Map<String, dynamic> body = {
        'quick_action_id': quickActionId,
        'user_id': userId,
      };

      if (name != null) body['name'] = name;
      if (description != null) body['description'] = description;
      if (templates != null) {
        body['templates'] = templates
            .map(
              (t) => {
                'title': t.title,
                'description': t.description,
                'deadline_days_after': t.deadlineDaysAfter,
                'assigned_user_ids': t.assignedUserIds ?? [],
                'display_order': t.displayOrder,
              },
            )
            .toList();
      }

      final response = await _apiClient.callFunction(
        functionName: 'update-quick-action',
        body: body,
      );

      if (response['success'] != true) {
        final errorMessage =
            response['error'] as String? ?? 'セットTODOの更新に失敗しました';
        throw ApiException(message: errorMessage, statusCode: 200);
      }

      return QuickActionModel.fromJson(
        response['quick_action'] as Map<String, dynamic>,
      );
    } catch (e) {
      debugPrint('[QuickActionService] ❌ クイックアクション更新エラー: $e');
      rethrow;
    }
  }

  /// クイックアクション削除
  Future<void> deleteQuickAction({
    required String userId,
    required String quickActionId,
  }) async {
    try {
      final response = await _apiClient.callFunction(
        functionName: 'delete-quick-action',
        body: {'quick_action_id': quickActionId, 'user_id': userId},
      );

      if (response['success'] != true) {
        final errorMessage =
            response['error'] as String? ?? 'セットTODOの削除に失敗しました';
        throw ApiException(message: errorMessage, statusCode: 200);
      }
    } catch (e) {
      debugPrint('[QuickActionService] ❌ クイックアクション削除エラー: $e');
      rethrow;
    }
  }

  /// クイックアクション実行（複数TODO一括生成）
  ///
  /// 戻り値: 作成されたTODOのリスト
  Future<List<TodoModel>> executeQuickAction({
    required String userId,
    required String quickActionId,
  }) async {
    try {
      final response = await _apiClient.callFunction(
        functionName: 'execute-quick-action',
        body: {'quick_action_id': quickActionId, 'executed_by': userId},
      );

      if (response['success'] != true) {
        final errorMessage =
            response['error'] as String? ?? 'セットTODOの実行に失敗しました';
        throw ApiException(message: errorMessage, statusCode: 200);
      }

      final createdTodosJson = response['todos'] as List<dynamic>? ?? [];
      final createdTodos = createdTodosJson
          .map((item) => TodoModel.fromJson(item as Map<String, dynamic>))
          .toList();

      debugPrint(
        '[QuickActionService] ✅ クイックアクション実行成功: ${createdTodos.length}件のTODO作成',
      );

      return createdTodos;
    } catch (e) {
      debugPrint('[QuickActionService] ❌ クイックアクション実行エラー: $e');
      rethrow;
    }
  }
}
