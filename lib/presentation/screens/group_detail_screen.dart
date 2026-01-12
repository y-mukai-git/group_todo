import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import '../../data/models/user_model.dart';
import '../../data/models/group_model.dart';
import '../../data/models/todo_model.dart';
import '../../data/models/recurring_todo_model.dart';
import '../../data/models/quick_action_model.dart';
import '../../services/creation_limit_service.dart';
import '../../services/data_cache_service.dart';
import '../../services/group_service.dart';
import '../../services/rewarded_ad_service.dart';
import '../../services/error_log_service.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/utils/api_client.dart';
import '../../core/constants/error_messages.dart';
import '../widgets/ad_required_dialog.dart';
import '../widgets/create_todo_bottom_sheet.dart';
import '../widgets/edit_group_bottom_sheet.dart';
import '../widgets/group_members_bottom_sheet.dart';
import '../widgets/create_recurring_todo_bottom_sheet.dart';
import '../widgets/create_quick_action_bottom_sheet.dart';
import '../widgets/quick_action_list_bottom_sheet.dart';
import '../widgets/error_dialog.dart';
import '../widgets/maintenance_dialog.dart';

/// グループ詳細画面
class GroupDetailScreen extends StatefulWidget {
  final UserModel user;
  final GroupModel group;

  const GroupDetailScreen({super.key, required this.user, required this.group});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final DataCacheService _cacheService = DataCacheService();
  final CreationLimitService _limitService = CreationLimitService();
  final RewardedAdService _rewardedAdService = RewardedAdService();
  List<TodoModel> _todos = [];
  late GroupModel _currentGroup;
  String _selectedFilter =
      'incomplete'; // 'incomplete', 'completed', 'my_incomplete'
  int _selectedViewIndex = 0; // 0: TODO, 1: 定期TODO, 2: クイックアクション
  List<UserModel> _groupMembers = []; // グループメンバーリスト
  List<RecurringTodoModel> _recurringTodos = []; // 定期TODOリスト
  List<QuickActionModel> _quickActions = []; // クイックアクションリスト
  final Set<String> _updatingTodoIds = {}; // 更新中のTODO IDを追跡
  final Set<String> _togglingRecurringTodoIds = {}; // 切り替え中の定期TODO IDを追跡

  @override
  void initState() {
    super.initState();
    _currentGroup = widget.group;
    // キャッシュリスナー登録
    _cacheService.addListener(_updateGroupData);
    // 初回データ取得
    _updateGroupData();
    // リワード広告の事前読み込み
    _rewardedAdService.loadAd();
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
                groupOwnerId: _currentGroup.ownerId,
                onRemoveMember: _removeMember,
                onMembersUpdated: (updatedMembers) {
                  // API #19から返されたメンバー一覧でローカルデータを更新
                  setState(() {
                    _groupMembers = updatedMembers;
                  });
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

      // メンテナンス時は MaintenanceDialog を表示
      if (e is MaintenanceException) {
        if (!mounted) return;
        await MaintenanceDialog.show(context: context, message: e.message);
        return;
      }

      // システムエラー時は ErrorDialog を表示
      final errorLog = await ErrorLogService().logError(
        userId: widget.user.id,
        errorType: 'メンバー削除エラー',
        errorMessage: ErrorMessages.memberRemoveFailed,
        stackTrace: '${e.toString()}\n${stackTrace.toString()}',
        screenName: 'グループ詳細画面',
      );
      if (mounted) {
        await ErrorDialog.show(
          context: context,
          errorId: errorLog.id,
          errorMessage:
              '${ErrorMessages.memberRemoveFailed}\n${ErrorMessages.retryLater}',
        );
        // エラー後にデータをリフレッシュ（データ更新系）
        await _cacheService.refreshCache();
      }
    }
  }

