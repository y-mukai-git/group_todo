import 'package:flutter/foundation.dart';
import '../core/utils/api_client.dart';
import '../data/models/todo_model.dart';
import '../data/models/group_model.dart';

/// TODO作成結果（グループも新規作成した場合を含む）
class CreateTodoResult {
  final TodoModel todo;
  final GroupModel? createdGroup; // 新規作成されたグループ（ある場合のみ）

  CreateTodoResult({required this.todo, this.createdGroup});
}

/// 新規グループ作成情報
class NewGroupInfo {
  final String name;
  final String? description;
  final String? category;
  final String? imageData; // base64エンコードされた画像データ

  NewGroupInfo({
    required this.name,
    this.description,
    this.category,
    this.imageData,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'category': category,
      'image_data': imageData,
    };
  }
}

/// タスク管理サービス
class TodoService {
  final ApiClient _apiClient = ApiClient();

  /// タスク作成（オプションで新規グループ作成も同時に行う）
  ///
  /// [groupId]: 既存グループに紐付ける場合に指定
  /// [newGroup]: 新規グループを作成して紐付ける場合に指定
  /// どちらか一方を指定する必要があります
  Future<CreateTodoResult> createTodo({
    required String userId,
    String? groupId,
    NewGroupInfo? newGroup,
    required String title,
    String? description,
    DateTime? dueDate,
    List<String>? assignedUserIds,
  }) async {
    // バリデーション: groupId か newGroup のどちらか必須
    assert(
      groupId != null || newGroup != null,
      'groupId or newGroup is required',
    );

    try {
      final body = <String, dynamic>{
        'title': title,
        'description': description,
        'deadline': dueDate?.toIso8601String(),
        'assigned_user_ids': assignedUserIds ?? [userId],
        'created_by': userId,
      };

      if (groupId != null) {
        body['group_id'] = groupId;
      }
      if (newGroup != null) {
        body['new_group'] = newGroup.toJson();
      }

      final response = await _apiClient.callFunction(
        functionName: 'create-todo',
        body: body,
      );

      if (response['success'] != true) {
        final errorMessage = response['error'] as String? ?? 'TODOの作成に失敗しました';
        throw ApiException(message: errorMessage, statusCode: 200);
      }

      final todo = TodoModel.fromJson(response['todo'] as Map<String, dynamic>);

      // 新規グループが作成された場合
      GroupModel? createdGroup;
      if (response['created_group'] != null) {
        createdGroup = GroupModel.fromJson(
          response['created_group'] as Map<String, dynamic>,
        );
      }

      return CreateTodoResult(todo: todo, createdGroup: createdGroup);
    } catch (e) {
      debugPrint('[TodoService] ❌ TODO作成エラー: $e');
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
