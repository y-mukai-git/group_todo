import 'package:flutter/material.dart';
import '../../data/models/user_model.dart';
import '../../data/models/group_model.dart';
import '../../data/models/todo_model.dart';
import '../../services/todo_service.dart';
import '../../services/group_service.dart';
import '../widgets/create_todo_bottom_sheet.dart';
import '../widgets/edit_group_bottom_sheet.dart';
import '../widgets/banner_ad_widget.dart';
import 'todo_detail_screen.dart';

/// グループ詳細画面
class GroupDetailScreen extends StatefulWidget {
  final UserModel user;
  final GroupModel group;

  const GroupDetailScreen({
    super.key,
    required this.user,
    required this.group,
  });

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final TodoService _todoService = TodoService();
  final GroupService _groupService = GroupService();
  List<TodoModel> _todos = [];
  bool _isLoading = true;
  late GroupModel _currentGroup;
  bool _isFabOpen = false;

  @override
  void initState() {
    super.initState();
    _currentGroup = widget.group;
    _loadGroupTodos();
  }

  /// グループのTODO読み込み
  Future<void> _loadGroupTodos() async {
    setState(() => _isLoading = true);

    try {
      final todos = await _todoService.getGroupTodos(
        userId: widget.user.id,
        groupId: widget.group.id,
      );

      if (!mounted) return;
      setState(() {
        _todos = todos;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[GroupDetailScreen] ❌ TODO読み込みエラー: $e');
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

      _loadGroupTodos();
    } catch (e) {
      debugPrint('[GroupDetailScreen] ❌ TODO完了切り替えエラー: $e');
      _showErrorSnackBar('完了状態の更新に失敗しました');
    }
  }

  /// TODO作成ボトムシート表示
  Future<void> _showCreateTodoDialog() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: true,
      useRootNavigator: false,
      builder: (context) => CreateTodoBottomSheet(
        fixedGroupId: widget.group.id,
        fixedGroupName: widget.group.name,
        currentUserId: widget.user.id,
        availableAssignees: null, // TODO: メンバー一覧取得して渡す
      ),
    );

    if (result != null && mounted) {
      final assigneeIds = result['assignee_ids'] as List<dynamic>?;
      _createTodo(
        title: result['title'] as String,
        description: result['description'] as String?,
        deadline: result['deadline'] as DateTime?,
        assigneeIds: assigneeIds?.cast<String>() ?? [widget.user.id],
      );
    }
  }

  /// TODO作成実行
  Future<void> _createTodo({
    required String title,
    String? description,
    DateTime? deadline,
    List<String>? assigneeIds,
  }) async {
    try {
      await _todoService.createTodo(
        userId: widget.user.id,
        groupId: widget.group.id,
        title: title,
        description: description?.isNotEmpty == true ? description : null,
        dueDate: deadline,
        category: widget.group.category ?? 'other', // グループのカテゴリを使用
        assignedUserIds: assigneeIds,
      );

      if (!mounted) return;
      _showSuccessSnackBar('TODOを作成しました');
      _loadGroupTodos();
    } catch (e) {
      debugPrint('[GroupDetailScreen] ❌ TODO作成エラー: $e');
      _showErrorSnackBar('TODOの作成に失敗しました');
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

  /// グループ編集ボトムシート表示
  Future<void> _showEditGroupDialog() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: true,
      useRootNavigator: false,
      builder: (context) => EditGroupBottomSheet(group: _currentGroup),
    );

    if (result != null && mounted) {
      _updateGroup(
        name: result['name'] as String,
        description: result['description'] as String?,
        category: result['category'] as String?,
      );
    }
  }

  /// グループ更新実行
  Future<void> _updateGroup({
    required String name,
    String? description,
    String? category,
  }) async {
    try {
      final updatedGroup = await _groupService.updateGroup(
        groupId: _currentGroup.id,
        userId: widget.user.id,
        groupName: name,
        description: description,
        category: category,
      );

      if (!mounted) return;
      setState(() {
        _currentGroup = updatedGroup;
      });
      _showSuccessSnackBar('グループ情報を更新しました');
    } catch (e) {
      debugPrint('[GroupDetailScreen] ❌ グループ更新エラー: $e');
      _showErrorSnackBar('グループ情報の更新に失敗しました');
    }
  }

