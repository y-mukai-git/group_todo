import 'package:flutter/material.dart';
import '../../data/models/user_model.dart';
import '../../data/models/todo_model.dart';
import '../../services/data_cache_service.dart';
import '../../services/error_log_service.dart';
import '../widgets/create_todo_bottom_sheet.dart';
import '../widgets/error_dialog.dart';

/// ホーム画面（MyTODO - 自分のタスク表示）
class HomeScreen extends StatefulWidget {
  final UserModel user;

  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DataCacheService _cacheService = DataCacheService();
  List<TodoModel> _todos = [];
  String _filterDays = '0'; // デフォルト: 本日期限
  late PageController _pageController;
  int _currentGroupIndex = 0;

  @override
  void initState() {
    super.initState();
    // PageController初期化
    _pageController = PageController();
    // キャッシュリスナー登録
    _cacheService.addListener(_updateTodos);
    // 初回データ取得
    _updateTodos();
  }

  @override
  void dispose() {
    // PageController破棄
    _pageController.dispose();
    // リスナー解除
    _cacheService.removeListener(_updateTodos);
    super.dispose();
  }

  /// キャッシュからTODO取得
  void _updateTodos() {
    final myTodos = _cacheService.getMyTodos(widget.user.id);

    // フィルタリング：選択期間に応じたTODO表示
    final now = DateTime.now();
    final filteredTodos = myTodos.where((todo) {
      // 全量表示
      if (_filterDays == 'all') {
        return true;
      }

      // 期限なしTODOは「本日期限」以外で表示
      if (todo.dueDate == null) {
        return _filterDays != '0';
      }

      // 期限切れは常に表示（未完了のみ）
      if (todo.dueDate!.isBefore(now) && !todo.isCompleted) {
        return true;
      }

      // 選択期間内のTODO表示
      if (_filterDays == '0') {
        // 本日期限
        return todo.dueDate!.year == now.year &&
            todo.dueDate!.month == now.month &&
            todo.dueDate!.day == now.day;
      } else if (_filterDays == '7') {
        // 1週間以内
        final oneWeekLater = now.add(const Duration(days: 7));
        return todo.dueDate!.isBefore(oneWeekLater) ||
            todo.dueDate!.isAtSameMomentAs(oneWeekLater);
      } else if (_filterDays == '30') {
        // 1ヶ月以内
        final oneMonthLater = now.add(const Duration(days: 30));
        return todo.dueDate!.isBefore(oneMonthLater) ||
            todo.dueDate!.isAtSameMomentAs(oneMonthLater);
      }

      return false;
    }).toList();

    if (mounted) {
      setState(() {
        _todos = filteredTodos;
      });
    }
  }

