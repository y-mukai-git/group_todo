import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../../data/models/user_model.dart';
import '../../services/group_service.dart';
import '../../services/error_log_service.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/utils/api_client.dart';
import '../../core/constants/error_messages.dart';
import '../widgets/error_dialog.dart';
import '../widgets/maintenance_dialog.dart';

/// グループメンバー一覧ボトムシート
class GroupMembersBottomSheet extends StatefulWidget {
  final String groupId; // グループID
  final List<UserModel> members;
  final String currentUserId;
  final String groupOwnerId; // グループオーナーID
  final Function(String userId) onRemoveMember;
  final Function(List<UserModel> members)? onMembersUpdated; // メンバー更新通知
  final int initialTab; // 初期表示タブ（0: メンバー一覧, 1: メンバー追加）

  const GroupMembersBottomSheet({
    super.key,
    required this.groupId,
    required this.members,
    required this.currentUserId,
    required this.groupOwnerId,
    required this.onRemoveMember,
    this.onMembersUpdated,
    this.initialTab = 0, // デフォルトはメンバー一覧
  });

  @override
  State<GroupMembersBottomSheet> createState() =>
      _GroupMembersBottomSheetState();
}

class _GroupMembersBottomSheetState extends State<GroupMembersBottomSheet> {
  final TextEditingController _userIdController = TextEditingController();
  final GroupService _groupService = GroupService();
  late List<UserModel> _members;
  String _selectedRole = 'member'; // デフォルト: メンバー
  late int _currentTabIndex; // 現在表示中のタブ（0: メンバー一覧, 1: メンバー追加）
  bool _isProcessing = false; // 連続タップ防止フラグ

  @override
  void initState() {
    super.initState();
    _members = _sortMembers(widget.members);
    _currentTabIndex = widget.initialTab; // 初期タブを設定
  }

  @override
  void didUpdateWidget(GroupMembersBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 親から渡されるmembersが更新されたら反映
    if (widget.members != oldWidget.members) {
      setState(() {
        _members = _sortMembers(widget.members);
      });
    }
  }

  @override
  void dispose() {
    _userIdController.dispose();
    super.dispose();
  }

  /// メンバーリストをソート
  /// 優先度: 1.管理者(オーナー) 2.オーナー 3.管理者(メンバー) 4.メンバー
  /// 同優先度内では加入日時(createdAt)の古い順
  List<UserModel> _sortMembers(List<UserModel> members) {
    return List.from(members)..sort((a, b) {
      // 優先度を取得する関数
      int getPriority(UserModel user) {
        final isGroupOwner = user.id == widget.groupOwnerId;
        final isOwnerRole = user.role == 'owner';

        if (isGroupOwner && isOwnerRole) return 1; // 管理者(オーナー)
        if (!isGroupOwner && isOwnerRole) return 2; // オーナー
        if (isGroupOwner && !isOwnerRole) return 3; // 管理者(メンバー)
        return 4; // メンバー
      }

      final priorityA = getPriority(a);
      final priorityB = getPriority(b);

      // 優先度で比較
      if (priorityA != priorityB) return priorityA.compareTo(priorityB);

      // 同優先度の場合は加入日時で比較（古い順）
      return a.createdAt.compareTo(b.createdAt);
    });
  }

