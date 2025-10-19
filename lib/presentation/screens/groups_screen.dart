import 'package:flutter/material.dart';
import '../../data/models/user_model.dart';
import '../../data/models/group_model.dart';
import '../../services/data_cache_service.dart';
import '../../services/error_log_service.dart';
import '../widgets/create_group_bottom_sheet.dart';
import '../widgets/error_dialog.dart';
import 'group_detail_screen.dart';

/// グループ一覧画面
class GroupsScreen extends StatefulWidget {
  final UserModel user;

  const GroupsScreen({super.key, required this.user});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final DataCacheService _cacheService = DataCacheService();
  List<GroupModel> _groups = [];

  @override
  void initState() {
    super.initState();
    // キャッシュリスナー登録
    _cacheService.addListener(_updateGroups);
    // 初回データ取得
    _updateGroups();
  }

  @override
  void dispose() {
    // リスナー解除
    _cacheService.removeListener(_updateGroups);
    super.dispose();
  }

  /// キャッシュからグループ取得
  void _updateGroups() {
    final groups = List<GroupModel>.from(_cacheService.groups);

    // 個人用グループを最上部に表示
    groups.sort((a, b) {
      if (a.name == '個人TODO') return -1;
      if (b.name == '個人TODO') return 1;
      return (a.createdAt ?? DateTime.now()).compareTo(
        b.createdAt ?? DateTime.now(),
      );
    });

    if (mounted) {
      setState(() {
        _groups = groups;
      });
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
        imageData: result['image_data'] as String?,
      );
    }
  }

  /// グループ作成実行（キャッシュサービス経由）
  Future<void> _createGroup({
    required String name,
    String? description,
    String? category,
    String? imageData,
  }) async {
    try {
      // DataCacheService経由でDB作成+キャッシュ追加
      await _cacheService.createGroup(
        userId: widget.user.id,
        groupName: name,
        description: description,
        category: category,
        imageData: imageData,
      );

      _showSuccessSnackBar('グループを作成しました');
    } catch (e, stackTrace) {
      debugPrint('[GroupsScreen] ❌ グループ作成エラー: $e');

      // エラーログ記録
      final errorLog = await ErrorLogService().logError(
        userId: widget.user.id,
        errorType: 'グループ作成エラー',
        errorMessage: e.toString(),
        stackTrace: stackTrace.toString(),
        screenName: 'グループ一覧画面',
      );

      // エラーダイアログ表示
      if (!mounted) return;
      await ErrorDialog.show(
        context: context,
        errorId: errorLog.id,
        errorMessage: 'グループの作成に失敗しました',
      );
    }
  }

  /// 手動リフレッシュ
  Future<void> _refreshData() async {
    try {
      await _cacheService.refreshCache();
    } catch (e, stackTrace) {
      debugPrint('[GroupsScreen] ❌ データ更新エラー: $e');

      // エラーログ記録
      final errorLog = await ErrorLogService().logError(
        userId: widget.user.id,
        errorType: 'データ更新エラー',
        errorMessage: e.toString(),
        stackTrace: stackTrace.toString(),
        screenName: 'グループ一覧画面',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('グループ')),
      body: _groups.isEmpty
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
              onRefresh: _refreshData,
              child: ListView(children: _buildGroupedList()),
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'groups_fab',
        onPressed: _showCreateGroupDialog,
        child: const Icon(Icons.add),
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
      for (final group in personalGroups) {
        widgets.add(_buildGroupItem(group, true));
      }
    }

    // グループセクション
    if (teamGroups.isNotEmpty) {
      for (final group in teamGroups) {
        widgets.add(_buildGroupItem(group, false));
      }
    }

    return widgets;
  }

  /// カテゴリ情報取得
  Map<String, dynamic>? _getCategoryInfo(String? category) {
    if (category == null || category == 'none') return null;

    const categoryMap = {
      'shopping': {'name': '買い物', 'icon': Icons.shopping_cart},
      'housework': {'name': '家事', 'icon': Icons.home},
      'work': {'name': '仕事', 'icon': Icons.work},
      'hobby': {'name': '趣味', 'icon': Icons.palette},
      'other': {'name': 'その他', 'icon': Icons.label},
    };

    return categoryMap[category];
  }

  /// グループアイテムウィジェット
  Widget _buildGroupItem(GroupModel group, bool isPersonalGroup) {
    // カテゴリ情報取得
    final categoryInfo = _getCategoryInfo(group.category);

    // メンバー数取得
    int memberCount = 1; // デフォルト1人
    final membersData = _cacheService.getGroupMembers(group.id);
    if (membersData != null && membersData['success'] == true) {
      final membersList = membersData['members'] as List<dynamic>;
      memberCount = membersList.length;
    }

    // TODO件数取得（未完了のみ）
    final todos = _cacheService.getTodosByGroupId(group.id);
    final incompleteTodoCount = todos.where((t) => !t.isCompleted).length;

    // オーナー判定
    final isOwner = group.ownerId == widget.user.id;

    return Column(
      children: [
        Dismissible(
          key: Key(group.id),
          direction: DismissDirection.endToStart,
          confirmDismiss: (direction) async {
            if (!isOwner) {
              // オーナー以外は削除不可
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('オーナーしか消せません'),
                  backgroundColor: Colors.red,
                ),
              );
              return false;
            }

            // オーナーの場合は削除確認ダイアログ表示
            return await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('グループ削除'),
                content: Text('「${group.name}」を削除しますか？'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('キャンセル'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('削除'),
                  ),
                ],
              ),
            );
          },
          onDismissed: (direction) async {
            try {
              // グループ削除API呼び出し
              await _cacheService.deleteGroup(
                groupId: group.id,
                userId: widget.user.id,
              );
              _showSuccessSnackBar('グループを削除しました');
            } catch (e, stackTrace) {
              debugPrint('[GroupsScreen] ❌ グループ削除エラー: $e');

              // エラーログ記録
              final errorLog = await ErrorLogService().logError(
                userId: widget.user.id,
                errorType: 'グループ削除エラー',
                errorMessage: e.toString(),
                stackTrace: stackTrace.toString(),
                screenName: 'グループ一覧画面',
              );

              // エラーダイアログ表示
              if (!mounted) return;
              await ErrorDialog.show(
                context: context,
                errorId: errorLog.id,
                errorMessage: 'グループの削除に失敗しました',
              );
            }
          },
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: Colors.red,
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      GroupDetailScreen(user: widget.user, group: group),
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
                      image: group.signedIconUrl != null
                          ? DecorationImage(
                              image: NetworkImage(group.signedIconUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: group.signedIconUrl == null
                        ? Icon(
                            isPersonalGroup ? Icons.person : Icons.group,
                            color: isPersonalGroup
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.secondary,
                            size: 24,
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  // グループ情報
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                group.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            // カテゴリ表示
                            if (group.category != null &&
                                categoryInfo != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.tertiaryContainer,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      categoryInfo['icon'] as IconData,
                                      size: 14,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onTertiaryContainer,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      categoryInfo['name'] as String,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onTertiaryContainer,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
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
                              '$memberCount人',
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
                              '$incompleteTodoCount件のTODO',
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
