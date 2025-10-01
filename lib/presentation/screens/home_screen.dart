import 'package:flutter/material.dart';
import '../../data/models/user_model.dart';
import '../../data/models/todo_model.dart';
import '../../services/todo_service.dart';
import '../../services/group_service.dart';

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

  /// 自分のTODO読み込み
  Future<void> _loadMyTodos() async {
    setState(() => _isLoading = true);

    try {
      final todos = await _todoService.getMyTodos(
        userId: widget.user.id,
        filterDays: _filterDays,
      );

      if (!mounted) return;
      setState(() {
        _todos = todos;
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
              child: ListView.builder(
                itemCount: _todos.length,
                itemBuilder: (context, index) {
                  final todo = _todos[index];
                  return _TodoListTile(
                    todo: todo,
                    onToggle: () => _toggleTodoCompletion(todo),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateTodoDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  /// TODO作成ダイアログ表示
  Future<void> _showCreateTodoDialog() async {
    String? title;
    String? description;

    await showDialog(
      context: context,
      builder: (context) {
        final TextEditingController titleController = TextEditingController();
        final TextEditingController descController = TextEditingController();

        return AlertDialog(
          title: const Text('新しいTODOを作成'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'タイトル',
                  hintText: 'TODOのタイトルを入力',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: '説明（任意）',
                  hintText: 'TODOの詳細を入力',
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () {
                final titleText = titleController.text.trim();
                if (titleText.isNotEmpty) {
                  title = titleText;
                  description = descController.text.trim();
                  Navigator.pop(context);
                }
              },
              child: const Text('作成'),
            ),
          ],
        );
      },
    );

    if (title != null) {
      _createTodo(title!, description ?? '');
    }
  }

  /// TODO作成実行
  Future<void> _createTodo(String title, String description) async {
    try {
      // 個人用グループIDを取得
      final personalGroupId = await _getPersonalGroupId();

      if (personalGroupId == null) {
        _showErrorSnackBar('個人用グループが見つかりません');
        return;
      }

      // TODO作成
      await _todoService.createTodo(
        userId: widget.user.id,
        groupId: personalGroupId,
        title: title,
        description: description.isNotEmpty ? description : null,
      );

      if (!mounted) return;
      _showSuccessSnackBar('TODOを作成しました');
      _loadMyTodos();
    } catch (e) {
      debugPrint('[HomeScreen] ❌ TODO作成エラー: $e');
      _showErrorSnackBar('TODOの作成に失敗しました');
    }
  }

  /// 個人用グループID取得
  Future<String?> _getPersonalGroupId() async {
    try {
      final groups = await GroupService().getUserGroups(userId: widget.user.id);
      final personalGroup = groups.firstWhere(
        (group) => group.name == '個人TODO',
        orElse: () => throw Exception('Personal group not found'),
      );
      return personalGroup.id;
    } catch (e) {
      debugPrint('[HomeScreen] ❌ 個人グループ取得エラー: $e');
      return null;
    }
  }

  /// 成功メッセージ表示
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }
}

/// TODOリストタイル
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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Checkbox(
          value: todo.isCompleted,
          onChanged: (_) => onToggle(),
        ),
        title: Text(
          todo.title,
          style: TextStyle(
            decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
            color: todo.isCompleted
                ? Theme.of(context).colorScheme.outline
                : null,
          ),
        ),
        subtitle: todo.dueDate != null
            ? Text(
                '期限: ${_formatDate(todo.dueDate!)}',
                style: TextStyle(
                  color: isOverdue
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            : null,
        trailing: isOverdue
            ? Icon(Icons.warning, color: Theme.of(context).colorScheme.error)
            : null,
        onTap: () {
          // TODO詳細画面へ遷移（後で実装）
          debugPrint('[HomeScreen] TODO詳細画面へ遷移: ${todo.id}');
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }
}
