import 'package:flutter/foundation.dart';
import '../core/utils/api_client.dart';
import '../data/models/todo_model.dart';

/// タスク管理サービス
class TodoService {
  final ApiClient _apiClient = ApiClient();

  /// タスク作成
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

      if (response['success'] != true) {
        final errorMessage = response['error'] as String? ?? 'タスクの作成に失敗しました';
        throw ApiException(message: errorMessage, statusCode: 200);
      }

      return TodoModel.fromJson(response['todo'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[TodoService] ❌ タスク作成エラー: $e');
      rethrow;
    }
  }

  /// 自分のタスク一覧取得
  Future<List<TodoModel>> getMyTodos({
    required String userId,
    String? filterDays,
  }) async {
    try {
      final response = await _apiClient.callFunction(
        functionName: 'get-my-todos',
        body: {'user_id': userId, 'filter_days': filterDays},
      );

      if (response['success'] != true) {
        final errorMessage =
            response['error'] as String? ?? '自分のタスク一覧の取得に失敗しました';
        throw ApiException(message: errorMessage, statusCode: 200);
      }

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

  /// グループのタスク一覧取得
  Future<List<TodoModel>> getGroupTodos({
    required String userId,
    required String groupId,
  }) async {
    try {
      final response = await _apiClient.callFunction(
        functionName: 'get-group-todos',
        body: {'user_id': userId, 'group_id': groupId},
      );

      if (response['success'] != true) {
        final errorMessage =
            response['error'] as String? ?? 'グループタスク一覧の取得に失敗しました';
        throw ApiException(message: errorMessage, statusCode: 200);
      }

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

  /// タスク詳細取得
  Future<TodoModel> getTodoDetail({
    required String userId,
    required String todoId,
  }) async {
    try {
      final response = await _apiClient.callFunction(
        functionName: 'get-todo-detail',
        body: {'user_id': userId, 'todo_id': todoId},
      );

      if (response['success'] != true) {
        final errorMessage = response['error'] as String? ?? 'タスク詳細の取得に失敗しました';
        throw ApiException(message: errorMessage, statusCode: 200);
      }

      return TodoModel.fromJson(response['todo'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[TodoService] ❌ タスク詳細取得エラー: $e');
      rethrow;
    }
  }

  /// タスク更新
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

      if (response['success'] != true) {
        final errorMessage = response['error'] as String? ?? 'タスクの更新に失敗しました';
        throw ApiException(message: errorMessage, statusCode: 200);
      }

      return TodoModel.fromJson(response['todo'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[TodoService] ❌ タスク更新エラー: $e');
      rethrow;
    }
  }

  /// タスク完了状態切り替え
  Future<TodoModel> toggleTodoCompletion({
    required String userId,
    required String todoId,
  }) async {
    try {
      final response = await _apiClient.callFunction(
        functionName: 'toggle-todo-completion',
        body: {'user_id': userId, 'todo_id': todoId},
      );

      if (response['success'] != true) {
        final errorMessage =
            response['error'] as String? ?? 'タスク完了状態の切り替えに失敗しました';
        throw ApiException(message: errorMessage, statusCode: 200);
      }

      return TodoModel.fromJson(response['todo'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[TodoService] ❌ タスク完了状態切り替えエラー: $e');
      rethrow;
    }
  }

  /// タスク削除
  Future<void> deleteTodo({
    required String userId,
    required String todoId,
  }) async {
    try {
      final response = await _apiClient.callFunction(
        functionName: 'delete-todo',
        body: {'user_id': userId, 'todo_id': todoId},
      );

      if (response['success'] != true) {
        final errorMessage = response['error'] as String? ?? 'タスクの削除に失敗しました';
        throw ApiException(message: errorMessage, statusCode: 200);
      }
    } catch (e) {
      debugPrint('[TodoService] ❌ タスク削除エラー: $e');
      rethrow;
    }
  }

  /// タスクコメント作成
  Future<void> createTodoComment({
    required String userId,
    required String todoId,
    required String commentText,
  }) async {
    try {
      final response = await _apiClient.callFunction(
        functionName: 'create-todo-comment',
        body: {
          'user_id': userId,
          'todo_id': todoId,
          'comment_text': commentText,
        },
      );

      if (response['success'] != true) {
        final errorMessage = response['error'] as String? ?? 'コメントの作成に失敗しました';
        throw ApiException(message: errorMessage, statusCode: 200);
      }
    } catch (e) {
      debugPrint('[TodoService] ❌ コメント作成エラー: $e');
      rethrow;
    }
  }

  /// タスクコメント一覧取得
  Future<List<dynamic>> getTodoComments({
    required String userId,
    required String todoId,
  }) async {
    try {
      final response = await _apiClient.callFunction(
        functionName: 'get-todo-comments',
        body: {'user_id': userId, 'todo_id': todoId},
      );

      if (response['success'] != true) {
        final errorMessage = response['error'] as String? ?? 'コメント一覧の取得に失敗しました';
        throw ApiException(message: errorMessage, statusCode: 200);
      }

      final comments = response['comments'] as List<dynamic>;
      return comments;
    } catch (e) {
      debugPrint('[TodoService] ❌ コメント取得エラー: $e');
      rethrow;
    }
  }
}
