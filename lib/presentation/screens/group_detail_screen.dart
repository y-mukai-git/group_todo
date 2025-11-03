import 'package:flutter/material.dart';
import '../../data/models/user_model.dart';
import '../../data/models/group_model.dart';
import '../../data/models/todo_model.dart';
import '../../data/models/recurring_todo_model.dart';
import '../../services/data_cache_service.dart';
import '../../services/group_service.dart';
import '../../services/recurring_todo_service.dart';
import '../../services/error_log_service.dart';
import '../widgets/create_todo_bottom_sheet.dart';
import '../widgets/edit_group_bottom_sheet.dart';
import '../widgets/group_members_bottom_sheet.dart';
import '../widgets/create_recurring_todo_bottom_sheet.dart';
import '../widgets/error_dialog.dart';

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
  final RecurringTodoService _recurringTodoService = RecurringTodoService();
  List<TodoModel> _todos = [];
  late GroupModel _currentGroup;
  String _selectedFilter =
      'incomplete'; // 'incomplete', 'completed', 'my_incomplete'
  late TabController _tabController;
  int _currentTabIndex = 0;
  List<UserModel> _groupMembers = []; // グループメンバーリスト
  List<RecurringTodoModel> _recurringTodos = []; // 定期TODOリスト
  bool _isLoadingRecurringTodos = false;

  @override
  void initState() {
    super.initState();
    _currentGroup = widget.group;
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
      // グループ設定タブに切り替えた時に定期タスクを読み込む
      if (_currentTabIndex == 1) {
        _loadRecurringTodos();
      }
    });
    // キャッシュリスナー登録
    _cacheService.addListener(_updateGroupData);
    // 初回データ取得
    _updateGroupData();
  }

  /// グループメンバー一覧ボトムシート表示
  void _showGroupMembers({int initialTab = 0}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return GroupMembersBottomSheet(
                groupId: widget.group.id,
                members: _groupMembers,
                currentUserId: widget.user.id,
                groupOwnerId: widget.group.ownerId,
                onRemoveMember: _removeMember,
                onMembersUpdated: () {
                  _updateGroupData();
                  setModalState(() {});
                },
                initialTab: initialTab,
              );
            },
          ),
        );
      },
    );
  }

  /// メンバー削除
  Future<void> _removeMember(String userId) async {
    try {
      // API呼び出し：グループメンバー削除
      await GroupService().removeGroupMember(
        groupId: widget.group.id,
        userId: widget.user.id,
        targetUserId: userId,
      );

      setState(() {
        _groupMembers.removeWhere((member) => member.id == userId);
      });

      if (!mounted) return;
      Navigator.pop(context); // ボトムシートを閉じる
      _showSuccessSnackBar('メンバーを削除しました');
    } catch (e, stackTrace) {
      debugPrint('[GroupDetailScreen] ❌ メンバー削除エラー: $e');
      final errorLog = await ErrorLogService().logError(
        userId: widget.user.id,
        errorType: 'メンバー削除エラー',
        errorMessage: e.toString(),
        stackTrace: stackTrace.toString(),
        screenName: 'グループ詳細画面',
      );
      if (mounted) {
        await ErrorDialog.show(
          context: context,
          errorId: errorLog.id,
          errorMessage: 'メンバーの削除に失敗しました',
        );
      }
    }
  }

  /// 定期タスク一覧読み込み
  Future<void> _loadRecurringTodos() async {
    if (_isLoadingRecurringTodos) return;

    setState(() {
      _isLoadingRecurringTodos = true;
    });

    try {
      final recurringTodos = await _recurringTodoService.getRecurringTodos(
        userId: widget.user.id,
        groupId: widget.group.id,
      );

      if (mounted) {
        setState(() {
          _recurringTodos = recurringTodos;
          _isLoadingRecurringTodos = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('[GroupDetailScreen] ❌ 定期タスク一覧取得エラー: $e');
      final errorLog = await ErrorLogService().logError(
        userId: widget.user.id,
        errorType: '定期タスク一覧取得エラー',
        errorMessage: e.toString(),
        stackTrace: stackTrace.toString(),
        screenName: 'グループ詳細画面',
      );
      if (mounted) {
        setState(() {
          _isLoadingRecurringTodos = false;
        });
        await ErrorDialog.show(
          context: context,
          errorId: errorLog.id,
          errorMessage: '定期タスク一覧の取得に失敗しました',
        );
      }
    }
  }

  /// 定期タスク作成ボトムシート表示
  Future<void> _showCreateRecurringTodoDialog() async {
    final result = await showModalBottomSheet<bool>(
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
          child: CreateRecurringTodoBottomSheet(
            groupId: widget.group.id,
            groupName: widget.group.name,
            userId: widget.user.id,
            availableAssignees: _groupMembers
                .map(
                  (member) => {
                    'id': member.id,
                    'name': member.id == widget.user.id
                        ? _cacheService.currentUser!.displayName
                        : member.displayName,
                  },
                )
                .toList(),
          ),
        );
      },
    );

    if (result == true && mounted) {
      _loadRecurringTodos(); // 一覧を再取得
      _showSuccessSnackBar('定期タスクを作成しました');
    }
  }

  /// 定期TODO編集ボトムシート表示
  Future<void> _showEditRecurringTodoDialog(
    RecurringTodoModel recurringTodo,
  ) async {
    final result = await showModalBottomSheet<bool>(
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
          child: CreateRecurringTodoBottomSheet(
            groupId: widget.group.id,
            groupName: widget.group.name,
            userId: widget.user.id,
            availableAssignees: _groupMembers
                .map(
                  (member) => {
                    'id': member.id,
                    'name': member.id == widget.user.id
                        ? _cacheService.currentUser!.displayName
                        : member.displayName,
                  },
                )
                .toList(),
            existingRecurringTodo: recurringTodo,
          ),
        );
      },
    );

    if (result == true && mounted) {
      _loadRecurringTodos(); // 一覧を再取得
      _showSuccessSnackBar('定期タスクを更新しました');
    }
  }

  /// 定期タスク削除
  Future<void> _deleteRecurringTodo(RecurringTodoModel recurringTodo) async {
    try {
      await _recurringTodoService.deleteRecurringTodo(
        userId: widget.user.id,
        recurringTodoId: recurringTodo.id,
      );

      if (mounted) {
        _loadRecurringTodos(); // 一覧を再取得
        _showSuccessSnackBar('定期タスクを削除しました');
      }
    } catch (e, stackTrace) {
      debugPrint('[GroupDetailScreen] ❌ 定期タスク削除エラー: $e');
      final errorLog = await ErrorLogService().logError(
        userId: widget.user.id,
        errorType: '定期タスク削除エラー',
        errorMessage: e.toString(),
        stackTrace: stackTrace.toString(),
        screenName: 'グループ詳細画面',
      );
      if (mounted) {
        await ErrorDialog.show(
          context: context,
          errorId: errorLog.id,
          errorMessage: '定期タスクの削除に失敗しました',
        );
      }
    }
  }

  /// 定期TODO ON/OFF切り替え
  Future<void> _toggleRecurringTodoActive(
    RecurringTodoModel recurringTodo,
  ) async {
    try {
      await _recurringTodoService.toggleRecurringTodoActive(
        userId: widget.user.id,
        recurringTodoId: recurringTodo.id,
      );

      if (mounted) {
        _loadRecurringTodos(); // 一覧を再取得
        final message = recurringTodo.isActive
            ? '定期タスクを無効にしました'
            : '定期タスクを有効にしました';
        _showSuccessSnackBar(message);
      }
    } catch (e, stackTrace) {
      debugPrint('[GroupDetailScreen] ❌ 定期TODO切り替えエラー: $e');
      final errorLog = await ErrorLogService().logError(
        userId: widget.user.id,
        errorType: '定期TODO切り替えエラー',
        errorMessage: e.toString(),
        stackTrace: stackTrace.toString(),
        screenName: 'グループ詳細画面',
      );
      if (mounted) {
        await ErrorDialog.show(
          context: context,
          errorId: errorLog.id,
          errorMessage: '定期タスクの切り替えに失敗しました',
        );
      }
    }
  }

  @override
  void dispose() {
    // リスナー解除
    _cacheService.removeListener(_updateGroupData);
    _tabController.dispose();
    super.dispose();
  }

  /// キャッシュからグループデータ取得
  Future<void> _updateGroupData() async {
    // キャッシュからグループ情報取得
    final group = _cacheService.getGroupById(widget.group.id);
    if (group != null) {
      _currentGroup = group;
    } else {
      debugPrint('[GroupDetailScreen] ⚠️ グループ情報取得失敗');
    }

    // キャッシュからTODO取得
    final todos = _cacheService.getTodosByGroupId(widget.group.id);

    // キャッシュからメンバー情報取得
    final membersData = _cacheService.getGroupMembers(widget.group.id);
    List<UserModel> members = [];
    if (membersData != null && membersData['success'] == true) {
      final membersList = membersData['members'] as List<dynamic>;
      members = membersList.map((memberData) {
        return UserModel.fromJson(memberData as Map<String, dynamic>);
      }).toList();
    } else {
      debugPrint('[GroupDetailScreen] ❌ メンバー情報取得失敗');
      final errorLog = await ErrorLogService().logError(
        userId: widget.user.id,
        errorType: 'メンバー情報取得エラー',
        errorMessage: 'キャッシュからのメンバー情報取得に失敗しました',
        stackTrace: StackTrace.current.toString(),
        screenName: 'グループ詳細画面',
      );
      if (mounted) {
        await ErrorDialog.show(
          context: context,
          errorId: errorLog.id,
          errorMessage: 'メンバー情報の取得に失敗しました',
        );
      }
      return; // 処理停止
    }

    if (mounted) {
      setState(() {
        _todos = todos;
        _groupMembers = members;
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
    } catch (e) {
      debugPrint('[GroupDetailScreen] ❌ タスク完了切り替えエラー: $e');
      _showErrorSnackBar('完了状態の更新に失敗しました');
    }
  }

  /// タスク作成ボトムシート表示
  Future<void> _showCreateTodoDialog() async {
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
            fixedGroupId: widget.group.id,
            fixedGroupName: widget.group.name,
            currentUserId: widget.user.id,
            currentUserName: _cacheService.currentUser!.displayName,
            availableAssignees: _groupMembers.map((member) {
              final memberName = member.id == widget.user.id
                  ? _cacheService.currentUser!.displayName
                  : member.displayName;
              return {'id': member.id, 'name': memberName};
            }).toList(),
          ),
        );
      },
    );

    if (result != null && mounted) {
      final assigneeIds = result['assignee_ids'] as List<dynamic>?;

      // ローディング表示
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        await _createTodo(
          title: result['title'] as String,
          description: result['description'] as String?,
          deadline: result['deadline'] as DateTime?,
          assigneeIds: assigneeIds?.cast<String>() ?? [widget.user.id],
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

  /// タスク作成実行（キャッシュサービス経由）
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
      _showSuccessSnackBar('タスクを作成しました');
    } catch (e) {
      debugPrint('[GroupDetailScreen] ❌ タスク作成エラー: $e');
      _showErrorSnackBar('タスクの作成に失敗しました');
    }
  }

  /// タスク更新実行（キャッシュサービス経由）
  Future<void> _updateTodo({
    required String todoId,
    required String title,
    String? description,
    DateTime? deadline,
    required List<String> assigneeIds,
  }) async {
    try {
      // DataCacheService経由でDB更新+キャッシュ更新
      await _cacheService.updateTodo(
        userId: widget.user.id,
        todoId: todoId,
        title: title,
        description: description?.isNotEmpty == true ? description : null,
        dueDate: deadline,
        assignedUserIds: assigneeIds,
      );

      if (!mounted) return;
      _showSuccessSnackBar('タスクを更新しました');
    } catch (e) {
      debugPrint('[GroupDetailScreen] ❌ タスク更新エラー: $e');
      _showErrorSnackBar('タスクの更新に失敗しました');
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
          child: EditGroupBottomSheet(group: _currentGroup),
        );
      },
    );

    if (result != null && mounted) {
      // ローディング表示
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        await _updateGroup(
          name: result['name'] as String,
          description: result['description'] as String?,
          category: result['category'] as String?,
          imageData: result['image_data'] as String?,
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

  /// グループ更新実行（キャッシュサービス経由）
  Future<void> _updateGroup({
    required String name,
    String? description,
    String? category,
    String? imageData,
  }) async {
    try {
      // DataCacheService経由でDB更新+キャッシュ更新
      await _cacheService.updateGroup(
        groupId: _currentGroup.id,
        userId: widget.user.id,
        groupName: name,
        description: description,
        category: category,
        imageData: imageData,
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

  /// 定期タスクの繰り返しパターンをテキスト化
  String _formatRecurrencePattern(RecurringTodoModel recurringTodo) {
    final timeParts = recurringTodo.generationTime.split(':');
    final timeStr = '${timeParts[0]}:${timeParts[1]}';

    switch (recurringTodo.recurrencePattern) {
      case 'daily':
        return '毎日 $timeStr';
      case 'weekly':
        if (recurringTodo.recurrenceDays == null ||
            recurringTodo.recurrenceDays!.isEmpty) {
          return '毎週 $timeStr';
        }
        final weekdays = ['日', '月', '火', '水', '木', '金', '土'];
        final dayNames = recurringTodo.recurrenceDays!
            .map((day) => weekdays[day])
            .join('・');
        return '毎週$dayNames $timeStr';
      case 'monthly':
        if (recurringTodo.recurrenceDays == null ||
            recurringTodo.recurrenceDays!.isEmpty) {
          return '毎月 $timeStr';
        }
        final day = recurringTodo.recurrenceDays!.first;
        if (day == -1) {
          return '毎月末 $timeStr';
        }
        return '毎月$day日 $timeStr';
      default:
        return timeStr;
    }
  }

  /// タスク削除（キャッシュサービス経由）
  Future<void> _deleteTodo(TodoModel todo) async {
    try {
      // DataCacheService経由でDB削除+キャッシュ削除
      await _cacheService.deleteTodo(userId: widget.user.id, todoId: todo.id);

      _showSuccessSnackBar('タスクを削除しました');
    } catch (e) {
      debugPrint('[GroupDetailScreen] ❌ タスク削除エラー: $e');
      _showErrorSnackBar('タスクの削除に失敗しました');
    }
  }

  /// タスク詳細画面表示
  Future<void> _showTodoDetail(TodoModel todo) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
            fixedGroupId: widget.group.id,
            fixedGroupName: widget.group.name,
            availableAssignees: _groupMembers.map((member) {
              final memberName = member.id == widget.user.id
                  ? _cacheService.currentUser!.displayName
                  : member.displayName;
              return {'id': member.id, 'name': memberName};
            }).toList(),
            currentUserId: widget.user.id,
            currentUserName: _cacheService.currentUser!.displayName,
            existingTodo: todo, // 編集モード：既存TODOデータを渡す
          ),
        );
      },
    );

    // 編集モード時：結果を受け取ってDB更新
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
          // 編集モード
          final assigneeIds = result['assignee_ids'] as List<dynamic>?;
          await _updateTodo(
            todoId: todoId,
            title: result['title'] as String,
            description: result['description'] as String?,
            deadline: result['deadline'] as DateTime?,
            assigneeIds: assigneeIds?.cast<String>() ?? [widget.user.id],
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

  /// 手動リフレッシュ
  Future<void> _refreshData() async {
    try {
      await _cacheService.refreshCache();
    } catch (e) {
      debugPrint('[GroupDetailScreen] ❌ データ更新エラー: $e');
      _showErrorSnackBar('データの更新に失敗しました');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
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
                          backgroundImage: member.signedAvatarUrl != null
                              ? NetworkImage(member.signedAvatarUrl!)
                              : null,
                          child: member.signedAvatarUrl == null
                              ? Text(
                                  member.displayName.isNotEmpty
                                      ? member.displayName[0]
                                      : 'U',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    );
                  },
                ),
                // 5人以上いる場合は「+N」表示
                if (_groupMembers.length > 5)
                  InkWell(
                    onTap: () => _showGroupMembers(initialTab: 0),
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
                  onPressed: () => _showGroupMembers(initialTab: 1),
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
                // タブ1: タスクエリア
                RefreshIndicator(
                  onRefresh: _refreshData,
                  child: ListView(
                    padding: const EdgeInsets.only(top: 12),
                    children: [
                      // タスク見出し
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
                      // タスクフィルター（均等配置）
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
                      // タスクリスト
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
                      // 定期タスク一覧
                      if (_isLoadingRecurringTodos)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (_recurringTodos.isEmpty)
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
                                ).colorScheme.shadow.withValues(alpha: 0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            '定期タスクがありません',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        )
                      else
                        ..._recurringTodos.map(
                          (recurringTodo) => Dismissible(
                            key: Key(recurringTodo.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.error,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.delete,
                                color: Theme.of(context).colorScheme.onError,
                              ),
                            ),
                            confirmDismiss: (direction) async {
                              return await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('削除確認'),
                                  content: Text(
                                    '「${recurringTodo.title}」を削除しますか？',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(false),
                                      child: const Text('キャンセル'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(true),
                                      child: Text(
                                        '削除',
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.error,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                            onDismissed: (direction) =>
                                _deleteRecurringTodo(recurringTodo),
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(context).colorScheme.shadow
                                        .withValues(alpha: 0.08),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: InkWell(
                                onTap: () =>
                                    _showEditRecurringTodoDialog(recurringTodo),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              recurringTodo.title,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyLarge
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _formatRecurrencePattern(
                                                recurringTodo,
                                              ),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // ON/OFFスイッチ
                                      Switch(
                                        value: recurringTodo.isActive,
                                        onChanged: (_) =>
                                            _toggleRecurringTodoActive(
                                              recurringTodo,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
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
              heroTag: 'group_detail_fab_todo',
              onPressed: _showCreateTodoDialog,
              tooltip: 'TODO追加',
              child: const Icon(Icons.add_task),
            )
          : FloatingActionButton(
              heroTag: 'group_detail_fab_recurring',
              onPressed: _showCreateRecurringTodoDialog,
              tooltip: '定期TODO追加',
              child: const Icon(Icons.repeat),
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

/// タスクリストタイル
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
              color: Theme.of(
                context,
              ).colorScheme.shadow.withValues(alpha: 0.08),
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
                    // タスク内容
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
