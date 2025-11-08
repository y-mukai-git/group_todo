import 'package:flutter/foundation.dart';
import '../core/utils/api_client.dart';
import '../data/models/recurring_todo_model.dart';

/// 定期タスク管理サービス
class RecurringTodoService {
  final ApiClient _apiClient = ApiClient();

  /// 定期タスク作成
  Future<RecurringTodoModel> createRecurringTodo({
    required String userId,
    required String groupId,
    required String title,
    String? description,
    required String recurrencePattern,
    List<int>? recurrenceDays,
    required String generationTime,
    int? deadlineDaysAfter,
    List<String>? assignedUserIds,
  }) async {
    try {
      final response = await _apiClient.callFunction(
        functionName: 'create-recurring-todo',
        body: {
          'group_id': groupId,
          'title': title,
          'description': description,
          'recurrence_pattern': recurrencePattern,
          'recurrence_days': recurrenceDays,
          'generation_time': generationTime,
          'deadline_days_after': deadlineDaysAfter,
          'assigned_user_ids': assignedUserIds ?? [],
          'created_by': userId,
        },
      );

      if (response['success'] != true) {
        final errorMessage = response['error'] as String? ?? '定期タスクの作成に失敗しました';
        throw ApiException(message: errorMessage, statusCode: 200);
      }

      return RecurringTodoModel.fromJson(
        response['recurring_todo'] as Map<String, dynamic>,
      );
    } catch (e) {
      debugPrint('[RecurringTodoService] ❌ 定期タスク作成エラー: $e');
      rethrow;
    }
  }

  /// 定期タスク一覧取得
  Future<List<RecurringTodoModel>> getRecurringTodos({
    required String userId,
    required String groupId,
  }) async {
    try {
      final response = await _apiClient.callFunction(
        functionName: 'get-recurring-todos',
        body: {'group_id': groupId},
      );

      if (response['success'] != true) {
        final errorMessage =
            response['error'] as String? ?? '定期タスク一覧の取得に失敗しました';
        throw ApiException(message: errorMessage, statusCode: 200);
      }

      final recurringTodos = (response['recurring_todos'] as List<dynamic>)
          .map(
            (item) => RecurringTodoModel.fromJson(item as Map<String, dynamic>),
          )
          .toList();

      debugPrint(
        '[RecurringTodoService] ✅ 定期タスク一覧取得成功: ${recurringTodos.length}件',
      );
      return recurringTodos;
    } catch (e) {
      debugPrint('[RecurringTodoService] ❌ 定期タスク一覧取得エラー: $e');
      rethrow;
    }
  }

  /// 定期タスク更新
  Future<RecurringTodoModel> updateRecurringTodo({
    required String userId,
    required String recurringTodoId,
    String? title,
    String? description,
    String? recurrencePattern,
    List<int>? recurrenceDays,
    String? generationTime,
    int? deadlineDaysAfter,
    List<String>? assignedUserIds,
  }) async {
    try {
      final Map<String, dynamic> body = {
        'recurring_todo_id': recurringTodoId,
        'user_id': userId,
      };

      if (title != null) body['title'] = title;
      if (description != null) body['description'] = description;
      if (recurrencePattern != null) {
        body['recurrence_pattern'] = recurrencePattern;
      }
      if (recurrenceDays != null) body['recurrence_days'] = recurrenceDays;
      if (generationTime != null) body['generation_time'] = generationTime;
      if (deadlineDaysAfter != null) {
        body['deadline_days_after'] = deadlineDaysAfter;
      }
      if (assignedUserIds != null) body['assigned_user_ids'] = assignedUserIds;

      final response = await _apiClient.callFunction(
        functionName: 'update-recurring-todo',
        body: body,
      );

      if (response['success'] != true) {
        final errorMessage = response['error'] as String? ?? '定期タスクの更新に失敗しました';
        throw ApiException(message: errorMessage, statusCode: 200);
      }

      return RecurringTodoModel.fromJson(
        response['recurring_todo'] as Map<String, dynamic>,
      );
    } catch (e) {
      debugPrint('[RecurringTodoService] ❌ 定期タスク更新エラー: $e');
      rethrow;
    }
  }

  /// 定期タスク削除
  Future<void> deleteRecurringTodo({
    required String userId,
    required String recurringTodoId,
  }) async {
    try {
      final response = await _apiClient.callFunction(
        functionName: 'delete-recurring-todo',
        body: {'recurring_todo_id': recurringTodoId, 'user_id': userId},
      );

      if (response['success'] != true) {
        final errorMessage = response['error'] as String? ?? '定期タスクの削除に失敗しました';
        throw ApiException(message: errorMessage, statusCode: 200);
      }
    } catch (e) {
      debugPrint('[RecurringTodoService] ❌ 定期タスク削除エラー: $e');
      rethrow;
    }
  }

  /// 定期TODO有効/無効切り替え
  Future<RecurringTodoModel> toggleRecurringTodoActive({
    required String userId,
    required String recurringTodoId,
  }) async {
    try {
      final response = await _apiClient.callFunction(
        functionName: 'toggle-recurring-todo',
        body: {'recurring_todo_id': recurringTodoId, 'user_id': userId},
      );

      if (response['success'] != true) {
        final errorMessage =
            response['error'] as String? ?? '定期タスク有効/無効切り替えに失敗しました';
        throw ApiException(message: errorMessage, statusCode: 200);
      }

      return RecurringTodoModel.fromJson(
        response['recurring_todo'] as Map<String, dynamic>,
      );
    } catch (e) {
      debugPrint('[RecurringTodoService] ❌ 定期TODO切り替えエラー: $e');
      rethrow;
    }
  }
}
