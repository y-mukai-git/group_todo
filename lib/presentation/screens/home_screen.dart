import 'package:flutter/material.dart';
import '../../data/models/user_model.dart';
import '../../data/models/todo_model.dart';
import '../../services/data_cache_service.dart';
import '../widgets/create_todo_bottom_sheet.dart';

/// ホーム画面（My TODO - 自分のTODO表示）
class HomeScreen extends StatefulWidget {
  final UserModel user;

  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DataCacheService _cacheService = DataCacheService();
  List<TodoModel> _todos = [];
  String _filterDays = '7'; // デフォルト: 1週間

  @override
  void initState() {
    super.initState();
    // キャッシュリスナー登録
    _cacheService.addListener(_updateTodos);
    // 初回データ取得
    _updateTodos();
  }

  @override
  void dispose() {
    // リスナー解除
    _cacheService.removeListener(_updateTodos);
    super.dispose();
  }

  /// キャッシュからTODO取得
  void _updateTodos() {
    final myTodos = _cacheService.getMyTodos(widget.user.id);

    // フィルタリング：期限切れ + 選択期間内のTODO
    final now = DateTime.now();
    final filteredTodos = myTodos.where((todo) {
      // 期限切れは常に表示
      if (todo.dueDate != null &&
          todo.dueDate!.isBefore(now) &&
          !todo.isCompleted) {
        return true;
      }
      // 選択期間内のTODO表示
      if (_filterDays == '0') {
        // 当日
        return todo.dueDate != null &&
            todo.dueDate!.year == now.year &&
            todo.dueDate!.month == now.month &&
            todo.dueDate!.day == now.day;
      } else if (_filterDays == '3') {
        // 3日以内
        final threeDaysLater = now.add(const Duration(days: 3));
        return todo.dueDate != null && todo.dueDate!.isBefore(threeDaysLater);
      } else {
        // 1週間以内（デフォルト）
        final oneWeekLater = now.add(const Duration(days: 7));
        return todo.dueDate != null && todo.dueDate!.isBefore(oneWeekLater);
      }
    }).toList();

    if (mounted) {
      setState(() {
        _todos = filteredTodos;
      });
    }
  }

  /// TODO完了状態切り替え（キャッシュサービス経由）
  Future<void> _toggleTodoCompletion(TodoModel todo) async {
    try {
      final wasCompleted = todo.isCompleted;

      // DataCacheService経由でDB更新+キャッシュ更新
      await _cacheService.toggleTodoCompletion(
        userId: widget.user.id,
        todoId: todo.id,
      );

      // 成功メッセージを表示
      if (wasCompleted) {
        _showSuccessSnackBar('TODOを未完了に戻しました');
      } else {
        _showSuccessSnackBar('TODOを完了しました');
      }
    } catch (e) {
      debugPrint('[HomeScreen] ❌ TODO完了切り替えエラー: $e');
      _showErrorSnackBar('完了状態の更新に失敗しました');
    }
  }

  /// 期限フィルター変更
  void _changeFilter(String filterDays) {
    setState(() {
      _filterDays = filterDays;
    });
    _updateTodos();
  }

  /// 手動リフレッシュ
  Future<void> _refreshData() async {
    try {
      await _cacheService.refreshCache();
      _showSuccessSnackBar('データを更新しました');
    } catch (e) {
      debugPrint('[HomeScreen] ❌ データ更新エラー: $e');
      _showErrorSnackBar('データの更新に失敗しました');
    }
  }

  /// エラーメッセージ表示
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  /// 成功メッセージ表示
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  /// TODO詳細画面表示
  Future<void> _showTodoDetail(TodoModel todo) async {
    final group = _cacheService.getGroupById(todo.groupId);
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      showDragHandle: true,
      isDismissible: true,
      barrierColor: Colors.black54,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateTodoBottomSheet(
        fixedGroupId: todo.groupId,
        fixedGroupName: group?.name ?? 'グループ',
        availableAssignees: null, // TODO: メンバー一覧取得して渡す
        currentUserId: widget.user.id,
        existingTodo: todo, // 編集モード：既存TODOデータを渡す
      ),
    );

