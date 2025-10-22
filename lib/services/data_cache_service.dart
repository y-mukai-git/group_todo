import 'package:flutter/foundation.dart';
import '../data/models/todo_model.dart';
import '../data/models/group_model.dart';
import '../data/models/user_model.dart';
import 'todo_service.dart';
import 'group_service.dart';
import 'user_service.dart';

/// データキャッシュサービス（シングルトン + ChangeNotifier）
///
/// アプリ全体のデータをキャッシュとして保持し、各画面はこのキャッシュを参照する。
/// データ更新時は「DB更新 → 成功 → キャッシュ更新 → notifyListeners()」の順で実行し、
/// DB更新失敗時はキャッシュ更新しないことで、DB と キャッシュの整合性を保証する。
class DataCacheService extends ChangeNotifier {
  // シングルトンパターン
  static final DataCacheService _instance = DataCacheService._internal();
  factory DataCacheService() => _instance;
  DataCacheService._internal();

  final TodoService _todoService = TodoService();
  final GroupService _groupService = GroupService();
  final UserService _userService = UserService();

  // キャッシュデータ
  List<TodoModel> _todos = [];
  List<GroupModel> _groups = [];
  UserModel? _currentUser;
  String? _signedAvatarUrl;
  // グループID -> メンバー一覧 + オーナーID
  Map<String, Map<String, dynamic>> _groupMembers = {};

  // ゲッター
  List<TodoModel> get todos => _todos;
  List<GroupModel> get groups {
    // displayOrder順にソートして返す
    final sortedGroups = List<GroupModel>.from(_groups);
    sortedGroups.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return sortedGroups;
  }

  UserModel? get currentUser => _currentUser;
  String? get signedAvatarUrl => _signedAvatarUrl;

  /// 初期データ取得（スプラッシュ画面で実行）
  Future<void> initializeCache(
    UserModel user, {
    String? signedAvatarUrl,
  }) async {
    try {
      debugPrint('[DataCacheService] 📦 初期データ取得開始');

      _currentUser = user;
      _signedAvatarUrl = signedAvatarUrl;

      // TODOデータ取得
      final myTodos = await _todoService.getMyTodos(userId: user.id);

      // グループデータ取得
      final userGroups = await _groupService.getUserGroups(userId: user.id);

      // グループごとのTODOとメンバーを取得
      final List<TodoModel> allTodos = List.from(myTodos);
      for (final group in userGroups) {
        // TODO取得
        final groupTodos = await _todoService.getGroupTodos(
          userId: user.id,
          groupId: group.id,
        );
        allTodos.addAll(groupTodos);

        // メンバー取得（エラー時はrethrowしてinitializeCache全体を失敗させる）
        final membersResponse = await _groupService.getGroupMembers(
          groupId: group.id,
          requesterId: user.id,
        );
        _groupMembers[group.id] = membersResponse;
      }

      // 重複を除去（同じidのTODOは1つにする）
      final Map<String, TodoModel> uniqueTodos = {};
      for (final todo in allTodos) {
        uniqueTodos[todo.id] = todo;
      }

      _todos = uniqueTodos.values.toList();
      _groups = userGroups;

      debugPrint(
        '[DataCacheService] ✅ 初期データ取得完了: TODOs=${_todos.length}, Groups=${_groups.length}',
      );
      notifyListeners();
    } catch (e) {
      debugPrint('[DataCacheService] ❌ 初期データ取得エラー: $e');
      rethrow;
    }
  }

  /// キャッシュリフレッシュ（手動リロード用）
  Future<void> refreshCache() async {
    if (_currentUser == null) return;
    await initializeCache(_currentUser!);
  }

  // ==================== TODO関連 ====================

  /// TODO完了切り替え（DB + キャッシュ）
  Future<void> toggleTodoCompletion({
    required String userId,
    required String todoId,
  }) async {
    try {
      // 1. DB更新
      await _todoService.toggleTodoCompletion(userId: userId, todoId: todoId);

      // 2. DB更新成功 → キャッシュ更新
      final index = _todos.indexWhere((t) => t.id == todoId);
      if (index != -1) {
        _todos[index] = _todos[index].copyWith(
          isCompleted: !_todos[index].isCompleted,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[DataCacheService] ❌ TODO完了切り替えエラー: $e');
      // DB更新失敗 → キャッシュ更新しない
      rethrow;
    }
  }

  /// TODO作成（DB + キャッシュ）
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
      // 1. DB作成
      final newTodo = await _todoService.createTodo(
        userId: userId,
        groupId: groupId,
        title: title,
        description: description,
        dueDate: dueDate,
        assignedUserIds: assignedUserIds,
        category: category,
      );

      // 2. DB作成成功 → キャッシュに追加
      _todos.add(newTodo);
      notifyListeners();

      return newTodo;
    } catch (e) {
      debugPrint('[DataCacheService] ❌ TODO作成エラー: $e');
      rethrow;
    }
  }

