import 'package:flutter/material.dart';
import '../../data/models/user_model.dart';

/// グループメンバー一覧ボトムシート
class GroupMembersBottomSheet extends StatefulWidget {
  final List<UserModel> members;
  final String currentUserId;
  final String groupOwnerId; // グループオーナーID
  final Function(String userId) onRemoveMember;
  final Function(String userId) onInviteMember;
  final VoidCallback? onMembersUpdated; // メンバー更新通知

  const GroupMembersBottomSheet({
    super.key,
    required this.members,
    required this.currentUserId,
    required this.groupOwnerId,
    required this.onRemoveMember,
    required this.onInviteMember,
    this.onMembersUpdated,
  });

  @override
  State<GroupMembersBottomSheet> createState() =>
      _GroupMembersBottomSheetState();
}

class _GroupMembersBottomSheetState extends State<GroupMembersBottomSheet> {
  final TextEditingController _userIdController = TextEditingController();
  late List<UserModel> _members;

  @override
  void initState() {
    super.initState();
    _members = widget.members;
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

  /// ユーザー招待実行
  void _inviteUser() {
    final userId = _userIdController.text.trim();
    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('ユーザーIDを入力してください'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    widget.onInviteMember(userId);
    _userIdController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTap: () {},
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

                // メンバー一覧
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _members.length,
                    itemBuilder: (context, index) {
                      final member = _members[index];
                      final isCurrentUser = member.id == widget.currentUserId;
                      final isOwner = member.id == widget.groupOwnerId;
                      final canDelete =
                          widget.currentUserId == widget.groupOwnerId &&
                          !isCurrentUser;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
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
                          title: Row(
                            children: [
                              Text(
                                member.displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (isOwner) ...[
                                const SizedBox(width: 8),
                                Icon(Icons.star, color: Colors.amber, size: 18),
                              ],
                            ],
                          ),
                          subtitle: Text('ID: ${member.displayId}'),
                          trailing: canDelete
                              ? IconButton(
                                  icon: Icon(
                                    Icons.delete,
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                  onPressed: () =>
                                      _showRemoveConfirmDialog(member),
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                ),

                const Divider(height: 1),

                // ユーザー招待UI
                SingleChildScrollView(
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
                          'ユーザーを招待',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        // 非オーナー時のメッセージ
                        if (widget.currentUserId != widget.groupOwnerId) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'オーナーのみがユーザー招待できます',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          // オーナー時の招待UI
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _userIdController,
                                  decoration: InputDecoration(
                                    labelText: 'ユーザーID',
                                    hintText: 'ユーザーIDを入力',
                                    prefixIcon: const Icon(Icons.person_add),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              FilledButton(
                                onPressed: _inviteUser,
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                                child: const Text('招待'),
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
      },
    );
  }
}
