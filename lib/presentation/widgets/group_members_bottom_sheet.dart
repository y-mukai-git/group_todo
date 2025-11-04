import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../../data/models/user_model.dart';
import '../../services/group_service.dart';

/// グループメンバー一覧ボトムシート
class GroupMembersBottomSheet extends StatefulWidget {
  final String groupId; // グループID
  final List<UserModel> members;
  final String currentUserId;
  final String groupOwnerId; // グループオーナーID
  final Function(String userId) onRemoveMember;
  final VoidCallback? onMembersUpdated; // メンバー更新通知
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

  @override
  void initState() {
    super.initState();
    _members = widget.members;
    _currentTabIndex = widget.initialTab; // 初期タブを設定
  }

  @override
  void didUpdateWidget(GroupMembersBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 親から渡されるmembersが更新されたら反映
    if (widget.members != oldWidget.members) {
      setState(() {
        _members = widget.members;
      });
    }
  }

  @override
  void dispose() {
    _userIdController.dispose();
    super.dispose();
  }

  /// メンバー削除確認ダイアログ
  Future<void> _showRemoveConfirmDialog(UserModel member) async {
    final confirmed = await showDialog<bool>(
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

    if (confirmed == true) {
      widget.onRemoveMember(member.id);
    }
  }

  /// ロール変更確認ダイアログ表示
  Future<void> _showChangeRoleDialog(UserModel member) async {
    final isCurrentlyOwner = member.id == widget.groupOwnerId;
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

  /// メンバーロール変更実行
  Future<void> _changeMemberRole(UserModel member, String newRole) async {
    try {
      await _groupService.changeMemberRole(
        groupId: widget.groupId,
        targetUserId: member.id,
        newRole: newRole,
        requesterId: widget.currentUserId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${member.displayName}のロールを変更しました'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );

      // メンバー更新通知
      widget.onMembersUpdated?.call();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ロール変更に失敗しました: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
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
                  backgroundImage: userInfo['icon_url'] != null
                      ? NetworkImage(userInfo['icon_url'])
                      : null,
                  child: userInfo['icon_url'] == null
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
        final isOwner = member.id == widget.groupOwnerId;

        return Card(
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
            title: Row(
              children: [
                Text(
                  member.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                if (isOwner) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.star, color: Colors.amber, size: 18),
                ],
              ],
            ),
            subtitle: InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: member.displayId));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('ユーザーIDをコピーしました'),
                    backgroundColor: Colors.green,
                  ),
                );
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
            trailing:
                (widget.currentUserId == widget.groupOwnerId && !isCurrentUser)
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ロール変更ボタン
                      IconButton(
                        icon: Icon(
                          Icons.swap_horiz,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        onPressed: () => _showChangeRoleDialog(member),
                        tooltip: 'ロール変更',
                      ),
                      // 削除ボタン
                      IconButton(
                        icon: Icon(
                          Icons.delete,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        onPressed: () => _showRemoveConfirmDialog(member),
                        tooltip: '削除',
                      ),
                    ],
                  )
                : null,
          ),
        );
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
            if (widget.currentUserId != widget.groupOwnerId) ...[
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
                  onPressed: _inviteUser,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('招待'),
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
    final displayId = _userIdController.text.trim();
    if (displayId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('ユーザーIDを入力してください'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    try {
      // 1. ユーザー情報取得・確認
      final response = await _groupService.validateUserForInvitation(
        groupId: widget.groupId,
        displayId: displayId,
        inviterId: widget.currentUserId,
      );

      if (!mounted) return;

      // 2. 確認ダイアログ表示
      final confirmed = await _showInviteConfirmDialog(
        response['user'],
        _selectedRole,
      );
      if (confirmed != true) return; // キャンセル

      // 3. 招待実行
      await _groupService.inviteUserToGroup(
        groupId: widget.groupId,
        inviterId: widget.currentUserId,
        invitedUserId: response['user']['id'],
        invitedRole: _selectedRole,
      );

      if (!mounted) return;

      _userIdController.clear();

      // 成功メッセージ
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('招待を送信しました'),
          backgroundColor: Colors.green,
        ),
      );

      // メンバー更新通知
      widget.onMembersUpdated?.call();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('招待に失敗しました: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
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