  /// グループ脱退
  Future<void> _leaveGroup() async {
    try {
      // メンバー数をカウント
      final memberCount = _groupMembers.length;

      // メンバーが1人しかいない場合（自分だけ）は脱退不可
      if (memberCount == 1) {
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('グループを脱退できません'),
            content: const Text('グループにメンバーが1人しかいないため脱退できません。グループを削除してください。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      // オーナー数をカウント
      final ownerCount = _groupMembers
          .where((member) => member.role == 'owner')
          .length;

      // 現在のユーザーがオーナーか確認
      final currentUserMember = _groupMembers.firstWhere(
        (member) => member.id == widget.user.id,
        orElse: () => UserModel(
          id: '',
          deviceId: '',
          displayName: '',
          displayId: '',
          notificationDeadline: false,
          notificationNewTodo: false,
          notificationAssigned: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      final isCurrentUserOwner = currentUserMember.role == 'owner';

      // オーナーが1人しかいない場合はエラー
      if (isCurrentUserOwner && ownerCount == 1) {
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('グループを脱退できません'),
            content: const Text(
              'グループにはオーナーが1人以上必要です。他のメンバーをオーナーに昇格させてから脱退してください。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      // 確認ダイアログ
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('グループを脱退'),
          content: Text('「${_currentGroup.name}」から脱退しますか？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('脱退する'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // API呼び出し：グループ脱退（自分自身を削除）
      await GroupService().removeGroupMember(
        groupId: widget.group.id,
        userId: widget.user.id,
        targetUserId: widget.user.id,
      );

      if (!mounted) return;
      // グループ詳細画面を閉じてグループ一覧に戻る
      Navigator.pop(context);
      _showSuccessSnackBar('グループから脱退しました');
    } catch (e, stackTrace) {
      debugPrint('[GroupDetailScreen] ❌ グループ脱退エラー: $e');

      // メンテナンス時は MaintenanceDialog を表示
      if (e is MaintenanceException) {
        if (!mounted) return;
        await MaintenanceDialog.show(context: context, message: e.message);
        return;
      }

      // システムエラー時は ErrorDialog を表示
      final errorLog = await ErrorLogService().logError(
        userId: widget.user.id,
        errorType: 'グループ脱退エラー',
        errorMessage: ErrorMessages.groupLeaveFailed,
        stackTrace: '${e.toString()}\n${stackTrace.toString()}',
        screenName: 'グループ詳細画面',
      );
      if (mounted) {
        await ErrorDialog.show(
          context: context,
          errorId: errorLog.id,
          errorMessage:
              '${ErrorMessages.groupLeaveFailed}\n${ErrorMessages.retryLater}',
        );
        // エラー後にデータをリフレッシュ（データ更新系）
        await _cacheService.refreshCache();
      }
    }
  }

  /// 定期タスク作成ボトムシート表示
  Future<void> _showCreateRecurringTodoDialog() async {
    // 作成上限チェック
    final canCreate = await AdRequiredDialog.checkAndShowForRecurringTodo(
      context,
      widget.group.id,
    );
    if (!canCreate || !mounted) {
      return; // キャンセルまたは広告視聴失敗
    }

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
      // 作成成功時、一時権限を消費
      _limitService.consumeTemporaryRecurringTodoPermission(widget.group.id);
    }
  }

  /// 定期TODO編集ボトムシート表示
  Future<void> _showEditRecurringTodoDialog(
    RecurringTodoModel recurringTodo,
  ) async {
    await showModalBottomSheet<bool>(
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

    // キャッシュサービスがnotifyListeners()を呼ぶので自動的に更新される
  }

  /// 定期タスク削除
  Future<void> _deleteRecurringTodo(RecurringTodoModel recurringTodo) async {
    try {
      await _cacheService.deleteRecurringTodo(
        userId: widget.user.id,
        groupId: widget.group.id,
        recurringTodoId: recurringTodo.id,
      );

      if (mounted) {
        _showSuccessSnackBar('定期TODOを削除しました');
      }
    } catch (e, stackTrace) {
      debugPrint('[GroupDetailScreen] ❌ 定期タスク削除エラー: $e');

      // メンテナンス時は MaintenanceDialog を表示
      if (e is MaintenanceException) {
        if (!mounted) return;
        await MaintenanceDialog.show(context: context, message: e.message);
        return;
      }

      // システムエラー時は ErrorDialog を表示
      final errorLog = await ErrorLogService().logError(
        userId: widget.user.id,
        errorType: '定期タスク削除エラー',
        errorMessage: ErrorMessages.recurringTodoDeleteFailed,
        stackTrace: '${e.toString()}\n${stackTrace.toString()}',
        screenName: 'グループ詳細画面',
      );
      if (mounted) {
        await ErrorDialog.show(
          context: context,
          errorId: errorLog.id,
          errorMessage:
              '${ErrorMessages.recurringTodoDeleteFailed}\n${ErrorMessages.retryLater}',
        );
        // エラー後にデータをリフレッシュ（データ更新系）
        await _cacheService.refreshCache();
      }
    }
  }

  /// クイックアクション作成ボトムシート表示
  Future<void> _showCreateQuickActionDialog() async {
    // 作成上限チェック
    final canCreate = await AdRequiredDialog.checkAndShowForQuickAction(
      context,
      widget.group.id,
    );
    if (!canCreate || !mounted) {
      return; // キャンセルまたは広告視聴失敗
    }

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: true,
      useRootNavigator: false,
      builder: (context) {
        final mediaQuery = MediaQuery.of(context);
        final contentHeight =
            mediaQuery.size.height -
            mediaQuery.padding.top -
            mediaQuery.padding.bottom;

        return Container(
          height: contentHeight * 0.8,
          margin: EdgeInsets.only(top: contentHeight * 0.2),
          child: CreateQuickActionBottomSheet(
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

    // キャッシュサービスがnotifyListeners()を呼ぶので自動的に更新される
    // 作成成功時、一時権限を消費
    if (result == true) {
      _limitService.consumeTemporaryQuickActionPermission(widget.group.id);
    }
  }

  /// クイックアクション編集ボトムシート表示
  Future<void> _showEditQuickActionDialog(QuickActionModel quickAction) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: true,
      useRootNavigator: false,
      builder: (context) {
        final mediaQuery = MediaQuery.of(context);
        final contentHeight =
            mediaQuery.size.height -
            mediaQuery.padding.top -
            mediaQuery.padding.bottom;

        return Container(
          height: contentHeight * 0.8,
          margin: EdgeInsets.only(top: contentHeight * 0.2),
          child: CreateQuickActionBottomSheet(
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
            existingQuickAction: quickAction,
          ),
        );
      },
    );

    // キャッシュサービスがnotifyListeners()を呼ぶので自動的に更新される
  }

  /// クイックアクション削除
  Future<void> _deleteQuickAction(QuickActionModel quickAction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除確認'),
        content: Text('セットTODO「${quickAction.name}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _cacheService.deleteQuickAction(
        userId: widget.user.id,
        groupId: widget.group.id,
        quickActionId: quickAction.id,
      );

      if (mounted) {
        _showSuccessSnackBar('セットTODOを削除しました');
      }
    } catch (e, stackTrace) {
      debugPrint('[GroupDetailScreen] ❌ クイックアクション削除エラー: $e');

      // メンテナンス時は MaintenanceDialog を表示
      if (e is MaintenanceException) {
        if (!mounted) return;
        await MaintenanceDialog.show(context: context, message: e.message);
        return;
      }

      // システムエラー時は ErrorDialog を表示
      final errorLog = await ErrorLogService().logError(
        userId: widget.user.id,
        errorType: 'クイックアクション削除エラー',
        errorMessage: ErrorMessages.quickActionDeleteFailed,
        stackTrace: '${e.toString()}\n${stackTrace.toString()}',
        screenName: 'グループ詳細画面',
      );
      if (mounted) {
        await ErrorDialog.show(
          context: context,
          errorId: errorLog.id,
          errorMessage:
              '${ErrorMessages.quickActionDeleteFailed}\n${ErrorMessages.retryLater}',
        );
        // エラー後にデータをリフレッシュ（データ更新系）
        await _cacheService.refreshCache();
      }
    }
  }

  /// 定期TODO ON/OFF切り替え
  Future<void> _toggleRecurringTodoActive(
    RecurringTodoModel recurringTodo,
  ) async {
    // 連打防止
    if (_togglingRecurringTodoIds.contains(recurringTodo.id)) return;

    setState(() {
      _togglingRecurringTodoIds.add(recurringTodo.id);
    });

    try {
      await _cacheService.toggleRecurringTodoActive(
        userId: widget.user.id,
        groupId: widget.group.id,
        recurringTodoId: recurringTodo.id,
      );

      if (mounted) {
        final message = recurringTodo.isActive
            ? '定期TODOを無効にしました'
            : '定期TODOを有効にしました';
        // 既存のスナックバーをクリアしてから表示（連続操作時のズレ防止）
        SnackBarHelper.showSuccessSnackBar(
          context,
          message,
          clearPrevious: true,
        );
        setState(() {
          _togglingRecurringTodoIds.remove(recurringTodo.id);
        });
      }
    } catch (e, stackTrace) {
      debugPrint('[GroupDetailScreen] ❌ 定期TODO切り替えエラー: $e');

      if (mounted) {
        setState(() {
          _togglingRecurringTodoIds.remove(recurringTodo.id);
        });
      }

      // メンテナンス時は MaintenanceDialog を表示
      if (e is MaintenanceException) {
        if (!mounted) return;
        await MaintenanceDialog.show(context: context, message: e.message);
        return;
      }

      // システムエラー時は ErrorDialog を表示
      final errorLog = await ErrorLogService().logError(
        userId: widget.user.id,
        errorType: '定期TODO切り替えエラー',
        errorMessage: ErrorMessages.recurringTodoToggleFailed,
        stackTrace: '${e.toString()}\n${stackTrace.toString()}',
        screenName: 'グループ詳細画面',
      );
      if (mounted) {
        await ErrorDialog.show(
          context: context,
          errorId: errorLog.id,
          errorMessage:
              '${ErrorMessages.recurringTodoToggleFailed}\n${ErrorMessages.retryLater}',
        );
        // エラー後にデータをリフレッシュ（データ更新系）
        await _cacheService.refreshCache();
      }
    }
  }

  @override
  void dispose() {
    // リスナー解除
    _cacheService.removeListener(_updateGroupData);
    super.dispose();
  }

  /// キャッシュからグループデータ取得
  Future<void> _updateGroupData() async {
    // キャッシュからグループ情報取得
    final group = _cacheService.getGroupById(widget.group.id);
    if (group == null) {
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

    // キャッシュから定期TODO取得
    final recurringTodos = _cacheService.getRecurringTodosByGroupId(
      widget.group.id,
    );

    // キャッシュからクイックアクション取得
    final quickActions = _cacheService.getQuickActionsByGroupId(
      widget.group.id,
    );

    if (mounted) {
      setState(() {
        if (group != null) {
          _currentGroup = group;
        }
        _todos = todos;
        _groupMembers = members;
        _recurringTodos = recurringTodos;
        _quickActions = quickActions;
      });
    }
  }

  /// タスク完了状態切り替え（キャッシュサービス経由）
  Future<void> _toggleTodoCompletion(TodoModel todo) async {
    // 連続タップ防止
    if (_updatingTodoIds.contains(todo.id)) return;

    // ローディング状態を開始
    setState(() {
      _updatingTodoIds.add(todo.id);
    });

    try {
      final wasCompleted = todo.isCompleted;

      // DataCacheService経由でDB更新+キャッシュ更新
      await _cacheService.toggleTodoCompletion(
        userId: widget.user.id,
        todoId: todo.id,
      );

      // ローディング状態を終了
      if (mounted) {
        setState(() {
          _updatingTodoIds.remove(todo.id);
        });
      }

      // 成功メッセージを表示
      if (mounted) {
        if (wasCompleted) {
          _showSuccessSnackBar('タスクを未完了に戻しました');
        } else {
          _showSuccessSnackBar('タスクを完了しました');
        }
      }
    } catch (e, stackTrace) {
      debugPrint('[GroupDetailScreen] ❌ タスク完了切り替えエラー: $e');

      // ローディング状態を終了
      if (mounted) {
        setState(() {
          _updatingTodoIds.remove(todo.id);
        });
      }

      // メンテナンス時は MaintenanceDialog を表示
      if (e is MaintenanceException) {
        if (!mounted) return;
        await MaintenanceDialog.show(context: context, message: e.message);
        return;
      }

      // システムエラー時は ErrorDialog を表示
      final errorLog = await ErrorLogService().logError(
        userId: widget.user.id,
        errorType: 'タスク完了切り替えエラー',
        errorMessage: ErrorMessages.todoCompletionToggleFailed,
        stackTrace: '${e.toString()}\n${stackTrace.toString()}',
        screenName: 'グループ詳細画面',
      );
      if (mounted) {
        await ErrorDialog.show(
          context: context,
          errorId: errorLog.id,
          errorMessage:
              '${ErrorMessages.todoCompletionToggleFailed}\n${ErrorMessages.retryLater}',
        );
        // エラー後にデータをリフレッシュ（データ更新系）
        await _cacheService.refreshCache();
      }
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
        assignedUserIds: assigneeIds,
      );

      if (!mounted) return;
      _showSuccessSnackBar('TODOを作成しました');
    } catch (e, stackTrace) {
      debugPrint('[GroupDetailScreen] ❌ タスク作成エラー: $e');

      // メンテナンス時は MaintenanceDialog を表示
      if (e is MaintenanceException) {
        if (!mounted) return;
        await MaintenanceDialog.show(context: context, message: e.message);
        return;
      }

      // システムエラー時は ErrorDialog を表示
      final errorLog = await ErrorLogService().logError(
        userId: widget.user.id,
        errorType: 'タスク作成エラー',
        errorMessage: ErrorMessages.todoCreationFailed,
        stackTrace: '${e.toString()}\n${stackTrace.toString()}',
        screenName: 'グループ詳細画面',
      );
      if (mounted) {
        await ErrorDialog.show(
          context: context,
          errorId: errorLog.id,
          errorMessage:
              '${ErrorMessages.todoCreationFailed}\n${ErrorMessages.retryLater}',
        );
        await _cacheService.refreshCache();
      }
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
      _showSuccessSnackBar('TODOを更新しました');
    } catch (e, stackTrace) {
      debugPrint('[GroupDetailScreen] ❌ TODO更新エラー: $e');

      // メンテナンス時は MaintenanceDialog を表示
      if (e is MaintenanceException) {
        if (!mounted) return;
        await MaintenanceDialog.show(context: context, message: e.message);
        return;
      }

      // システムエラー時は ErrorDialog を表示
      final errorLog = await ErrorLogService().logError(
        userId: widget.user.id,
        errorType: 'TODO更新エラー',
        errorMessage: ErrorMessages.todoUpdateFailed,
        stackTrace: '${e.toString()}\n${stackTrace.toString()}',
        screenName: 'グループ詳細画面',
      );
      if (mounted) {
        await ErrorDialog.show(
          context: context,
          errorId: errorLog.id,
          errorMessage:
              '${ErrorMessages.todoUpdateFailed}\n${ErrorMessages.retryLater}',
        );
        await _cacheService.refreshCache();
      }
    }
  }

  /// 成功メッセージ表示
  void _showSuccessSnackBar(String message) {
    SnackBarHelper.showSuccessSnackBar(context, message);
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
    } catch (e, stackTrace) {
      debugPrint('[GroupDetailScreen] ❌ グループ更新エラー: $e');

      // メンテナンス時は MaintenanceDialog を表示
      if (e is MaintenanceException) {
        if (!mounted) return;
        await MaintenanceDialog.show(context: context, message: e.message);
        return;
      }

      // システムエラー時は ErrorDialog を表示
      final errorLog = await ErrorLogService().logError(
        userId: widget.user.id,
        errorType: 'グループ更新エラー',
        errorMessage: ErrorMessages.groupUpdateFailed,
        stackTrace: '${e.toString()}\n${stackTrace.toString()}',
        screenName: 'グループ詳細画面',
      );
      if (mounted) {
        await ErrorDialog.show(
          context: context,
          errorId: errorLog.id,
          errorMessage:
              '${ErrorMessages.groupUpdateFailed}\n${ErrorMessages.retryLater}',
        );
        await _cacheService.refreshCache();
      }
    }
  }

  /// フィルター済みTODOリスト
  List<TodoModel> get _filteredTodos {
    switch (_selectedFilter) {
      case 'completed':
        // 過去30日以内に完了したタスクのみを表示
        final now = DateTime.now();
        final oneMonthAgo = now.subtract(const Duration(days: 30));
        return _todos
            .where(
              (todo) =>
                  todo.isCompleted &&
                  todo.completedAt != null &&
                  todo.completedAt!.isAfter(oneMonthAgo),
            )
            .toList();
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

      if (!mounted) return;
      _showSuccessSnackBar('TODOを削除しました');
    } catch (e, stackTrace) {
      debugPrint('[GroupDetailScreen] ❌ TODO削除エラー: $e');

      // メンテナンス時は MaintenanceDialog を表示
      if (e is MaintenanceException) {
        if (!mounted) return;
        await MaintenanceDialog.show(context: context, message: e.message);
        return;
      }

      // システムエラー時は ErrorDialog を表示
      final errorLog = await ErrorLogService().logError(
        userId: widget.user.id,
        errorType: 'TODO削除エラー',
        errorMessage: ErrorMessages.todoDeleteFailed,
        stackTrace: '${e.toString()}\n${stackTrace.toString()}',
        screenName: 'グループ詳細画面',
      );
      if (mounted) {
        await ErrorDialog.show(
          context: context,
          errorId: errorLog.id,
          errorMessage:
              '${ErrorMessages.todoDeleteFailed}\n${ErrorMessages.retryLater}',
        );
        await _cacheService.refreshCache();
      }
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

  /// FAB構築（タブに応じて切り替え）
  Widget _buildFloatingActionButton() {
    switch (_selectedViewIndex) {
      case 0:
        // TODOタブ: SpeedDial（複数選択肢）
        return SpeedDial(
          icon: Icons.add,
          activeIcon: Icons.close,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
          overlayColor: Colors.black,
          overlayOpacity: 0.4,
          spacing: 12,
          childPadding: const EdgeInsets.all(5),
          spaceBetweenChildren: 12,
          children: [
            SpeedDialChild(
              child: const Icon(Icons.add_task),
              label: 'TODO作成',
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
              onTap: _showCreateTodoDialog,
            ),
            SpeedDialChild(
              child: const Icon(Icons.flash_on),
              label: 'セットTODO',
              backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
              foregroundColor: Theme.of(
                context,
              ).colorScheme.onTertiaryContainer,
              onTap: () async {
                final result = await showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  enableDrag: true,
                  isDismissible: true,
                  useRootNavigator: false,
                  builder: (context) {
                    final mediaQuery = MediaQuery.of(context);
                    final contentHeight =
                        mediaQuery.size.height -
                        mediaQuery.padding.top -
                        mediaQuery.padding.bottom;

                    return Container(
                      height: contentHeight * 0.8,
                      margin: EdgeInsets.only(top: contentHeight * 0.2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      child: QuickActionListBottomSheet(
                        fixedGroupId: widget.group.id,
                        userId: widget.user.id,
                      ),
                    );
                  },
                );

                // クイックアクション実行成功時にグループデータを更新
                if (result == true && mounted) {
                  await _updateGroupData();
                }
              },
            ),
          ],
        );
      case 1:
        // 定期TODOタブ: 通常のFAB
        return FloatingActionButton(
          onPressed: _showCreateRecurringTodoDialog,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
          child: const Icon(Icons.add),
        );
      case 2:
        // クイックアクションタブ: 通常のFAB
        return FloatingActionButton(
          onPressed: _showCreateQuickActionDialog,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
          child: const Icon(Icons.add),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  /// 手動リフレッシュ
  Future<void> _refreshData() async {
    try {
      await _cacheService.refreshCache();
    } catch (e, stackTrace) {
      debugPrint('[GroupDetailScreen] ❌ データ更新エラー: $e');

      // メンテナンス時は MaintenanceDialog を表示
      if (e is MaintenanceException) {
        if (!mounted) return;
        await MaintenanceDialog.show(context: context, message: e.message);
        return;
      }

      // システムエラー時は ErrorDialog を表示
      final errorLog = await ErrorLogService().logError(
        userId: widget.user.id,
        errorType: 'データ更新エラー',
        errorMessage: ErrorMessages.dataRefreshFailed,
        stackTrace: '${e.toString()}\n${stackTrace.toString()}',
        screenName: 'グループ詳細画面',
      );
      if (mounted) {
        await ErrorDialog.show(
          context: context,
          errorId: errorLog.id,
          errorMessage:
              '${ErrorMessages.dataRefreshFailed}\n${ErrorMessages.retryLater}',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(_currentGroup.name),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'グループメニュー',
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  _showEditGroupDialog();
                  break;
                case 'leave':
                  _leaveGroup();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(
                      Icons.edit,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    const SizedBox(width: 8),
                    const Text('グループ編集'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'leave',
                child: Row(
                  children: [
                    Icon(
                      Icons.exit_to_app,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    const SizedBox(width: 8),
                    const Text('グループを脱退'),
                  ],
                ),
              ),
            ],
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
          // 3つのボタン切り替え
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
                      onTap: () => setState(() => _selectedViewIndex = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedViewIndex == 0
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_box,
                              size: 20,
                              color: _selectedViewIndex == 0
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'TODO',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: _selectedViewIndex == 0
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
                      onTap: () => setState(() => _selectedViewIndex = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedViewIndex == 1
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.repeat,
                              size: 20,
                              color: _selectedViewIndex == 1
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '定期TODO',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: _selectedViewIndex == 1
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
                      onTap: () => setState(() => _selectedViewIndex = 2),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedViewIndex == 2
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.flash_on,
                              size: 20,
                              color: _selectedViewIndex == 2
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'セット\nTODO',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 10,
                                    height: 1.2,
                                    color: _selectedViewIndex == 2
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
          // 表示コンテンツ（選択されたインデックスに応じて切り替え）
          Expanded(
            child: _selectedViewIndex == 0
                ? // ビュー0: TODOエリア
                  Column(
                    children: [
                      // タスクフィルター（固定表示）
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
                      // タスクリスト（スクロール可能）
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _refreshData,
                          child: ListView(
                            padding: const EdgeInsets.only(top: 4),
                            children: [
                              // タスクリスト
                              ..._filteredTodos.map(
                                (todo) => _TodoListTile(
                                  todo: todo,
                                  user: widget.user,
                                  onToggle: () => _toggleTodoCompletion(todo),
                                  onTap: () => _showTodoDetail(todo),
                                  onDelete: () => _deleteTodo(todo),
                                  isUpdating: _updatingTodoIds.contains(
                                    todo.id,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 80),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : _selectedViewIndex == 1
                ? // ビュー1: 定期TODOエリア
                  RefreshIndicator(
                    onRefresh: _refreshData,
                    child: ListView(
                      padding: const EdgeInsets.only(top: 12),
                      children: [
                        // 定期タスク一覧
                        if (_recurringTodos.isEmpty)
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
                                      color: Theme.of(context)
                                          .colorScheme
                                          .shadow
                                          .withValues(alpha: 0.08),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: InkWell(
                                  onTap: () => _showEditRecurringTodoDialog(
                                    recurringTodo,
                                  ),
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
                                                      fontWeight:
                                                          FontWeight.w600,
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
                                        _togglingRecurringTodoIds.contains(
                                              recurringTodo.id,
                                            )
                                            ? const SizedBox(
                                                width: 48,
                                                height: 24,
                                                child: Center(
                                                  child: SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                  ),
                                                ),
                                              )
                                            : Switch(
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
                  )
                : // ビュー2: クイックアクションエリア
                  RefreshIndicator(
                    onRefresh: _refreshData,
                    child: ListView(
                      padding: const EdgeInsets.only(top: 12),
                      children: [
                        // クイックアクション一覧
                        if (_quickActions.isEmpty)
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
                              'セットTODOがありません',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          )
                        else
                          ..._quickActions.map(
                            (quickAction) => Dismissible(
                              key: Key(quickAction.id),
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
                                      '「${quickAction.name}」を削除しますか？',
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
                                  _deleteQuickAction(quickAction),
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
                                      color: Theme.of(context)
                                          .colorScheme
                                          .shadow
                                          .withValues(alpha: 0.08),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: InkWell(
                                  onTap: () =>
                                      _showEditQuickActionDialog(quickAction),
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
                                                quickAction.name,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyLarge
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                              ),
                                            ],
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
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
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
  final bool isUpdating;

  const _TodoListTile({
    required this.todo,
    required this.user,
    required this.onToggle,
    required this.onTap,
    required this.onDelete,
    required this.isUpdating,
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
                    // チェックボックスまたはローディングインジケーター
                    SizedBox(
                      width: 42,
                      height: 42,
                      child: isUpdating
                          ? const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : Transform.scale(
                              scale: 1.1,
                              child: Checkbox(
                                value: todo.isCompleted,
                                onChanged: (_) => onToggle(),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
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
