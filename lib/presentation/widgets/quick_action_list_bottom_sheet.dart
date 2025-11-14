import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../data/models/quick_action_model.dart';
import '../../services/data_cache_service.dart';
import '../../services/error_log_service.dart';
import '../../core/utils/snackbar_helper.dart';
import '../widgets/error_dialog.dart';

/// クイックアクション実行ボトムシート
class QuickActionListBottomSheet extends StatefulWidget {
  final String? fixedGroupId; // グループID（常に固定）
  final String? defaultGroupId; // グループID（デフォルト値、変更可能）
  final String userId;

  const QuickActionListBottomSheet({
    super.key,
    this.fixedGroupId,
    this.defaultGroupId,
    required this.userId,
  });

  @override
  State<QuickActionListBottomSheet> createState() =>
      _QuickActionListBottomSheetState();
}

class _QuickActionListBottomSheetState
    extends State<QuickActionListBottomSheet> {
  final DataCacheService _cacheService = DataCacheService();
  bool _isExecuting = false;
  String? _executingQuickActionId;
  String? _selectedGroupId;

  @override
  void initState() {
    super.initState();

    // fixedGroupIdが設定されている場合はそれを使用、なければdefaultGroupIdを使用
    if (widget.fixedGroupId != null) {
      _selectedGroupId = widget.fixedGroupId;
    } else if (widget.defaultGroupId != null) {
      _selectedGroupId = widget.defaultGroupId;
    } else {
      // デフォルトグループがない場合は最初のグループを選択
      final groups = _cacheService.groups;
      if (groups.isNotEmpty) {
        _selectedGroupId = groups.first.id;
      }
    }
  }

  /// クイックアクション実行
  Future<void> _executeQuickAction(QuickActionModel quickAction) async {
    if (_isExecuting) return;

    setState(() {
      _isExecuting = true;
      _executingQuickActionId = quickAction.id;
    });

    try {
      // クイックアクション実行（execute-quick-action Edge Function呼び出し）
      await _cacheService.executeQuickAction(
        userId: widget.userId,
        quickActionId: quickAction.id,
      );

      if (!mounted) return;

      // キャッシュをリフレッシュして新規作成されたTODOを反映
      await _cacheService.refreshCache();

      if (!mounted) return;

      // 成功メッセージ
      SnackBarHelper.showSuccessSnackBar(
        context,
        'クイックアクション「${quickAction.name}」を実行しました',
      );

      // ボトムシートを閉じる
      Navigator.pop(context);
    } catch (e, stackTrace) {
      debugPrint('[QuickActionListBottomSheet] ❌ クイックアクション実行エラー: $e');

      final errorLog = await ErrorLogService().logError(
        userId: widget.userId,
        errorType: 'クイックアクション実行エラー',
        errorMessage: 'クイックアクションの実行に失敗しました',
        stackTrace: '${e.toString()}\n${stackTrace.toString()}',
        screenName: 'クイックアクション一覧',
      );

      if (mounted) {
        await ErrorDialog.show(
          context: context,
          errorId: errorLog.id,
          errorMessage: 'クイックアクションの実行に失敗しました',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExecuting = false;
          _executingQuickActionId = null;
        });
      }
    }
  }

  /// グループ選択ピッカー表示
  void _showGroupPicker() {
    final groups = _cacheService.groups;

    // 現在選択されているインデックスを取得
    int currentIndex = 0;
    if (_selectedGroupId != null) {
      currentIndex = groups.indexWhere((g) => g.id == _selectedGroupId);
      if (currentIndex < 0) currentIndex = 0;
    }

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        int selectedIndex = currentIndex;

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
                      final selectedGroup = groups[selectedIndex];
                      setState(() {
                        _selectedGroupId = selectedGroup.id;
                      });
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
                    initialItem: selectedIndex,
                  ),
                  onSelectedItemChanged: (index) {
                    selectedIndex = index;
                  },
                  children: groups
                      .map((group) => Center(child: Text(group.name)))
                      .toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// グループ選択UI（ピッカー形式）
  Widget _buildGroupSelector() {
    final groups = _cacheService.groups;

    // 選択されているグループ名を取得
    String displayText;
    if (_selectedGroupId != null) {
      final selectedGroup = groups.firstWhere(
        (g) => g.id == _selectedGroupId,
        orElse: () => groups.first,
      );
      displayText = selectedGroup.name;
    } else {
      displayText = 'グループを選択';
    }

    return InkWell(
      onTap: _showGroupPicker,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.folder, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                displayText,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              color: Theme.of(context).colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = _cacheService.groups;
    final quickActions = _selectedGroupId != null
        ? _cacheService.getQuickActionsByGroupId(_selectedGroupId!)
        : <QuickActionModel>[];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ハンドル
        Container(
          margin: const EdgeInsets.only(top: 12, bottom: 8),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        // タイトル
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Icon(
                Icons.flash_on,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'クイックアクション',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        // グループ選択（fixedGroupIdがnullの場合のみ表示）
        if (widget.fixedGroupId == null && groups.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _buildGroupSelector(),
          ),
        // クイックアクション一覧
        if (quickActions.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(
                  Icons.flash_off_outlined,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  'クイックアクションがありません',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'グループ詳細画面から設定できます',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          )
        else
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: quickActions.length,
              itemBuilder: (context, index) {
                final quickAction = quickActions[index];
                final isExecuting = _executingQuickActionId == quickAction.id;

                return ListTile(
                  leading: Icon(
                    Icons.flash_on,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(quickAction.name),
                  subtitle: quickAction.description != null
                      ? Text(
                          quickAction.description!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : null,
                  trailing: isExecuting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow),
                  enabled: !_isExecuting,
                  onTap: () => _executeQuickAction(quickAction),
                );
              },
            ),
          ),
      ],
    );
  }
}
