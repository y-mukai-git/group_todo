import 'package:flutter/material.dart';
import '../../data/models/user_model.dart';
import '../../data/models/group_model.dart';
import '../../services/group_service.dart';

/// グループ一覧画面
class GroupsScreen extends StatefulWidget {
  final UserModel user;

  const GroupsScreen({super.key, required this.user});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final GroupService _groupService = GroupService();
  List<GroupModel> _groups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  /// グループ一覧読み込み
  Future<void> _loadGroups() async {
    setState(() => _isLoading = true);

    try {
      final groups = await _groupService.getUserGroups(userId: widget.user.id);

      // 個人用グループを最上部に表示
      groups.sort((a, b) {
        if (a.name == '個人TODO') return -1;
        if (b.name == '個人TODO') return 1;
        return (a.createdAt ?? DateTime.now())
            .compareTo(b.createdAt ?? DateTime.now());
      });

      if (!mounted) return;
      setState(() {
        _groups = groups;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[GroupsScreen] ❌ グループ読み込みエラー: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showErrorSnackBar('グループの読み込みに失敗しました');
    }
  }

  /// グループ作成ダイアログ表示
  Future<void> _showCreateGroupDialog() async {
    final TextEditingController controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新しいグループを作成'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'グループ名',
            hintText: 'グループ名を入力',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              final groupName = controller.text.trim();
              if (groupName.isNotEmpty) {
                Navigator.pop(context);
                _createGroup(groupName);
              }
            },
            child: const Text('作成'),
          ),
        ],
      ),
    );

    controller.dispose();
  }

  /// グループ作成実行
  Future<void> _createGroup(String groupName) async {
    try {
      await _groupService.createGroup(
        userId: widget.user.id,
        groupName: groupName,
      );

      _showSuccessSnackBar('グループを作成しました');
      _loadGroups();
    } catch (e) {
      debugPrint('[GroupsScreen] ❌ グループ作成エラー: $e');
      _showErrorSnackBar('グループの作成に失敗しました');
    }
  }

  /// 成功メッセージ表示
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
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
        title: const Text('グループ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadGroups,
            tooltip: '更新',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _groups.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.group_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'グループがありません',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '右下のボタンから新しいグループを作成できます',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadGroups,
              child: ListView.builder(
                itemCount: _groups.length,
                itemBuilder: (context, index) {
                  final group = _groups[index];
                  final isPersonalGroup = group.name == '個人TODO';

                  // 案3: リッチカードデザインを採用
                  return _buildRichCardDesign(group, isPersonalGroup);
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateGroupDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  /// リッチカードデザイン
  Widget _buildRichCardDesign(GroupModel group, bool isPersonalGroup) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          debugPrint('[GroupsScreen] グループ詳細画面へ遷移: ${group.id}');
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // アイコン
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isPersonalGroup
                        ? [
                            Theme.of(context).colorScheme.primaryContainer,
                            Theme.of(context).colorScheme.primary,
                          ]
                        : [
                            Theme.of(context).colorScheme.secondaryContainer,
                            Theme.of(context).colorScheme.secondary,
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isPersonalGroup ? Icons.person : Icons.group,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              // グループ情報
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 16,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '1人',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.check_circle_outline,
                          size: 16,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '0件のTODO',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