  /// タスク完了状態切り替え（キャッシュサービス経由）
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
        _showSuccessSnackBar('タスクを未完了に戻しました');
      } else {
        _showSuccessSnackBar('タスクを完了しました');
      }
    } catch (e, stackTrace) {
      debugPrint('[HomeScreen] ❌ タスク完了切り替えエラー: $e');

      // エラーログ記録
      final errorLog = await ErrorLogService().logError(
        userId: widget.user.id,
        errorType: 'タスク完了切り替えエラー',
        errorMessage: e.toString(),
        stackTrace: stackTrace.toString(),
        screenName: 'ホーム画面',
      );

      // エラーダイアログ表示
      if (!mounted) return;
      await ErrorDialog.show(
        context: context,
        errorId: errorLog.id,
        errorMessage: '完了状態の更新に失敗しました',
      );
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
    } catch (e, stackTrace) {
      debugPrint('[HomeScreen] ❌ データ更新エラー: $e');

      // エラーログ記録
      final errorLog = await ErrorLogService().logError(
        userId: widget.user.id,
        errorType: 'データ更新エラー',
        errorMessage: e.toString(),
        stackTrace: stackTrace.toString(),
        screenName: 'ホーム画面',
      );

      // エラーダイアログ表示
      if (!mounted) return;
      await ErrorDialog.show(
        context: context,
        errorId: errorLog.id,
        errorMessage: 'データの更新に失敗しました',
      );
    }
  }

  /// 成功メッセージ表示
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  /// タスク詳細画面表示
  Future<void> _showTodoDetail(TodoModel todo) async {
    final group = _cacheService.getGroupById(todo.groupId);

    // グループメンバー情報取得
    final membersData = _cacheService.getGroupMembers(todo.groupId);

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: true,
      useRootNavigator: false,
      builder: (context) {
        // コンテンツエリアの80%を固定値として計算
        final mediaQuery = MediaQuery.of(context);
        final contentHeight =
            mediaQuery.size.height -
            mediaQuery.padding.top -
            mediaQuery.padding.bottom;

        return Container(
          height: contentHeight * 0.8,
          margin: EdgeInsets.only(top: contentHeight * 0.2),
          child: CreateTodoBottomSheet(
            fixedGroupId: todo.groupId,
            fixedGroupName: group?.name ?? 'グループ',
            availableAssignees:
                membersData != null && membersData['success'] == true
                ? (membersData['members'] as List<dynamic>).map((m) {
                    final memberId = m['id'] as String;
                    final memberName = memberId == _cacheService.currentUser!.id
                        ? _cacheService.currentUser!.displayName
                        : m['display_name'] as String;
                    return {'id': memberId, 'name': memberName};
                  }).toList()
                : null,
            currentUserId: widget.user.id,
            currentUserName: _cacheService.currentUser!.displayName,
            existingTodo: todo, // 編集モード：既存TODOデータを渡す
          ),
        );
      },
    );

    // 更新処理
    if (result != null && mounted) {
      final todoId = result['todo_id'] as String?;
      if (todoId != null) {
        // ローディング表示
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) =>
              const Center(child: CircularProgressIndicator()),
        );

        try {
          // 編集モード：タスク更新
          await _updateTodo(
            todoId: todoId,
            title: result['title'] as String,
            description: result['description'] as String?,
            deadline: result['deadline'] as DateTime?,
            assigneeIds: (result['assignee_ids'] as List<dynamic>?)
                ?.cast<String>(),
          );

          // ローディング非表示（フレーム完了後に実行）
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) Navigator.of(context, rootNavigator: true).pop();
            });
          }
        } catch (e) {
          // ローディング非表示
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) Navigator.of(context, rootNavigator: true).pop();
            });
          }
          rethrow;
        }
      }
    }
  }

  /// タスク更新実行（楽観的更新）
  Future<void> _updateTodo({
    required String todoId,
    required String title,
    String? description,
    DateTime? deadline,
    List<String>? assigneeIds,
  }) async {
    try {
      // 楽観的更新：キャッシュ即座更新 + 非同期DB更新
      await _cacheService.updateTodoOptimistic(
        userId: widget.user.id,
        todoId: todoId,
        title: title,
        description: description?.isNotEmpty == true ? description : null,
        dueDate: deadline,
        assignedUserIds: assigneeIds,
      );
    } catch (e, stackTrace) {
      // エラーログをDB登録
      await ErrorLogService().logError(
        userId: widget.user.id,
        errorType: 'todo_update_error',
        errorMessage: e.toString(),
        stackTrace: stackTrace.toString(),
        screenName: 'home_screen',
      );

      // エラーダイアログ表示
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('エラー'),
            content: Text('タスクの更新に失敗しました\n$e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }

    // 成功時のメッセージ（楽観的更新なので即座に表示）
    if (mounted) {
      _showSuccessSnackBar('タスクを更新しました');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(title: const Text('My TODO'), actions: []),
      body: _buildGroupPageView(),
      floatingActionButton: FloatingActionButton(
        heroTag: 'home_fab',
        onPressed: () async {
          // 選択中グループの情報を取得
          final myGroups = _cacheService.groups;
          final selectedGroup =
              myGroups.isNotEmpty && _currentGroupIndex < myGroups.length
              ? myGroups[_currentGroupIndex]
              : null;

          // デフォルトグループのメンバー情報取得
          final membersData = selectedGroup != null
              ? _cacheService.getGroupMembers(selectedGroup.id)
              : null;

          // asyncギャップの前にmountedチェックとcontextを保存
          if (!mounted) return;
          final localContext = context;

          final result = await showModalBottomSheet<Map<String, dynamic>>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            enableDrag: true,
            isDismissible: true,
            useRootNavigator: false,
            builder: (context) {
              // コンテンツエリアの80%を固定値として計算
              final mediaQuery = MediaQuery.of(context);
              final contentHeight =
                  mediaQuery.size.height -
                  mediaQuery.padding.top -
                  mediaQuery.padding.bottom;

              return Container(
                height: contentHeight * 0.8,
                margin: EdgeInsets.only(top: contentHeight * 0.2),
                child: CreateTodoBottomSheet(
                  fixedGroupId: null, // グループ選択UI表示
                  defaultGroupId: selectedGroup?.id, // 選択中のグループをデフォルト値に設定
                  availableAssignees:
                      membersData != null && membersData['success'] == true
                      ? (membersData['members'] as List<dynamic>).map((m) {
                          final memberId = m['id'] as String;
                          final memberName =
                              memberId == _cacheService.currentUser!.id
                              ? _cacheService.currentUser!.displayName
                              : m['display_name'] as String;
                          return {'id': memberId, 'name': memberName};
                        }).toList()
                      : null,
                  currentUserId: widget.user.id,
                  currentUserName: _cacheService.currentUser!.displayName,
                  existingTodo: null,
                ),
              );
            },
          );

          // asyncギャップの後にmountedチェック
          if (!mounted) return;
          if (result == null) return;

          final isCreatingNewGroup = result['is_creating_new_group'] as bool?;
          final title = result['title'] as String;
          final description = result['description'] as String?;
          final deadline = result['deadline'] as DateTime?;
          final assigneeIds =
              (result['assignee_ids'] as List<dynamic>?)?.cast<String>() ??
              [widget.user.id];

          // ローディング表示
          if (mounted) {
            showDialog(
              // ignore: use_build_context_synchronously
              context: localContext,
              barrierDismissible: false,
              builder: (context) =>
                  const Center(child: CircularProgressIndicator()),
            );
          }

          try {
            String groupId;

            // 新規グループ作成の場合
            if (isCreatingNewGroup == true) {
              final groupName = result['group_name'] as String;
              final groupDescription = result['group_description'] as String?;
              final groupCategory = result['group_category'] as String?;
              final groupImageData = result['group_image_data'] as String?;

              // グループ作成
              final newGroup = await _cacheService.createGroup(
                userId: widget.user.id,
                groupName: groupName,
                description: groupDescription,
                category: groupCategory,
                imageData: groupImageData,
              );
              groupId = newGroup.id;
              _showSuccessSnackBar('グループを作成しました');
            } else {
              // 既存グループ選択の場合
              groupId = result['group_id'] as String;
            }

            // タスク作成
            await _cacheService.createTodo(
              userId: widget.user.id,
              groupId: groupId,
              title: title,
              description: description?.isNotEmpty == true ? description : null,
              dueDate: deadline,
              category: 'other',
              assignedUserIds: assigneeIds,
            );

            _showSuccessSnackBar('タスクを作成しました');

            // ローディング非表示（フレーム完了後に実行）
            if (mounted) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                // ignore: use_build_context_synchronously
                if (mounted) {
                  Navigator.of(localContext, rootNavigator: true).pop();
                }
              });
            }
          } catch (e, stackTrace) {
            debugPrint('[HomeScreen] ❌ タスク/グループ作成エラー: $e');

            // ローディング非表示
            if (mounted) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                // ignore: use_build_context_synchronously
                if (mounted) {
                  Navigator.of(localContext, rootNavigator: true).pop();
                }
              });
            }

            // エラーログ記録
            final errorLog = await ErrorLogService().logError(
              userId: widget.user.id,
              errorType: 'タスク作成エラー',
              errorMessage: e.toString(),
              stackTrace: stackTrace.toString(),
              screenName: 'ホーム画面',
            );

            // エラーメッセージ表示（フレーム完了後に安全に表示）
            if (mounted) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  // ignore: use_build_context_synchronously
                  ScaffoldMessenger.of(localContext).showSnackBar(
                    SnackBar(
                      content: Text('タスク/グループの作成に失敗しました（ID: ${errorLog.id}）'),
                      // ignore: use_build_context_synchronously
                      backgroundColor: Theme.of(localContext).colorScheme.error,
                      duration: const Duration(seconds: 5),
                    ),
                  );
                }
              });
            }
          }
        },
        tooltip: 'タスク作成',
        child: const Icon(Icons.add),
      ),
    );
  }

  /// グループスワイプ切り替えPageView構築
  Widget _buildGroupPageView() {
    final myGroups = _cacheService.groups;

    return Column(
      children: [
        // フィルターチップ（均等配置・折り返し調整）
        Container(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: _FilterChip(
                  label: '本日期限',
                  isSelected: _filterDays == '0',
                  onTap: () => _changeFilter('0'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _FilterChip(
                  label: '1週間以内',
                  isSelected: _filterDays == '7',
                  onTap: () => _changeFilter('7'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _FilterChip(
                  label: '1ヶ月以内',
                  isSelected: _filterDays == '30',
                  onTap: () => _changeFilter('30'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _FilterChip(
                  label: '全て',
                  isSelected: _filterDays == 'all',
                  onTap: () => _changeFilter('all'),
                ),
              ),
            ],
          ),
        ),
        // 横スクロール可能なグループタブバー
        Container(
          height: 54,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 1,
              ),
            ),
          ),
          child: myGroups.isEmpty
              ? const SizedBox.expand()
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: MediaQuery.of(context).size.width - 32,
                    ),
                    child: Row(
                      children: myGroups.asMap().entries.map((entry) {
                        final index = entry.key;
                        final group = entry.value;
                        final isSelected = index == _currentGroupIndex;

                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          child: InkWell(
                            onTap: () {
                              _pageController.animateToPage(
                                index,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(8),
                              topRight: Radius.circular(8),
                            ),
                            child: Container(
                              width: 130, // 1画面約2.5グループ表示・省略表示減らす（調整）
                              height: 54,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.primaryContainer
                                    : Colors.transparent,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(8),
                                  topRight: Radius.circular(8),
                                ),
                                border: isSelected
                                    ? Border(
                                        left: BorderSide(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.outline,
                                          width: 1,
                                        ),
                                        right: BorderSide(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.outline,
                                          width: 1,
                                        ),
                                        top: BorderSide(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.outline,
                                          width: 1,
                                        ),
                                      )
                                    : null,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // グループ名
                                  Text(
                                    group.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: isSelected
                                              ? Theme.of(
                                                  context,
                                                ).colorScheme.onPrimaryContainer
                                              : Theme.of(
                                                  context,
                                                ).colorScheme.onSurface,
                                        ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                  // タスク件数
                                  Text(
                                    '${_todos.where((t) => t.groupId == group.id).length}件',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: isSelected
                                              ? Theme.of(context)
                                                    .colorScheme
                                                    .onPrimaryContainer
                                                    .withValues(alpha: 0.7)
                                              : Theme.of(context)
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: 0.6),
                                        ),
                                  ),
                                  // アクティブタブの下部インジケーター
                                  if (isSelected)
                                    Container(
                                      height: 1.5,
                                      margin: EdgeInsets.zero,
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
        ),
        // PageView for group content
        Expanded(
          child: myGroups.isEmpty
              ? RefreshIndicator(
                  onRefresh: _refreshData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height - 200,
                      child: const Center(child: Text('TODOがありません')),
                    ),
                  ),
                )
              : PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentGroupIndex = index;
                    });
                  },
                  itemCount: myGroups.length,
                  itemBuilder: (context, index) {
                    final group = myGroups[index];
                    // このグループのタスクを取得
                    final groupTodos = _todos
                        .where((todo) => todo.groupId == group.id)
                        .toList();

                    return RefreshIndicator(
                      onRefresh: _refreshData,
                      child: groupTodos.isEmpty
                          ? ListView(
                              children: [
                                SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height * 0.3,
                                ),
                                Center(
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.inbox_outlined,
                                        size: 48,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.outline,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'TODOがありません',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.copyWith(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.outline,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: groupTodos.length,
                              itemBuilder: (context, todoIndex) {
                                final todo = groupTodos[todoIndex];
                                return _TodoListTile(
                                  todo: todo,
                                  onToggle: () => _toggleTodoCompletion(todo),
                                  onTap: () => _showTodoDetail(todo),
                                );
                              },
                            ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// タスクリストタイル（スタイリッシュなフラットデザイン）
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
                // タスク内容
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
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
