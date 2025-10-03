import 'package:flutter/material.dart';
import '../../data/models/user_model.dart';
import '../../data/models/todo_model.dart';
import '../../services/todo_service.dart';

/// ホーム画面（My TODO - 自分のTODO表示）
class HomeScreen extends StatefulWidget {
  final UserModel user;

  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TodoService _todoService = TodoService();
  List<TodoModel> _todos = [];
  bool _isLoading = true;
  String _filterDays = '7'; // デフォルト: 1週間

  @override
  void initState() {
    super.initState();
    _loadMyTodos();
  }

  /// 自分のTODO読み込み（期限切れ+選択期間のフィルタリング）
  Future<void> _loadMyTodos() async {
    setState(() => _isLoading = true);

    try {
      final todos = await _todoService.getMyTodos(
        userId: widget.user.id,
        filterDays: _filterDays,
      );

      if (!mounted) return;

      // フィルタリング：期限切れ + 選択期間内のTODO
      final now = DateTime.now();
      final filteredTodos = todos.where((todo) {
        // 期限切れは常に表示
        if (todo.dueDate != null && todo.dueDate!.isBefore(now) && !todo.isCompleted) {
          return true;
        }
        // 選択期間内のTODO表示（APIフィルタ済み）
        return true;
      }).toList();

      setState(() {
        _todos = filteredTodos;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[HomeScreen] ❌ TODO読み込みエラー: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showErrorSnackBar('TODOの読み込みに失敗しました');
    }
  }

  /// TODO完了状態切り替え
  Future<void> _toggleTodoCompletion(TodoModel todo) async {
    try {
      await _todoService.toggleTodoCompletion(
        userId: widget.user.id,
        todoId: todo.id,
      );

      // リスト更新
      _loadMyTodos();
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
    _loadMyTodos();
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
            onPressed: _loadMyTodos,
            tooltip: '更新',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _todos.isEmpty
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
              onRefresh: _loadMyTodos,
              child: ListView(
                children: _buildGroupedTodoList(),
              ),
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
      // グループヘッダー（APIから取得したグループ名を表示、なければgroupIdを表示）
      final groupName = todos.first.groupName ?? 'グループ: $groupId';
      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            groupName,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
      );

      // グループ内のTODO一覧
      for (final todo in todos) {
        widgets.add(_TodoListTile(
          todo: todo,
          onToggle: () => _toggleTodoCompletion(todo),
        ));
      }
    });

    return widgets;
  }
}

/// TODOリストタイル（スタイリッシュなフラットデザイン）
class _TodoListTile extends StatelessWidget {
  final TodoModel todo;
  final VoidCallback onToggle;

  const _TodoListTile({required this.todo, required this.onToggle});

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
          onTap: () {
            debugPrint('[HomeScreen] TODO詳細画面へ遷移: ${todo.id}');
          },
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
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(todo.dueDate!),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: isOverdue
                                        ? Theme.of(context).colorScheme.error
                                        : Theme.of(context).colorScheme.onSurfaceVariant,
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