  /// TODO更新（DB + キャッシュ）
  Future<TodoModel> updateTodo({
    required String userId,
    required String todoId,
    required String title,
    String? description,
    DateTime? dueDate,
    List<String>? assignedUserIds,
  }) async {
    try {
      // 1. DB更新
      final updatedTodo = await _todoService.updateTodo(
        userId: userId,
        todoId: todoId,
        title: title,
        description: description,
        dueDate: dueDate,
        assignedUserIds: assignedUserIds,
      );

      // 2. DB更新成功 → キャッシュ更新
      final index = _todos.indexWhere((t) => t.id == todoId);
      if (index != -1) {
        _todos[index] = updatedTodo;
        notifyListeners();
      }

      return updatedTodo;
    } catch (e) {
      debugPrint('[DataCacheService] ❌ TODO更新エラー: $e');
      rethrow;
    }
  }

  /// TODO更新（DB + キャッシュ）※旧updateTodoOptimistic
  Future<TodoModel> updateTodoOptimistic({
    required String userId,
    required String todoId,
    required String title,
    String? description,
    DateTime? dueDate,
    List<String>? assignedUserIds,
    required Function(String) onNetworkError,
    required Function(String) onOtherError,
  }) async {
    try {
      // 1. DB更新
      final updatedTodo = await _todoService.updateTodo(
        userId: userId,
        todoId: todoId,
        title: title,
        description: description,
        dueDate: dueDate,
        assignedUserIds: assignedUserIds,
      );

      // 2. DB更新成功 → キャッシュ更新
      final index = _todos.indexWhere((t) => t.id == todoId);
      if (index != -1) {
        _todos[index] = updatedTodo;
        notifyListeners();
      }

      return updatedTodo;
    } catch (e) {
      debugPrint('[DataCacheService] ❌ TODO更新エラー: $e');
      // DB更新失敗 → キャッシュ更新しない
      rethrow;
    }
  }

  /// TODO削除（DB + キャッシュ）
  Future<void> deleteTodo({
    required String userId,
    required String todoId,
  }) async {
    try {
      // 1. DB削除
      await _todoService.deleteTodo(userId: userId, todoId: todoId);

      // 2. DB削除成功 → キャッシュから削除
      _todos.removeWhere((t) => t.id == todoId);
      notifyListeners();
    } catch (e) {
      debugPrint('[DataCacheService] ❌ TODO削除エラー: $e');
      rethrow;
    }
  }

  // ==================== グループ関連 ====================

  /// グループ作成（DB + キャッシュ）
  Future<GroupModel> createGroup({
    required String userId,
    required String groupName,
    String? description,
    String? category,
    String? imageData,
  }) async {
    try {
      // 1. DB作成
      final newGroup = await _groupService.createGroup(
        userId: userId,
        groupName: groupName,
        description: description,
        category: category,
        imageData: imageData,
      );

      // 2. DB作成成功 → キャッシュに追加
      _groups.add(newGroup);

      // 3. メンバー情報を取得してキャッシュに追加
      final membersResponse = await _groupService.getGroupMembers(
        groupId: newGroup.id,
        requesterId: userId,
      );
      _groupMembers[newGroup.id] = membersResponse;

      notifyListeners();

      return newGroup;
    } catch (e) {
      debugPrint('[DataCacheService] ❌ グループ作成エラー: $e');
      rethrow;
    }
  }

  /// グループ更新（DB + キャッシュ）
  Future<GroupModel> updateGroup({
    required String userId,
    required String groupId,
    required String groupName,
    String? description,
    String? category,
    String? imageData,
  }) async {
    try {
      // 1. DB更新
      final updatedGroup = await _groupService.updateGroup(
        userId: userId,
        groupId: groupId,
        groupName: groupName,
        description: description,
        category: category,
        imageData: imageData,
      );

      // 2. DB更新成功 → キャッシュ更新
      final index = _groups.indexWhere((g) => g.id == groupId);
      if (index != -1) {
        _groups[index] = updatedGroup;
        notifyListeners();
      }

      return updatedGroup;
    } catch (e) {
      debugPrint('[DataCacheService] ❌ グループ更新エラー: $e');
      rethrow;
    }
  }