  /// TODO詳細画面表示
  Future<void> _showTodoDetail(TodoModel todo) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => TodoDetailScreen(
          user: widget.user,
          todo: todo,
          availableAssignees: null, // TODO: メンバー一覧取得して渡す
        ),
      ),
    );

    // 更新された場合は再読み込み
    if (result == true && mounted) {
      _loadGroupTodos();
    }
  }

  /// スピードダイヤル開閉
  void _toggleSpeedDial() {
    setState(() {
      _isFabOpen = !_isFabOpen;
    });
  }

  /// スピードダイヤルを閉じる
  void _closeSpeedDial() {
    if (_isFabOpen) {
      setState(() {
        _isFabOpen = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, IconData> categoryIcons = {
      'shopping': Icons.shopping_cart,
      'housework': Icons.home,
      'work': Icons.work,
      'hobby': Icons.palette,
      'other': Icons.label,
    };

    final Map<String, String> categoryNames = {
      'shopping': '買い物',
      'housework': '家事',
      'work': '仕事',
      'hobby': '趣味',
      'other': 'その他',
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentGroup.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _showEditGroupDialog,
            tooltip: '編集',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadGroupTodos,
            tooltip: '更新',
          ),
        ],
      ),
      body: Column(
        children: [
          // TODO一覧セクション
          Expanded(
            child: _isLoading
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
                              'TODOがありません',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '右下のボタンから新しいTODOを作成できます',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadGroupTodos,
                        child: ListView(
                          padding: const EdgeInsets.only(top: 12),
                          children: [
                            // TODO見出し
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                              child: Text(
                                'TODO',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                              ),
                            ),
                            // TODOリスト
                            ..._todos.map((todo) => _TodoListTile(
                                  todo: todo,
                                  user: widget.user,
                                  onToggle: () => _toggleTodoCompletion(todo),
                                  onTap: () => _showTodoDetail(todo),
                                )),
                            const SizedBox(height: 24),
                            // グループ設定見出し
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                              child: Text(
                                'グループ設定',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                              ),
                            ),
                            // グループ情報
                            if (_currentGroup.description != null || _currentGroup.category != null)
                              Container(
                                margin: const EdgeInsets.symmetric(horizontal: 16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (_currentGroup.description != null) ...[
                                      Text(
                                        _currentGroup.description!,
                                        style: Theme.of(context).textTheme.bodyMedium,
                                      ),
                                      if (_currentGroup.category != null) const SizedBox(height: 8),
                                    ],
                                    if (_currentGroup.category != null)
                                      Row(
                                        children: [
                                          Icon(
                                            categoryIcons[_currentGroup.category] ?? Icons.label,
                                            size: 16,
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            categoryNames[_currentGroup.category] ?? 'その他',
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                  color: Theme.of(context).colorScheme.primary,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: Stack(
        children: [
          // 背景タップでメニューを閉じる
          if (_isFabOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeSpeedDial,
                child: Container(
                  color: Colors.transparent,
                ),
              ),
            ),
          // スピードダイヤルメニュー
          Positioned(
            right: 16,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // TODO追加ボタン（1番目に表示）
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    begin: 0.0,
                    end: _isFabOpen ? 1.0 : 0.0,
                  ),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    final clampedValue = value.clamp(0.0, 1.0);
                    if (clampedValue == 0.0) {
                      return const SizedBox.shrink();
                    }
                    return Transform.translate(
                      offset: Offset(0, 30 * (1 - clampedValue)),
                      child: Opacity(
                        opacity: clampedValue,
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            'TODO追加',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FloatingActionButton(
                          heroTag: 'add_todo',
                          onPressed: () {
                            _closeSpeedDial();
                            _showCreateTodoDialog();
                          },
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          child: Icon(
                            Icons.add_task,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // グループ設定追加ボタン（2番目に表示、遅延あり）
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    begin: 0.0,
                    end: _isFabOpen ? 1.0 : 0.0,
                  ),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    final clampedValue = value.clamp(0.0, 1.0);
                    if (clampedValue == 0.0) {
                      return const SizedBox.shrink();
                    }
                    return Transform.translate(
                      offset: Offset(0, 30 * (1 - clampedValue)),
                      child: Opacity(
                        opacity: clampedValue,
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            'グループ設定追加',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FloatingActionButton(
                          heroTag: 'edit_group',
                          onPressed: () {
                            _closeSpeedDial();
                            _showEditGroupDialog();
                          },
                          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                          child: Icon(
                            Icons.playlist_add,
                            color: Theme.of(context).colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // メインFAB
                FloatingActionButton(
                  heroTag: 'main_fab',
                  onPressed: _toggleSpeedDial,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) {
                      return ScaleTransition(
                        scale: animation,
                        child: child,
                      );
                    },
                    child: Icon(
                      _isFabOpen ? Icons.close : Icons.menu,
                      key: ValueKey<bool>(_isFabOpen),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // バナー広告
          const BannerAdWidget(),

          // ボトムナビゲーションバー
          NavigationBar(
            selectedIndex: 1, // グループ画面
            onDestinationSelected: (index) {
              if (index == 0) {
                // ホームへ戻る
                Navigator.pop(context);
              } else if (index == 2) {
                // 設定画面へ（未実装）
              }
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'ホーム',
              ),
              NavigationDestination(
                icon: Icon(Icons.group_outlined),
                selectedIcon: Icon(Icons.group),
                label: 'グループ',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: '設定',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// TODOリストタイル
class _TodoListTile extends StatelessWidget {
  final TodoModel todo;
  final UserModel user;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  const _TodoListTile({
    required this.todo,
    required this.user,
    required this.onToggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isOverdue = todo.dueDate != null &&
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
