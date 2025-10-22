import 'package:flutter/foundation.dart';
import '../core/utils/api_client.dart';
import '../data/models/todo_model.dart';

/// TODO管理サービス
class TodoService {
  final ApiClient _apiClient = ApiClient();

  /// TODO作成
  Future<TodoModel> createTodo({
    required String userId,
    required String groupId,
    required String title,
    String? description,
    DateTime? dueDate,
    List<String>? assignedUserIds,
    String? category,
  }) async {
    try {
      final response = await _apiClient.callFunction(
        functionName: 'create-todo',
        body: {
          'group_id': groupId,
          'title': title,
          'description': description,
          'deadline': dueDate?.toIso8601String(),
          'category': category ?? 'other',
          'assigned_user_ids': assignedUserIds ?? [userId],
          'created_by': userId,
        },
      );

      return TodoModel.fromJson(response['todo'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[TodoService] ❌ TODO作成エラー: $e');
      rethrow;
    }
  }

  /// 自分のTODO一覧取得
  Future<List<TodoModel>> getMyTodos({
    required String userId,
    String? filterDays,
  }) async {
    try {
      final response = await _apiClient.callFunction(
        functionName: 'get-my-todos',
        body: {'user_id': userId, 'filter_days': filterDays},
      );

      final todosList = response['todos'] as List<dynamic>;
      final todos = todosList
          .map((json) => TodoModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return todos;
    } catch (e) {
      debugPrint('[TodoService] ❌ 自分のTODO取得エラー: $e');
      rethrow;
    }
  }

  /// グループのTODO一覧取得
  Future<List<TodoModel>> getGroupTodos({
    required String userId,
    required String groupId,
  }) async {
    try {
      final response = await _apiClient.callFunction(
        functionName: 'get-group-todos',
        body: {'user_id': userId, 'group_id': groupId},
      );

      final todosList = response['todos'] as List<dynamic>;
      final todos = todosList
          .map((json) => TodoModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return todos;
    } catch (e) {
      debugPrint('[TodoService] ❌ グループTODO取得エラー: $e');
      rethrow;
    }
  }

  /// TODO詳細取得
  Future<TodoModel> getTodoDetail({
    required String userId,
    required String todoId,
  }) async {
    try {
      final response = await _apiClient.callFunction(
        functionName: 'get-todo-detail',
        body: {'user_id': userId, 'todo_id': todoId},
      );

      return TodoModel.fromJson(response['todo'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[TodoService] ❌ TODO詳細取得エラー: $e');
      rethrow;
    }
  }

  /// TODO更新
  Future<TodoModel> updateTodo({
    required String userId,
    required String todoId,
    String? title,
    String? description,
    DateTime? dueDate,
    List<String>? assignedUserIds,
  }) async {
    try {
      final response = await _apiClient.callFunction(
        functionName: 'update-todo',
        body: {
          'user_id': userId,
          'todo_id': todoId,
          'title': title,
          'description': description,
          'deadline': dueDate?.toIso8601String(),
          'assigned_user_ids': assignedUserIds,
        },
      );

      return TodoModel.fromJson(response['todo'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[TodoService] ❌ TODO更新エラー: $e');
      rethrow;
    }
  }

  /// TODO完了状態切り替え
  Future<TodoModel> toggleTodoCompletion({
    required String userId,
    required String todoId,
  }) async {
    try {
      final response = await _apiClient.callFunction(
        functionName: 'toggle-todo-completion',
        body: {'user_id': userId, 'todo_id': todoId},
      );

      return TodoModel.fromJson(response['todo'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[TodoService] ❌ TODO完了状態切り替えエラー: $e');
      rethrow;
    }
  }

  /// TODO削除
  Future<void> deleteTodo({
    required String userId,
    required String todoId,
  }) async {
    try {
      await _apiClient.callFunction(
        functionName: 'delete-todo',
        body: {'user_id': userId, 'todo_id': todoId},
      );
    } catch (e) {
      debugPrint('[TodoService] ❌ TODO削除エラー: $e');
      rethrow;
    }
  }

  /// TODOコメント作成
  Future<void> createTodoComment({
    required String userId,
    required String todoId,
    required String commentText,
  }) async {
    try {
      await _apiClient.callFunction(
        functionName: 'create-todo-comment',
        body: {
          'user_id': userId,
          'todo_id': todoId,
          'comment_text': commentText,
        },
      );
    } catch (e) {
      debugPrint('[TodoService] ❌ コメント作成エラー: $e');
      rethrow;
    }
  }

  /// TODOコメント一覧取得
  Future<List<dynamic>> getTodoComments({
    required String userId,
    required String todoId,
  }) async {
    try {
      final response = await _apiClient.callFunction(
        functionName: 'get-todo-comments',
        body: {'user_id': userId, 'todo_id': todoId},
      );

      final comments = response['comments'] as List<dynamic>;
      return comments;
    } catch (e) {
      debugPrint('[TodoService] ❌ コメント取得エラー: $e');
      rethrow;
    }
  }
}
