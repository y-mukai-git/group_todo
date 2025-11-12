import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../data/models/user_model.dart';
import '../../data/models/group_model.dart';
import '../../data/models/group_invitation.dart';
import '../../services/data_cache_service.dart';
import '../../services/group_service.dart';
import '../../services/error_log_service.dart';
import '../../core/utils/snackbar_helper.dart';
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
  final GroupService _groupService = GroupService();
  List<GroupModel> _groups = [];
  List<GroupModel> _reorderingGroups = []; // 並び替え中の一時リスト
  List<GroupInvitationModel> _pendingInvitations = []; // 承認待ち招待一覧
  bool _isReorderMode = false; // 並び替えモードフラグ
  bool _isCompleting = false; // 完了処理中フラグ

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
    // DataCacheService.groupsで既にdisplayOrder順にソート済み
    final groups = List<GroupModel>.from(_cacheService.groups);

    if (mounted) {
      setState(() {
        _groups = groups;
      });
    }

    // 承認待ち招待一覧を取得
    _loadPendingInvitations();
  }

  /// 承認待ち招待一覧を取得
  Future<void> _loadPendingInvitations() async {
    try {
      final invitationsList = await _groupService.getPendingInvitations(
        userId: widget.user.id,
      );

      if (mounted) {
        final invitations = invitationsList
            .map((json) => GroupInvitationModel.fromJson(json))
            .toList();

        setState(() {
          _pendingInvitations = invitations;
        });
      }
    } catch (e) {
      debugPrint('[GroupsScreen] 承認待ち招待一覧取得エラー: $e');
      // エラーは無視（承認待ちがない場合も含む）
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
          child: const CreateGroupBottomSheet(),
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
        await _createGroup(
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
        errorMessage: 'グループの作成に失敗しました',
        stackTrace: '${e.toString()}\n${stackTrace.toString()}',
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
        errorMessage: 'データの更新に失敗しました',
        stackTrace: '${e.toString()}\n${stackTrace.toString()}',
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
    SnackBarHelper.showSuccessSnackBar(context, message);
  }

  /// 並び替えモード開始
  void _startReorderMode() {
    setState(() {
      _isReorderMode = true;
      _reorderingGroups = List.from(_groups); // 現在の順序をコピー
    });
  }

  /// 並び替えキャンセル
  void _cancelReorder() {
    setState(() {
      _isReorderMode = false;
      _reorderingGroups = [];
    });
  }

  /// 並び替え完了（DB保存）
  Future<void> _completeReorder() async {
    // 多重実行防止
    if (_isCompleting) return;

    setState(() {
      _isCompleting = true;
    });

    try {
      // DB保存
      await _cacheService.updateGroupOrder(
        userId: widget.user.id,
        orderedGroups: _reorderingGroups,
      );

      setState(() {
        _isReorderMode = false;
        _reorderingGroups = [];
        _isCompleting = false;
      });

      _showSuccessSnackBar('グループ順を変更しました');
    } catch (e, stackTrace) {
      debugPrint('[GroupsScreen] ❌ 並び順保存エラー: $e');

      // エラーログ記録
      final errorLog = await ErrorLogService().logError(
        userId: widget.user.id,
        errorType: '並び順保存エラー',
        errorMessage: '並び順の保存に失敗しました',
        stackTrace: '${e.toString()}\n${stackTrace.toString()}',
        screenName: 'グループ一覧画面',
      );

      // エラーダイアログ表示
      if (!mounted) return;
      await ErrorDialog.show(
        context: context,
        errorId: errorLog.id,
        errorMessage: '並び順の保存に失敗しました',
      );

      // エラー時は変更をキャンセル
      setState(() {
        _isCompleting = false;
      });
      _cancelReorder();
    }
  }

  /// 並び替え実行時のコールバック
  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _reorderingGroups.removeAt(oldIndex);
      _reorderingGroups.insert(newIndex, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: const Key('groups-screen'),
      onVisibilityChanged: (info) {
        // 画面が非表示になった時（他のタブに切り替わった時）
        if (info.visibleFraction == 0.0 && _isReorderMode) {
          _cancelReorder();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title: Text(_isReorderMode ? '並び替え' : 'グループ'),
          leadingWidth: _isReorderMode ? 100 : null,
          leading: _isReorderMode
              ? TextButton(
                  onPressed: _cancelReorder,
                  child: const Text(
                    'キャンセル',
                    style: TextStyle(color: Colors.white),
                  ),
                )
              : null,
          actions: [
            if (_isReorderMode)
              TextButton(
                onPressed: _isCompleting ? null : _completeReorder,
                child: Text(
                  '完了',
                  style: TextStyle(
                    color: _isCompleting
                        ? Colors.white.withValues(alpha: 0.5)
                        : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              TextButton.icon(
                onPressed: _groups.isEmpty ? null : _startReorderMode,
                icon: const Icon(Icons.swap_vert),
                label: const Text('並び替え'),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
              ),
          ],
        ),
        body: _groups.isEmpty
            ? RefreshIndicator(
                onRefresh: _refreshData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height - 200,
                    child: Center(
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
                    ),
                  ),
                ),
              )
            : _isReorderMode
            ? _buildReorderableList()
            : RefreshIndicator(
                onRefresh: _refreshData,
                child: ListView(children: _buildGroupedList()),
              ),
        floatingActionButton: _isReorderMode
            ? null
            : FloatingActionButton(
                heroTag: 'groups_fab',
                onPressed: _showCreateGroupDialog,
                child: const Icon(Icons.add),
              ),
      ),
    );
  }

  /// グループ分類リストを構築（個人・グループセクション）
  List<Widget> _buildGroupedList() {
    final widgets = <Widget>[];

    // 上部余白
    widgets.add(const SizedBox(height: 12));

    // 承認待ち招待セクション
    if (_pendingInvitations.isNotEmpty) {
      widgets.add(_buildPendingInvitationsSection());
      widgets.add(const SizedBox(height: 16));
    }

    // 全グループを表示（displayOrder順）
    for (final group in _groups) {
      widgets.add(_buildGroupItem(group));
    }

    return widgets;
  }

  /// 承認待ち招待セクションを構築
  Widget _buildPendingInvitationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            '承認待ちの招待',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        ..._pendingInvitations.map((invitation) {
          return _buildInvitationCard(invitation);
        }),
      ],
    );
  }

  /// 招待カードを構築
  Widget _buildInvitationCard(GroupInvitationModel invitation) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // グループ名
            Text(
              invitation.groupName ?? '不明なグループ',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            // 招待者名
            Row(
              children: [
                const Icon(Icons.person, size: 16),
                const SizedBox(width: 4),
                Text(
                  '招待者: ${invitation.inviterName ?? '不明'}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 4),
            // ロール
            Row(
              children: [
                Icon(
                  invitation.invitedRole == 'owner' ? Icons.star : Icons.person,
                  size: 16,
                  color: invitation.invitedRole == 'owner'
                      ? Colors.amber
                      : null,
                ),
                const SizedBox(width: 4),
                Text(
                  'ロール: ${invitation.invitedRole == 'owner' ? 'オーナー' : 'メンバー'}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 承認/却下ボタン
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _rejectInvitation(invitation.id),
                  child: const Text('却下'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => _acceptInvitation(invitation.id),
                  child: const Text('承認'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// グループ招待を承認
  Future<void> _acceptInvitation(String invitationId) async {
    // ローディング表示
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await _groupService.acceptInvitation(
        invitationId: invitationId,
        userId: widget.user.id,
      );

      // キャッシュを再読み込み（承認したグループが追加される）
      await _cacheService.refreshCache();

      // 招待一覧を再取得
      await _loadPendingInvitations();

      // ローディング非表示
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showSuccessSnackBar('招待を承認しました');
      }
    } catch (e) {
      debugPrint('[GroupsScreen] 招待承認エラー: $e');

      // ローディング非表示
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        SnackBarHelper.showErrorSnackBar(context, '招待の承認に失敗しました');
      }
    }
  }

  /// グループ招待を却下
  Future<void> _rejectInvitation(String invitationId) async {
    // ローディング表示
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await _groupService.rejectInvitation(
        invitationId: invitationId,
        userId: widget.user.id,
      );

      // 招待一覧を再取得
      await _loadPendingInvitations();

      // ローディング非表示
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showSuccessSnackBar('招待を却下しました');
      }
    } catch (e) {
      debugPrint('[GroupsScreen] 招待却下エラー: $e');

      // ローディング非表示
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        SnackBarHelper.showErrorSnackBar(context, '招待の却下に失敗しました');
      }
    }
  }

  /// 並び替えモード用リスト構築
  Widget _buildReorderableList() {
    return ReorderableListView(
      onReorder: _onReorder,
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.only(top: 12, bottom: 80),
      children: _reorderingGroups.asMap().entries.map((entry) {
        final index = entry.key;
        final group = entry.value;
        return _buildReorderableGroupItem(group, index);
      }).toList(),
    );
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
  Widget _buildGroupItem(GroupModel group) {
    final isPersonalGroup = group.name == '個人TODO';
    // カテゴリ情報取得
    final categoryInfo = _getCategoryInfo(group.category);

    // メンバー数取得
    int memberCount = 1; // デフォルト1人
    final membersData = _cacheService.getGroupMembers(group.id);
    if (membersData != null && membersData['success'] == true) {
      final membersList = membersData['members'] as List<dynamic>;
      // 承諾待ちユーザーを除外してカウント
      memberCount = membersList
          .where((m) => !(m['is_pending'] as bool? ?? false))
          .length;
    }

    // タスク件数取得（未完了のみ）
    final todos = _cacheService.getTodosByGroupId(group.id);
    final incompleteTodoCount = todos.where((t) => !t.isCompleted).length;

    // オーナー判定
    final isOwner = group.ownerId == widget.user.id;

    // グループカードWidget
    final groupCardWidget = InkWell(
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
                      if (group.category != null && categoryInfo != null) ...[
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
    );

    // オーナーの場合のみスワイプ削除可能
    return Column(
      children: [
        if (isOwner)
          Dismissible(
            key: Key(group.id),
            direction: DismissDirection.endToStart,
            confirmDismiss: (direction) async {
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
                  errorMessage: 'グループの削除に失敗しました',
                  stackTrace: '${e.toString()}\n${stackTrace.toString()}',
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
            child: groupCardWidget,
          )
        else
          groupCardWidget,
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

  /// 並び替えモード用グループアイテムウィジェット
  Widget _buildReorderableGroupItem(GroupModel group, int index) {
    final isPersonalGroup = group.name == '個人TODO';

    // カテゴリ情報取得
    final categoryInfo = _getCategoryInfo(group.category);

    // メンバー数取得
    int memberCount = 1; // デフォルト1人
    final membersData = _cacheService.getGroupMembers(group.id);
    if (membersData != null && membersData['success'] == true) {
      final membersList = membersData['members'] as List<dynamic>;
      // 承諾待ちユーザーを除外してカウント
      memberCount = membersList
          .where((m) => !(m['is_pending'] as bool? ?? false))
          .length;
    }

    // タスク件数取得（未完了のみ）
    final todos = _cacheService.getTodosByGroupId(group.id);
    final incompleteTodoCount = todos.where((t) => !t.isCompleted).length;

    return Container(
      key: Key(group.id), // ReorderableListViewで必須
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                // ドラッグハンドル
                ReorderableDragStartListener(
                  index: index,
                  child: Icon(
                    Icons.drag_handle,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                const SizedBox(width: 16),
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
              ],
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
      ),
    );
  }
}
