import 'package:flutter/foundation.dart';
import '../core/utils/api_client.dart';
import '../data/models/recurring_todo_model.dart';

/// 定期TODO管理サービス
class RecurringTodoService {
  final ApiClient _apiClient = ApiClient();

  /// 定期TODO作成
  Future<RecurringTodoModel> createRecurringTodo({
    required String userId,
    required String groupId,
    required String title,
    String? description,
    required String category,
    required String recurrencePattern,
    List<int>? recurrenceDays,
    required String generationTime,
    List<String>? assignedUserIds,
  }) async {
    try {
      final response = await _apiClient.callFunction(
        functionName: 'create-recurring-todo',
        body: {
          'group_id': groupId,
          'title': title,
          'description': description,
          'category': category,
          'recurrence_pattern': recurrencePattern,
          'recurrence_days': recurrenceDays,
          'generation_time': generationTime,
          'assigned_user_ids': assignedUserIds ?? [],
          'created_by': userId,
        },
      );

      return RecurringTodoModel.fromJson(
        response['recurring_todo'] as Map<String, dynamic>,
      );
    } catch (e) {
      debugPrint('[RecurringTodoService] ❌ 定期TODO作成エラー: $e');
      rethrow;
    }
  }

  /// 定期TODO一覧取得
  Future<List<RecurringTodoModel>> getRecurringTodos({
    required String userId,
    required String groupId,
  }) async {
    try {
      final response = await _apiClient.callFunction(
        functionName: 'get-recurring-todos',
        body: {'group_id': groupId},
      );

      final recurringTodos = (response['recurring_todos'] as List<dynamic>)
          .map(
            (item) => RecurringTodoModel.fromJson(item as Map<String, dynamic>),
          )
          .toList();

      debugPrint(
        '[RecurringTodoService] ✅ 定期TODO一覧取得成功: ${recurringTodos.length}件',
      );
      return recurringTodos;
    } catch (e) {
      debugPrint('[RecurringTodoService] ❌ 定期TODO一覧取得エラー: $e');
      rethrow;
    }
  }

  /// 定期TODO更新
  Future<RecurringTodoModel> updateRecurringTodo({
    required String userId,
    required String recurringTodoId,
    String? title,
    String? description,
    String? category,
    String? recurrencePattern,
    List<int>? recurrenceDays,
    String? generationTime,
    List<String>? assignedUserIds,
  }) async {
    try {
      final Map<String, dynamic> body = {
        'recurring_todo_id': recurringTodoId,
        'user_id': userId,
      };

      if (title != null) body['title'] = title;
      if (description != null) body['description'] = description;
      if (category != null) body['category'] = category;
      if (recurrencePattern != null) {
        body['recurrence_pattern'] = recurrencePattern;
      }
      if (recurrenceDays != null) body['recurrence_days'] = recurrenceDays;
      if (generationTime != null) body['generation_time'] = generationTime;
      if (assignedUserIds != null) body['assigned_user_ids'] = assignedUserIds;

      final response = await _apiClient.callFunction(
        functionName: 'update-recurring-todo',
        body: body,
      );

      return RecurringTodoModel.fromJson(
        response['recurring_todo'] as Map<String, dynamic>,
      );
    } catch (e) {
      debugPrint('[RecurringTodoService] ❌ 定期TODO更新エラー: $e');
      rethrow;
    }
  }

  /// 定期TODO削除
  Future<void> deleteRecurringTodo({
    required String userId,
    required String recurringTodoId,
  }) async {
    try {
      await _apiClient.callFunction(
        functionName: 'delete-recurring-todo',
        body: {'recurring_todo_id': recurringTodoId, 'user_id': userId},
      );
    } catch (e) {
      debugPrint('[RecurringTodoService] ❌ 定期TODO削除エラー: $e');
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

      return RecurringTodoModel.fromJson(
        response['recurring_todo'] as Map<String, dynamic>,
      );
    } catch (e) {
      debugPrint('[RecurringTodoService] ❌ 定期TODO切り替えエラー: $e');
      rethrow;
    }
  }
}
