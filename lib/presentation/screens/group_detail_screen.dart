import 'package:flutter/material.dart';
import '../../data/models/user_model.dart';
import '../../data/models/group_model.dart';
import '../../data/models/todo_model.dart';
import '../../services/data_cache_service.dart';
import '../widgets/create_todo_bottom_sheet.dart';
import '../widgets/edit_group_bottom_sheet.dart';
import '../widgets/group_members_bottom_sheet.dart';

/// グループ詳細画面
class GroupDetailScreen extends StatefulWidget {
  final UserModel user;
  final GroupModel group;

  const GroupDetailScreen({super.key, required this.user, required this.group});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  final DataCacheService _cacheService = DataCacheService();
  List<TodoModel> _todos = [];
  late GroupModel _currentGroup;
  String _selectedFilter =
      'incomplete'; // 'incomplete', 'completed', 'my_incomplete'
  late TabController _tabController;
  int _currentTabIndex = 0;
  List<UserModel> _groupMembers = []; // グループメンバーリスト

  @override
  void initState() {
    super.initState();
    _currentGroup = widget.group;
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    });
    // キャッシュリスナー登録
    _cacheService.addListener(_updateGroupData);
    // 初回データ取得
    _updateGroupData();
    _loadGroupMembers();
  }

  /// グループメンバー読み込み（仮実装：現在のユーザーのみ）
  Future<void> _loadGroupMembers() async {
    // TODO: グループメンバー取得APIが実装されたら修正
    setState(() {
      _groupMembers = [widget.user];
    });
  }

  /// グループメンバー一覧ボトムシート表示
  void _showGroupMembers() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GroupMembersBottomSheet(members: _groupMembers),
    );
  }

  @override
  void dispose() {
    // リスナー解除
    _cacheService.removeListener(_updateGroupData);
    _tabController.dispose();
    super.dispose();
  }

  /// キャッシュからグループデータ取得
  void _updateGroupData() {
    debugPrint(
      '[GroupDetailScreen] 🔍 _updateGroupData開始: groupId=${widget.group.id}',
    );

    // キャッシュからグループ情報取得
    final group = _cacheService.getGroupById(widget.group.id);
    if (group != null) {
      _currentGroup = group;
      debugPrint('[GroupDetailScreen] 🔍 グループ情報取得成功: ${group.name}');
    } else {
      debugPrint('[GroupDetailScreen] ⚠️ グループ情報取得失敗');
    }

    // キャッシュからTODO取得
    final todos = _cacheService.getTodosByGroupId(widget.group.id);
    debugPrint('[GroupDetailScreen] 🔍 TODO取得結果: ${todos.length}件');

    if (mounted) {
      setState(() {
        _todos = todos;
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

  /// TODO作成実行（キャッシュサービス経由）
  Future<void> _createTodo({
    required String title,
    String? description,
    DateTime? deadline,
    List<String>? assigneeIds,
  }) async {
    try {
      // DataCacheService経由でDB作成+キャッシュ追加
      await _cacheService.createTodo(
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
    debugPrint(
      '[GroupDetailScreen] 📝 グループ編集開始: category=${_currentGroup.category}',
    );
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

  /// グループ更新実行（キャッシュサービス経由）
  Future<void> _updateGroup({
    required String name,
    String? description,
    String? category,
  }) async {
    try {
      // DataCacheService経由でDB更新+キャッシュ更新
      await _cacheService.updateGroup(
        groupId: _currentGroup.id,
        userId: widget.user.id,
        groupName: name,
        description: description,
        category: category,
      );

      if (!mounted) return;
      debugPrint(
        '[GroupDetailScreen] ✅ グループ更新完了: category=${_currentGroup.category}',
      );
      _showSuccessSnackBar('グループ情報を更新しました');
    } catch (e) {
      debugPrint('[GroupDetailScreen] ❌ グループ更新エラー: $e');
      _showErrorSnackBar('グループ情報の更新に失敗しました');
    }
  }

  /// フィルター済みTODOリスト
  List<TodoModel> get _filteredTodos {
    switch (_selectedFilter) {
      case 'completed':
        return _todos.where((todo) => todo.isCompleted).toList();
      case 'my_incomplete':
        return _todos
            .where(
              (todo) =>
                  !todo.isCompleted &&
                  (todo.assignedUserIds?.contains(widget.user.id) ?? false),
            )
            .toList();
      case 'incomplete':
      default:
        return _todos.where((todo) => !todo.isCompleted).toList();
    }
  }

  /// TODO削除（キャッシュサービス経由）
  Future<void> _deleteTodo(TodoModel todo) async {
    try {
      // DataCacheService経由でDB削除+キャッシュ削除
      await _cacheService.deleteTodo(userId: widget.user.id, todoId: todo.id);

      _showSuccessSnackBar('TODOを削除しました');
    } catch (e) {
      debugPrint('[GroupDetailScreen] ❌ TODO削除エラー: $e');
      _showErrorSnackBar('TODOの削除に失敗しました');
    }
  }

  /// TODO詳細画面表示
  Future<void> _showTodoDetail(TodoModel todo) async {
    await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateTodoBottomSheet(
        fixedGroupId: widget.group.id,
        fixedGroupName: widget.group.name,
        availableAssignees: null, // TODO: メンバー一覧取得して渡す
        currentUserId: widget.user.id,
        existingTodo: todo, // 編集モード：既存TODOデータを渡す
      ),
    );

    // キャッシュが自動更新されるため、手動リロード不要
  }

  /// 手動リフレッシュ
  Future<void> _refreshData() async {
    try {
      await _cacheService.refreshCache();
      _showSuccessSnackBar('データを更新しました');
    } catch (e) {
      debugPrint('[GroupDetailScreen] ❌ データ更新エラー: $e');
      _showErrorSnackBar('データの更新に失敗しました');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentGroup.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _showEditGroupDialog,
            tooltip: 'グループ編集',
          ),
        ],
      ),
      body: Column(
        children: [
          // ユーザーアイコン表示エリア
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                // ユーザーアイコン（最大5個表示）
                ...List.generate(
                  _groupMembers.length > 5 ? 5 : _groupMembers.length,
                  (index) {
                    final member = _groupMembers[index];
                    return Padding(
                      padding: EdgeInsets.only(right: index < 4 ? 8 : 0),
                      child: InkWell(
                        onTap: _showGroupMembers,
                        borderRadius: BorderRadius.circular(20),
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                          child: Text(
                            member.displayName.isNotEmpty
                                ? member.displayName[0].toUpperCase()
                                : 'U',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                // 5人以上いる場合は「+N」表示
                if (_groupMembers.length > 5)
                  InkWell(
                    onTap: _showGroupMembers,
                    borderRadius: BorderRadius.circular(20),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.secondaryContainer,
                      child: Text(
                        '+${_groupMembers.length - 5}',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                const Spacer(),
                // ユーザー招待ボタン
                IconButton(
                  icon: const Icon(Icons.person_add),
                  onPressed: () {
                    // TODO: 招待コード生成画面に遷移
                  },
                  tooltip: 'ユーザー招待',
                ),
              ],
            ),
          ),
          // セグメントコントロール風タブ
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _tabController.animateTo(0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _currentTabIndex == 0
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_box,
                              size: 20,
                              color: _currentTabIndex == 0
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'TODO',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: _currentTabIndex == 0
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.onPrimary
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _tabController.animateTo(1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _currentTabIndex == 1
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.settings,
                              size: 20,
                              color: _currentTabIndex == 1
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'グループ設定',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: _currentTabIndex == 1
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.onPrimary
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // タブコンテンツ
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // タブ1: TODOエリア
                RefreshIndicator(
                  onRefresh: _refreshData,
                  child: ListView(
                    padding: const EdgeInsets.only(top: 12),
                    children: [
                      // TODO見出し
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Text(
                          'TODO',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ),
                      // TODOフィルター（均等配置）
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _FilterChip(
                                label: '未完了',
                                isSelected: _selectedFilter == 'incomplete',
                                onTap: () => setState(
                                  () => _selectedFilter = 'incomplete',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _FilterChip(
                                label: '直近の完了',
                                isSelected: _selectedFilter == 'completed',
                                onTap: () => setState(
                                  () => _selectedFilter = 'completed',
                                ),
                              ),
                            ),
                            if (widget.group.category != 'personal') ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: _FilterChip(
                                  label: '自タスク',
                                  isSelected:
                                      _selectedFilter == 'my_incomplete',
                                  onTap: () => setState(
                                    () => _selectedFilter = 'my_incomplete',
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // TODOリスト
                      ..._filteredTodos.map(
                        (todo) => _TodoListTile(
                          todo: todo,
                          user: widget.user,
                          onToggle: () => _toggleTodoCompletion(todo),
                          onTap: () => _showTodoDetail(todo),
                          onDelete: () => _deleteTodo(todo),
                        ),
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
                // タブ2: グループ設定エリア
                RefreshIndicator(
                  onRefresh: _refreshData,
                  child: ListView(
                    padding: const EdgeInsets.only(top: 12),
                    children: [
                      // グループ設定見出し
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Text(
                          'グループ設定',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ),
                      // グループ設定エリア（カード化）
                      Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(
                                context,
                              ).colorScheme.shadow.withOpacity(0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '設定がありません',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _currentTabIndex == 0
          ? FloatingActionButton(
              onPressed: _showCreateTodoDialog,
              tooltip: 'TODO追加',
              child: const Icon(Icons.add_task),
            )
          : FloatingActionButton(
              onPressed: () {
                // TODO: グループ設定追加画面に遷移
              },
              tooltip: 'グループ設定追加',
              child: const Icon(Icons.playlist_add),
            ),
    );
  }
}

/// フィルターチップ
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
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
  final VoidCallback onDelete;

  const _TodoListTile({
    required this.todo,
    required this.user,
    required this.onToggle,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isOverdue =
        todo.dueDate != null &&
        todo.dueDate!.isBefore(now) &&
        !todo.isCompleted;

    return Dismissible(
      key: Key(todo.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Theme.of(context).colorScheme.error,
        child: Icon(Icons.delete, color: Theme.of(context).colorScheme.onError),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('削除確認'),
            content: Text('「${todo.title}」を削除しますか？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  '削除',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) => onDelete(),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.shadow.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(8),
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
                      child: Text(
                        todo.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                    ),
                    // 期限（右側配置）
                    if (todo.dueDate != null) ...[
                      const SizedBox(width: 12),
                      Row(
                        mainAxisSize: MainAxisSize.min,
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
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }
}