    // 更新処理
    if (result != null && mounted) {
      final todoId = result['todo_id'] as String?;
      if (todoId != null) {
        // 編集モード：TODO更新
        await _updateTodo(
          todoId: todoId,
          title: result['title'] as String,
          description: result['description'] as String?,
          deadline: result['deadline'] as DateTime?,
          assigneeIds: (result['assignee_ids'] as List<dynamic>?)
              ?.cast<String>(),
        );
      }
    }
  }

  /// TODO更新実行（楽観的更新）
  Future<void> _updateTodo({
    required String todoId,
    required String title,
    String? description,
    DateTime? deadline,
    List<String>? assigneeIds,
  }) async {
    // 楽観的更新：キャッシュ即座更新 + 非同期DB更新
    await _cacheService.updateTodoOptimistic(
      userId: widget.user.id,
      todoId: todoId,
      title: title,
      description: description?.isNotEmpty == true ? description : null,
      dueDate: deadline,
      assignedUserIds: assigneeIds,
      onNetworkError: (message) {
        // ネットワークエラー → アラート表示（キャッシュは自動ロールバック済み）
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('ネットワークエラー'),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      },
      onOtherError: (message) {
        // その他のエラー → エラーメッセージ表示
        // TODO: 将来的にエラー画面遷移に変更
        if (mounted) {
          _showErrorSnackBar(message);
        }
      },
    );

    // 成功時のメッセージ（楽観的更新なので即座に表示）
    if (mounted) {
      _showSuccessSnackBar('TODOを更新しました');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My TODO'),
        actions: [
          // 期限フィルター
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: _changeFilter,
            initialValue: _filterDays,
            itemBuilder: (context) => [
              const PopupMenuItem(value: '0', child: Text('当日')),
              const PopupMenuItem(value: '3', child: Text('3日以内')),
              const PopupMenuItem(value: '7', child: Text('1週間以内')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: '更新',
          ),
        ],
      ),
      body: _todos.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '予定されているTODOはありません',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _refreshData,
              child: ListView(children: _buildGroupedTodoList()),
            ),
    );
  }

  /// グループごとにTODOリストを構築
  List<Widget> _buildGroupedTodoList() {
    // groupIdでグループ化
    final groupedTodos = <String, List<TodoModel>>{};
    for (final todo in _todos) {
      final groupId = todo.groupId;
      if (!groupedTodos.containsKey(groupId)) {
        groupedTodos[groupId] = [];
      }
      groupedTodos[groupId]!.add(todo);
    }

    // グループごとにウィジェット構築
    final widgets = <Widget>[];

    // 最初に上部余白を追加
    widgets.add(const SizedBox(height: 12));

    groupedTodos.forEach((groupId, todos) {
      // グループヘッダー（キャッシュからグループ名を取得）
      final group = _cacheService.getGroupById(groupId);
      final groupName = group?.name ?? todos.first.groupName ?? 'グループ';
      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            groupName,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
      );

      // グループ内のTODO一覧
      for (final todo in todos) {
        widgets.add(
          _TodoListTile(
            todo: todo,
            onToggle: () => _toggleTodoCompletion(todo),
            onTap: () => _showTodoDetail(todo),
          ),
        );
      }
    });

    return widgets;
  }
}

/// TODOリストタイル（スタイリッシュなフラットデザイン）
class _TodoListTile extends StatelessWidget {
  final TodoModel todo;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  const _TodoListTile({
    required this.todo,
    required this.onToggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isOverdue =
        todo.dueDate != null &&
        todo.dueDate!.isBefore(now) &&
        !todo.isCompleted;

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // チェックボックス
                Transform.scale(
                  scale: 1.1,
                  child: Checkbox(
                    value: todo.isCompleted,
                    onChanged: (_) => onToggle(),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // TODO内容
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        todo.title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          decoration: todo.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: todo.isCompleted
                              ? Theme.of(context).colorScheme.outline
                              : Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (todo.dueDate != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: isOverdue
                                  ? Theme.of(context).colorScheme.error
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(todo.dueDate!),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: isOverdue
                                        ? Theme.of(context).colorScheme.error
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }
}