  /// グループ削除（DB + キャッシュ）
  Future<void> deleteGroup({
    required String groupId,
    required String userId,
  }) async {
    try {
      // 1. DB削除
      await _groupService.deleteGroup(groupId: groupId, userId: userId);

      // 2. DB削除成功 → キャッシュから削除
      _groups.removeWhere((g) => g.id == groupId);

      // 3. 関連TODOを削除
      _todos.removeWhere((t) => t.groupId == groupId);

      // 4. グループメンバー情報を削除
      _groupMembers.remove(groupId);

      notifyListeners();
    } catch (e) {
      debugPrint('[DataCacheService] ❌ グループ削除エラー: $e');
      rethrow;
    }
  }

  /// グループメンバーキャッシュを更新
  Future<void> refreshGroupMembers({
    required String groupId,
    required String requesterId,
  }) async {
    try {
      final membersResponse = await _groupService.getGroupMembers(
        groupId: groupId,
        requesterId: requesterId,
      );
      _groupMembers[groupId] = membersResponse;
      notifyListeners();
    } catch (e) {
      debugPrint('[DataCacheService] ❌ グループメンバーキャッシュ更新エラー: $e');
      rethrow;
    }
  }

  /// グループ並び順更新（DB + キャッシュ）
  Future<void> updateGroupOrder({
    required String userId,
    required List<GroupModel> orderedGroups,
  }) async {
    try {
      // 1. DB更新用データ準備
      final groupOrders = orderedGroups
          .asMap()
          .entries
          .map(
            (entry) => {
              'group_id': entry.value.id,
              'display_order': entry.key + 1, // 1から開始
            },
          )
          .toList();

      // 2. DB更新
      await _groupService.updateGroupOrder(
        userId: userId,
        groupOrders: groupOrders,
      );

      // 3. DB更新成功 → キャッシュ更新
      for (var i = 0; i < orderedGroups.length; i++) {
        final index = _groups.indexWhere((g) => g.id == orderedGroups[i].id);
        if (index != -1) {
          _groups[index] = _groups[index].copyWith(displayOrder: i + 1);
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('[DataCacheService] ❌ グループ並び順更新エラー: $e');
      rethrow;
    }
  }

  // ==================== ユーザー関連 ====================

  /// ユーザー情報更新（DB + キャッシュ）
  Future<Map<String, dynamic>> updateUser({
    required String userId,
    String? displayName,
    String? imageData,
  }) async {
    try {
      // 1. DB更新
      final response = await _userService.updateUserProfile(
        userId: userId,
        displayName: displayName,
        imageData: imageData,
      );

      final updatedUser = response['user'] as UserModel;
      final signedAvatarUrl = response['signed_avatar_url'] as String?;

      // 2. DB更新成功 → キャッシュ更新
      _currentUser = updatedUser;
      _signedAvatarUrl = signedAvatarUrl;
      notifyListeners();

      return {'user': updatedUser, 'signed_avatar_url': signedAvatarUrl};
    } catch (e) {
      debugPrint('[DataCacheService] ❌ ユーザー情報更新エラー: $e');
      rethrow;
    }
  }

  // ==================== ヘルパーメソッド ====================

  /// グループIDからグループを取得
  GroupModel? getGroupById(String groupId) {
    try {
      return _groups.firstWhere((g) => g.id == groupId);
    } catch (e) {
      return null;
    }
  }

  /// グループメンバー情報を取得
  Map<String, dynamic>? getGroupMembers(String groupId) {
    return _groupMembers[groupId];
  }

  /// グループに紐づくTODO一覧を取得
  List<TodoModel> getTodosByGroupId(String groupId) {
    return _todos.where((t) => t.groupId == groupId).toList();
  }

  /// 自分のTODO一覧を取得（My TODO）
  /// 自分が担当している未完了TODOを返す
  List<TodoModel> getMyTodos(String userId, {String? filterDays}) {
    return _todos
        .where(
          (t) =>
              t.assignedUserIds != null &&
              t.assignedUserIds!.contains(userId) &&
              !t.isCompleted,
        )
        .toList();
  }
}
