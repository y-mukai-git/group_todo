import 'package:flutter/material.dart';
import '../../data/models/user_model.dart';
import '../../data/models/group_model.dart';
import '../../services/group_service.dart';
import '../widgets/create_group_bottom_sheet.dart';
import 'group_detail_screen.dart';

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

  /// グループ作成ボトムシート表示
  Future<void> _showCreateGroupDialog() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: true,
      useRootNavigator: false,
      builder: (context) => const CreateGroupBottomSheet(),
    );

    if (result != null && mounted) {
      _createGroup(
        name: result['name'] as String,
        description: result['description'] as String?,
        category: result['category'] as String?,
      );
    }
  }

  /// グループ作成実行
  Future<void> _createGroup({
    required String name,
    String? description,
    String? category,
  }) async {
    try {
      await _groupService.createGroup(
        userId: widget.user.id,
        groupName: name,
        description: description,
        category: category,
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
              child: ListView(
                children: _buildGroupedList(),
              ),
            ),
      floatingActionButton: Stack(
        children: [
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              onPressed: _showCreateGroupDialog,
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }

  /// グループ分類リストを構築（個人・グループセクション）
  List<Widget> _buildGroupedList() {
    // 個人グループ（name == '個人TODO'）とグループグループに分類
    final personalGroups = _groups.where((g) => g.name == '個人TODO').toList();
    final teamGroups = _groups.where((g) => g.name != '個人TODO').toList();

    final widgets = <Widget>[];

    // 上部余白
    widgets.add(const SizedBox(height: 12));

    // 個人セクション
    if (personalGroups.isNotEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            '個人',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
      );

      for (final group in personalGroups) {
        widgets.add(_buildGroupItem(group, true));
      }
    }

    // グループセクション
    if (teamGroups.isNotEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'グループ',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
      );

      for (final group in teamGroups) {
        widgets.add(_buildGroupItem(group, false));
      }
    }

    return widgets;
  }

  /// グループアイテムウィジェット
  Widget _buildGroupItem(GroupModel group, bool isPersonalGroup) {
    return Column(
      children: [
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GroupDetailScreen(
                  user: widget.user,
                  group: group,
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                // アイコン
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isPersonalGroup
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isPersonalGroup ? Icons.person : Icons.group,
                    color: isPersonalGroup
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.secondary,
                    size: 24,
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
        Divider(
          height: 1,
          thickness: 1,
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ],
    );
  }
}