  /// 現在のユーザーがオーナーかどうかを判定
  bool _isOwner() {
    // グループ作成者の場合
    if (widget.currentUserId == widget.groupOwnerId) {
      return true;
    }
    // roleが'owner'の場合
    final currentUser = _members.firstWhere(
      (m) => m.id == widget.currentUserId,
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
    return currentUser.role == 'owner';
  }

  /// ロール変更確認ダイアログ表示
  Future<void> _showChangeRoleDialog(UserModel member) async {
    final isCurrentlyOwner = member.role == 'owner';
    final newRole = isCurrentlyOwner ? 'member' : 'owner';
    final newRoleLabel = isCurrentlyOwner ? 'メンバー' : 'オーナー';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ロール変更'),
        content: Text('${member.displayName}のロールを「$newRoleLabel」に変更しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('変更'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _changeMemberRole(member, newRole);
    }
  }

  /// メンバーのロールを変更
  Future<void> _changeMemberRole(UserModel member, String newRole) async {
    if (_isProcessing) return; // 連続タップ防止

    setState(() {
      _isProcessing = true;
    });

    // API #19: change-member-role
    try {
      final updatedMembers = await _groupService.changeMemberRole(
        groupId: widget.groupId,
        targetUserId: member.id,
        newRole: newRole,
        requesterId: widget.currentUserId,
      );

      if (!mounted) return;

      SnackBarHelper.showSuccessSnackBar(
        context,
        '${member.displayName}のロールを変更しました',
      );

      // メンバー更新通知（更新後のメンバー一覧を渡す）
      widget.onMembersUpdated?.call(updatedMembers);
    } catch (e, stackTrace) {
      debugPrint('[GroupMembersBottomSheet] ❌ ロール変更エラー: $e');

      // メンテナンスモード対応
      if (e is MaintenanceException) {
        if (mounted) {
          await MaintenanceDialog.show(context: context, message: e.message);
        }
        return;
      }

      // システムエラー対応
      final errorLog = await ErrorLogService().logError(
        userId: widget.currentUserId,
        errorType: 'ロール変更エラー',
        errorMessage: ErrorMessages.memberRoleChangeFailed,
        stackTrace: '${e.toString()}\n${stackTrace.toString()}',
        screenName: 'グループメンバー一覧',
      );

      if (mounted) {
        await ErrorDialog.show(
          context: context,
          errorId: errorLog.id,
          errorMessage:
              '${ErrorMessages.memberRoleChangeFailed}\n${ErrorMessages.retryLater}',
        );
      }

      // データ更新系なのでリフレッシュ（現在のメンバーリストを渡す）
      widget.onMembersUpdated?.call(_members);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  /// ロール選択ピッカー表示
  void _showRolePicker() {
    final roles = ['member', 'owner'];
    final labels = ['メンバー', 'オーナー'];
    final currentIndex = roles.indexOf(_selectedRole);

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 250,
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('キャンセル'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('完了'),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 40,
                  scrollController: FixedExtentScrollController(
                    initialItem: currentIndex >= 0 ? currentIndex : 0,
                  ),
                  onSelectedItemChanged: (index) {
                    setState(() {
                      _selectedRole = roles[index];
                    });
                  },
                  children: labels
                      .map((label) => Center(child: Text(label)))
                      .toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// ユーザー招待確認ダイアログ
  Future<bool?> _showInviteConfirmDialog(
    Map<String, dynamic> userInfo,
    String role,
  ) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('招待確認'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('以下のユーザーを招待しますか？'),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: userInfo['avatar_url'] != null
                      ? NetworkImage(userInfo['avatar_url'])
                      : null,
                  child: userInfo['avatar_url'] == null
                      ? Text(userInfo['display_name']?[0] ?? 'U')
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userInfo['display_name'] ?? '不明',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text('ID: ${userInfo['display_id'] ?? '不明'}'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  role == 'owner' ? Icons.star : Icons.person,
                  size: 16,
                  color: role == 'owner' ? Colors.amber : null,
                ),
                const SizedBox(width: 4),
                Text(
                  'ロール: ${role == 'owner' ? 'オーナー' : 'メンバー'}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('招待する'),
          ),
        ],
      ),
    );
  }

  /// メンバー一覧タブの構築
  Widget _buildMembersList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _members.length,
      itemBuilder: (context, index) {
        final member = _members[index];
        final isCurrentUser = member.id == widget.currentUserId;
        final isOwner = member.role == 'owner';
        final isPending = member.isPending;

        // 現在のユーザーのroleを取得
        final currentUserRole = widget.members
            .firstWhere(
              (m) => m.id == widget.currentUserId,
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
            )
            .role;
        final isCurrentUserOwner =
            widget.currentUserId == widget.groupOwnerId ||
            currentUserRole == 'owner';
        final canModify = isCurrentUserOwner && !isCurrentUser && !isPending;

        final cardWidget = Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              backgroundImage: member.signedAvatarUrl != null
                  ? NetworkImage(member.signedAvatarUrl!)
                  : null,
              child: member.signedAvatarUrl == null
                  ? Text(
                      member.displayName.isNotEmpty
                          ? member.displayName[0]
                          : 'U',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  member.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                if (isOwner || isPending) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (isOwner) ...[
                        const Icon(Icons.star, color: Colors.amber, size: 18),
                        const SizedBox(width: 4),
                        const Text('オーナー', style: TextStyle(fontSize: 12)),
                      ],
                      if (isPending) ...[
                        if (isOwner) const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '承諾待ち',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
            subtitle: InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: member.displayId));
                SnackBarHelper.showSuccessSnackBar(context, 'ユーザーIDをコピーしました');
              },
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('ID: ${member.displayId}'),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.copy,
                      size: 14,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
            trailing: canModify
                ? IconButton(
                    icon: Icon(
                      Icons.swap_horiz,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    onPressed: () => _showChangeRoleDialog(member),
                    tooltip: 'ロール変更',
                  )
                : null,
          ),
        );

        // オーナーかつ自分自身でない場合のみスワイプ削除可能
        if (canModify) {
          return Dismissible(
            key: Key(member.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              margin: const EdgeInsets.only(bottom: 8),
              color: Theme.of(context).colorScheme.error,
              child: Icon(
                Icons.delete,
                color: Theme.of(context).colorScheme.onError,
              ),
            ),
            confirmDismiss: (direction) async {
              return await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('メンバー削除'),
                  content: Text('${member.displayName}をグループから削除しますか？'),
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
            },
            onDismissed: (direction) {
              widget.onRemoveMember(member.id);
            },
            child: cardWidget,
          );
        } else {
          return cardWidget;
        }
      },
    );
  }

  /// メンバー追加タブの構築
  Widget _buildInviteUI() {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ユーザーID',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            // 非オーナー時のメッセージ
            if (!_isOwner()) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'オーナーのみがユーザー招待できます',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // オーナー時の招待UI
              // ユーザーID入力（8桁制限）
              TextField(
                controller: _userIdController,
                maxLength: 8,
                decoration: InputDecoration(
                  labelText: 'ユーザーID',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  counterText: '', // 文字数カウンター非表示
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // ロール選択見出し
              Text(
                '権限',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              // ロール選択
              InkWell(
                onTap: _showRolePicker,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.admin_panel_settings,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedRole == 'owner' ? 'オーナー' : 'メンバー',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                      Icon(
                        Icons.arrow_drop_down,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // 招待ボタン
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isProcessing ? null : _inviteUser,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text('招待'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// ユーザー招待実行
  Future<void> _inviteUser() async {
    if (_isProcessing) return; // 連続タップ防止

    final displayId = _userIdController.text.trim();
    if (displayId.isEmpty) {
      if (!mounted) return;
      SnackBarHelper.showErrorSnackBar(context, 'ユーザーIDを入力してください');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    // API #20: validate-user-for-invitation
    Map<String, dynamic> validateResponse;
    try {
      // 1. ユーザー情報取得・確認
      validateResponse = await _groupService.validateUserForInvitation(
        groupId: widget.groupId,
        displayId: displayId,
        userId: widget.currentUserId,
      );

      if (!mounted) return;

      // successチェック（ビジネスエラー）
      if (validateResponse['success'] != true) {
        final errorMessage = _getErrorMessage(validateResponse['error']);
        if (!mounted) return;
        SnackBarHelper.showErrorSnackBar(context, errorMessage);
        return;
      }
    } catch (e, stackTrace) {
      debugPrint('[GroupMembersBottomSheet] ❌ ユーザー検証エラー: $e');

      // メンテナンスモード対応
      if (e is MaintenanceException) {
        if (mounted) {
          await MaintenanceDialog.show(context: context, message: e.message);
        }
        return;
      }

      // ApiExceptionの場合、ステータスコードで判定
      if (e is ApiException) {
        if (e.statusCode == 200) {
          // ビジネスエラー（200 + success:false）→ SnackBar
          final errorMessage = _getErrorMessage(e.message);
          if (mounted) {
            SnackBarHelper.showErrorSnackBar(context, errorMessage);
          }
        } else {
          // システムエラー（400/500）→ ErrorDialog + ログ
          final errorLog = await ErrorLogService().logError(
            userId: widget.currentUserId,
            errorType: 'ユーザー検証エラー',
            errorMessage: ErrorMessages.userValidationFailed,
            stackTrace: '${e.toString()}\n${stackTrace.toString()}',
            screenName: 'グループメンバー一覧',
          );
          if (mounted) {
            await ErrorDialog.show(
              context: context,
              errorId: errorLog.id,
              errorMessage:
                  '${ErrorMessages.userValidationFailed}\n${ErrorMessages.retryLater}',
            );
          }
        }
      } else {
        // その他のシステムエラー
        final errorLog = await ErrorLogService().logError(
          userId: widget.currentUserId,
          errorType: 'ユーザー検証エラー',
          errorMessage: ErrorMessages.userValidationFailed,
          stackTrace: '${e.toString()}\n${stackTrace.toString()}',
          screenName: 'グループメンバー一覧',
        );
        if (mounted) {
          await ErrorDialog.show(
            context: context,
            errorId: errorLog.id,
            errorMessage:
                '${ErrorMessages.userValidationFailed}\n${ErrorMessages.retryLater}',
          );
        }
      }
      return;
    }

    // 2. 確認ダイアログ表示
    final confirmed = await _showInviteConfirmDialog(
      validateResponse['user'],
      _selectedRole,
    );
    if (confirmed != true) {
      // キャンセル時は_isProcessingをリセット
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
      return;
    }

    // API #21: invite-user-to-group
    try {
      // 3. 招待実行
      await _groupService.inviteUserToGroup(
        groupId: widget.groupId,
        inviterId: widget.currentUserId,
        invitedUserId: validateResponse['user']['id'],
        invitedRole: _selectedRole,
      );

      if (!mounted) return;

      _userIdController.clear();

      // 成功メッセージ
      SnackBarHelper.showSuccessSnackBar(context, '招待を送信しました');

      // 招待はメンバー追加ではないため、メンバー更新通知は不要
    } catch (e, stackTrace) {
      debugPrint('[GroupMembersBottomSheet] ❌ 招待エラー: $e');

      // メンテナンスモード対応
      if (e is MaintenanceException) {
        if (mounted) {
          await MaintenanceDialog.show(context: context, message: e.message);
        }
        return;
      }

      // ApiExceptionの場合、ステータスコードで判定
      if (e is ApiException) {
        if (e.statusCode == 200) {
          // ビジネスエラー（200 + success:false）→ SnackBar
          final errorMessage = _getErrorMessage(e.message);
          if (mounted) {
            SnackBarHelper.showErrorSnackBar(context, errorMessage);
          }
        } else {
          // システムエラー（400/500）→ ErrorDialog + ログ
          final errorLog = await ErrorLogService().logError(
            userId: widget.currentUserId,
            errorType: '招待エラー',
            errorMessage: ErrorMessages.invitationFailed,
            stackTrace: '${e.toString()}\n${stackTrace.toString()}',
            screenName: 'グループメンバー一覧',
          );
          if (mounted) {
            await ErrorDialog.show(
              context: context,
              errorId: errorLog.id,
              errorMessage:
                  '${ErrorMessages.invitationFailed}\n${ErrorMessages.retryLater}',
            );
          }
        }
      } else {
        // システムエラーの場合、エラーダイアログを表示
        final errorLog = await ErrorLogService().logError(
          userId: widget.currentUserId,
          errorType: '招待エラー',
          errorMessage: ErrorMessages.invitationFailed,
          stackTrace: '${e.toString()}\n${stackTrace.toString()}',
          screenName: 'グループメンバー一覧',
        );
        if (mounted) {
          await ErrorDialog.show(
            context: context,
            errorId: errorLog.id,
            errorMessage:
                '${ErrorMessages.invitationFailed}\n${ErrorMessages.retryLater}',
          );
        }
      }

      // 招待はメンバー追加ではないため、リフレッシュ不要
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  /// エラーメッセージを取得
  String _getErrorMessage(String? error) {
    if (error == null) return '招待に失敗しました';

    switch (error) {
      case 'User not found':
        return '指定されたユーザーIDが見つかりません';
      case 'User is already a member of this group':
        return 'このユーザーは既にメンバーです';
      case 'User is already invited to this group':
        return 'このユーザーは既に招待済みです';
      case 'Only group owner can invite members':
        return 'オーナーのみが招待できます';
      case 'Inviter is not a member of this group':
        return '招待者がグループのメンバーではありません';
      case 'メンバーでないため操作できません':
        return 'メンバーでないため操作できません';
      default:
        // 未知のビジネスエラーはそのまま表示
        return error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTap: () {
            // キーボードを閉じる
            FocusScope.of(context).unfocus();
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                // ヘッダー
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.group,
                        color: Theme.of(context).colorScheme.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'グループメンバー',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          if (!mounted) return;
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // タブ選択
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _currentTabIndex = 0;
                              });
                            },
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
                                    Icons.group,
                                    size: 20,
                                    color: _currentTabIndex == 0
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.onPrimary
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'メンバー一覧',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
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
                            onTap: () {
                              setState(() {
                                _currentTabIndex = 1;
                              });
                            },
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
                                    Icons.person_add,
                                    size: 20,
                                    color: _currentTabIndex == 1
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.onPrimary
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'メンバー追加',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
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
                  child: _currentTabIndex == 0
                      ? _buildMembersList()
                      : _buildInviteUI(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
