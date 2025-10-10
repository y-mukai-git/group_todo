import 'package:flutter/foundation.dart';
import '../data/models/todo_model.dart';
import '../data/models/group_model.dart';
import '../data/models/user_model.dart';
import 'todo_service.dart';
import 'group_service.dart';

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

  // キャッシュデータ
  List<TodoModel> _todos = [];
  List<GroupModel> _groups = [];
  UserModel? _currentUser;

  // ゲッター
  List<TodoModel> get todos => _todos;
  List<GroupModel> get groups => _groups;
  UserModel? get currentUser => _currentUser;

  /// 初期データ取得（スプラッシュ画面で実行）
  Future<void> initializeCache(UserModel user) async {
    try {
      debugPrint('[DataCacheService] 📦 初期データ取得開始');

      _currentUser = user;

      // TODOデータ取得
      final myTodos = await _todoService.getMyTodos(userId: user.id);

      // グループデータ取得
      final userGroups = await _groupService.getUserGroups(userId: user.id);

      // グループごとのTODOを取得
      final List<TodoModel> allTodos = List.from(myTodos);
      for (final group in userGroups) {
        final groupTodos = await _todoService.getGroupTodos(
          userId: user.id,
          groupId: group.id,
        );
        allTodos.addAll(groupTodos);
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
        debugPrint('[DataCacheService] ✅ TODO完了切り替え: id=$todoId');
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
      debugPrint('[DataCacheService] ✅ TODO作成: id=${newTodo.id}');
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
        debugPrint('[DataCacheService] ✅ TODO更新: id=$todoId');
        notifyListeners();
      }

      return updatedTodo;
    } catch (e) {
      debugPrint('[DataCacheService] ❌ TODO更新エラー: $e');
      rethrow;
    }
  }

  /// TODO楽観的更新（キャッシュ即座更新 + 非同期DB更新）
  Future<void> updateTodoOptimistic({
    required String userId,
    required String todoId,
    required String title,
    String? description,
    DateTime? dueDate,
    List<String>? assignedUserIds,
    required Function(String) onNetworkError,
    required Function(String) onOtherError,
  }) async {
    // 1. 既存TODOをバックアップ
    final index = _todos.indexWhere((t) => t.id == todoId);
    if (index == -1) {
      debugPrint('[DataCacheService] ❌ TODO not found: id=$todoId');
      return;
    }
    final oldTodo = _todos[index];

    // 2. キャッシュを即座に更新（楽観的更新）
    final optimisticTodo = oldTodo.copyWith(
      title: title,
      description: description,
      dueDate: dueDate,
      assignedUserIds: assignedUserIds,
    );
    _todos[index] = optimisticTodo;
    notifyListeners(); // 画面即座に反映
    debugPrint('[DataCacheService] 🚀 楽観的更新: id=$todoId（画面即座反映）');

    // 3. 非同期でDB更新
    try {
      final updatedTodo = await _todoService.updateTodo(
        userId: userId,
        todoId: todoId,
        title: title,
        description: description,
        dueDate: dueDate,
        assignedUserIds: assignedUserIds,
      );

      // DB更新成功 → キャッシュを正式な値で再更新
      _todos[index] = updatedTodo;
      notifyListeners();
      debugPrint('[DataCacheService] ✅ DB更新成功: id=$todoId');
    } catch (e) {
      final errorMessage = e.toString();
      debugPrint('[DataCacheService] ❌ DB更新エラー: $errorMessage');

      // ネットワークエラー判定
      final isNetworkError =
          errorMessage.contains('SocketException') ||
          errorMessage.contains('network') ||
          errorMessage.contains('connection') ||
          errorMessage.contains('timeout');

      if (isNetworkError) {
        // ネットワークエラー → ロールバック
        _todos[index] = oldTodo;
        notifyListeners();
        debugPrint('[DataCacheService] 🔄 ロールバック実施（ネットワークエラー）');
        onNetworkError('ネットワーク接続を確認してください');
      } else {
        // その他のエラー → エラー画面遷移
        debugPrint('[DataCacheService] 🚨 サーバーエラー（エラー画面遷移）');
        onOtherError('更新に失敗しました。管理者に問い合わせてください。');
      }
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
      debugPrint('[DataCacheService] ✅ TODO削除: id=$todoId');
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
  }) async {
    try {
      // 1. DB作成
      final newGroup = await _groupService.createGroup(
        userId: userId,
        groupName: groupName,
        description: description,
        category: category,
      );

      // 2. DB作成成功 → キャッシュに追加
      _groups.add(newGroup);
      debugPrint('[DataCacheService] ✅ グループ作成: id=${newGroup.id}');
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
  }) async {
    try {
      // 1. DB更新
      final updatedGroup = await _groupService.updateGroup(
        userId: userId,
        groupId: groupId,
        groupName: groupName,
        description: description,
        category: category,
      );

      // 2. DB更新成功 → キャッシュ更新
      final index = _groups.indexWhere((g) => g.id == groupId);
      if (index != -1) {
        _groups[index] = updatedGroup;
        debugPrint('[DataCacheService] ✅ グループ更新: id=$groupId');
        notifyListeners();
      }

      return updatedGroup;
    } catch (e) {
      debugPrint('[DataCacheService] ❌ グループ更新エラー: $e');
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

  /// グループに紐づくTODO一覧を取得
  List<TodoModel> getTodosByGroupId(String groupId) {
    debugPrint(
      '[DataCacheService] 🔍 getTodosByGroupId: groupId=$groupId, 全TODO数=${_todos.length}',
    );
    final result = _todos.where((t) => t.groupId == groupId).toList();
    debugPrint('[DataCacheService] 🔍 getTodosByGroupId結果: ${result.length}件');
    // デバッグ：各TODOのgroupIdを出力
    for (final todo in _todos) {
      debugPrint(
        '[DataCacheService] 🔍 TODO: id=${todo.id}, groupId="${todo.groupId}", title="${todo.title}"',
      );
    }
    return result;
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
