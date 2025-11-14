import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../data/models/quick_action_model.dart';
import '../../services/data_cache_service.dart';
import '../../services/error_log_service.dart';
import 'error_dialog.dart';
import '../../core/utils/content_validator.dart';
import '../../core/utils/snackbar_helper.dart';
import '../screens/content_policy_screen.dart';

/// セットTODO作成・編集ボトムシート
class CreateQuickActionBottomSheet extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String userId;
  final List<Map<String, String>>? availableAssignees; // 担当者候補リスト [{id, name}]
  final QuickActionModel? existingQuickAction; // 編集モード時の既存データ

  const CreateQuickActionBottomSheet({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.userId,
    this.availableAssignees,
    this.existingQuickAction,
  });

  @override
  State<CreateQuickActionBottomSheet> createState() =>
      _CreateQuickActionBottomSheetState();
}

class _CreateQuickActionBottomSheetState
    extends State<CreateQuickActionBottomSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final DataCacheService _cacheService = DataCacheService();

  List<TemplateItem> _templates = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    // 編集モード時：既存データを初期値として設定
    if (widget.existingQuickAction != null) {
      final existing = widget.existingQuickAction!;
      _nameController.text = existing.name;
      _descriptionController.text = existing.description ?? '';

      // テンプレートを復元
      if (existing.templates != null && existing.templates!.isNotEmpty) {
        _templates = existing.templates!.map((t) {
          return TemplateItem(
            titleController: TextEditingController(text: t.title),
            descriptionController: TextEditingController(
              text: t.description ?? '',
            ),
            deadlineDaysAfter: t.deadlineDaysAfter,
            assignedUserIds: t.assignedUserIds?.toSet() ?? {},
          );
        }).toList();
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    for (var template in _templates) {
      template.titleController.dispose();
      template.descriptionController.dispose();
    }
    super.dispose();
  }

  /// テンプレート追加（ダイアログ表示）
  Future<void> _addTemplate() async {
    final newTemplate = TemplateItem(
      titleController: TextEditingController(),
      descriptionController: TextEditingController(),
      assignedUserIds: {widget.userId},
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _TemplateEditDialog(
        template: newTemplate,
        availableAssignees: widget.availableAssignees,
      ),
    );

    if (result == true) {
      setState(() {
        _templates.add(newTemplate);
      });
    } else {
      newTemplate.titleController.dispose();
      newTemplate.descriptionController.dispose();
    }
  }

  /// テンプレート削除
  void _removeTemplate(int index) {
    setState(() {
      _templates[index].titleController.dispose();
      _templates[index].descriptionController.dispose();
      _templates.removeAt(index);
    });
  }

  /// テンプレート編集（ダイアログ表示）
  Future<void> _editTemplate(int index) async {
    await showDialog(
      context: context,
      builder: (context) => _TemplateEditDialog(
        template: _templates[index],
        availableAssignees: widget.availableAssignees,
      ),
    );
    setState(() {});
  }

  /// セットTODO作成・更新実行
  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      SnackBarHelper.showErrorSnackBar(context, 'セットTODO名を入力してください');
      return;
    }

    // コンテンツバリデーション
    final validationError = ContentValidator.validate(name);
    if (validationError != null) {
      SnackBarHelper.showErrorSnackBar(context, validationError);
      return;
    }

    // テンプレートのバリデーション
    if (_templates.isEmpty) {
      SnackBarHelper.showErrorSnackBar(context, 'テンプレートを1つ以上追加してください');
      return;
    }

    for (int i = 0; i < _templates.length; i++) {
      if (_templates[i].titleController.text.trim().isEmpty) {
        SnackBarHelper.showErrorSnackBar(
          context,
          'テンプレート${i + 1}のタイトルを入力してください',
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      // テンプレートデータ作成
      final templates = _templates.asMap().entries.map((entry) {
        return QuickActionTemplateModel(
          id: '', // サーバー側で生成
          quickActionId: '', // サーバー側で生成
          title: entry.value.titleController.text.trim(),
          description: entry.value.descriptionController.text.trim().isEmpty
              ? null
              : entry.value.descriptionController.text.trim(),
          deadlineDaysAfter: entry.value.deadlineDaysAfter,
          assignedUserIds: entry.value.assignedUserIds.toList(),
          displayOrder: entry.key,
          createdAt: DateTime.now(),
        );
      }).toList();

      if (widget.existingQuickAction != null) {
        // 更新
        await _cacheService.updateQuickAction(
          userId: widget.userId,
          groupId: widget.groupId,
          quickActionId: widget.existingQuickAction!.id,
          name: name,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          templates: templates,
        );
      } else {
        // 新規作成
        await _cacheService.createQuickAction(
          userId: widget.userId,
          groupId: widget.groupId,
          name: name,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          templates: templates,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true); // 成功フラグを返す
    } catch (e, stackTrace) {
      debugPrint('[CreateQuickActionBottomSheet] ❌ エラー: $e');

      // エラーログ記録
      final errorLog = await ErrorLogService().logError(
        userId: widget.userId,
        errorType: widget.existingQuickAction != null
            ? 'セットTODO更新エラー'
            : 'セットTODO作成エラー',
        errorMessage: widget.existingQuickAction != null
            ? 'セットTODOの更新に失敗しました'
            : 'セットTODOの作成に失敗しました',
        stackTrace: '${e.toString()}\n${stackTrace.toString()}',
        screenName: 'セットTODO作成・編集',
      );

      // エラーダイアログ表示
      if (!mounted) return;
      await ErrorDialog.show(
        context: context,
        errorId: errorLog.id,
        errorMessage: 'セットTODOの保存に失敗しました',
      );

      setState(() => _isLoading = false);
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
                        Icons.flash_on,
                        color: Theme.of(context).colorScheme.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.existingQuickAction != null
                                  ? 'セットTODO編集'
                                  : 'セットTODO作成',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              widget.groupName,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
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

                // コンテンツ（スクロール可能）
                Expanded(
                  child: Column(
                    children: [
                      // 上部コンテンツ
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.all(24),
                          children: [
                            // コンテンツポリシーリンク
                            Align(
                              alignment: Alignment.centerRight,
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const ContentPolicyScreen(),
                                    ),
                                  );
                                },
                                child: Text(
                                  '入力における注意事項',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // セットTODO名入力
                            TextField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: 'セットTODO名',
                                hintText: 'セットTODO名を入力',
                                prefixIcon: const Icon(Icons.flash_on),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              autofocus: false,
                              textInputAction: TextInputAction.next,
                              maxLength: 100,
                            ),

                            const SizedBox(height: 12),

                            // 説明入力
                            TextField(
                              controller: _descriptionController,
                              decoration: InputDecoration(
                                labelText: '説明（任意）',
                                hintText: '説明を入力',
                                prefixIcon: const Icon(Icons.description),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              maxLines: 2,
                              maxLength: 200,
                              textInputAction: TextInputAction.done,
                            ),

                            const SizedBox(height: 16),

                            // TODOテンプレート見出し
                            Text(
                              'TODOテンプレート',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),

                            const SizedBox(height: 16),

                            // テンプレートリスト
                            ...List.generate(_templates.length, (index) {
                              final template = _templates[index];
                              final assignedUser = widget.availableAssignees
                                  ?.firstWhere(
                                    (a) =>
                                        a['id'] ==
                                        template.assignedUserIds.firstOrNull,
                                    orElse: () => {'id': '', 'name': '未設定'},
                                  );

                              return Dismissible(
                                key: Key(index.toString()),
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
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onError,
                                  ),
                                ),
                                confirmDismiss: (direction) async {
                                  return await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('削除確認'),
                                      content: Text(
                                        '「${template.titleController.text.isEmpty ? 'テンプレート ${index + 1}' : template.titleController.text}」を削除しますか？',
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
                                    _removeTemplate(index),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surface,
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
                                    onTap: () => _editTemplate(index),
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
                                                  template
                                                          .titleController
                                                          .text
                                                          .isEmpty
                                                      ? 'テンプレート ${index + 1}'
                                                      : template
                                                            .titleController
                                                            .text,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                ),
                                                const SizedBox(height: 8),
                                                Wrap(
                                                  spacing: 8,
                                                  children: [
                                                    if (template
                                                            .deadlineDaysAfter !=
                                                        null)
                                                      Chip(
                                                        label: Text(
                                                          '${template.deadlineDaysAfter}日後',
                                                          style: Theme.of(
                                                            context,
                                                          ).textTheme.bodySmall,
                                                        ),
                                                        padding:
                                                            EdgeInsets.zero,
                                                        materialTapTargetSize:
                                                            MaterialTapTargetSize
                                                                .shrinkWrap,
                                                      ),
                                                    if (assignedUser != null &&
                                                        assignedUser['name'] !=
                                                            '未設定')
                                                      Chip(
                                                        label: Text(
                                                          assignedUser['name']!,
                                                          style: Theme.of(
                                                            context,
                                                          ).textTheme.bodySmall,
                                                        ),
                                                        padding:
                                                            EdgeInsets.zero,
                                                        materialTapTargetSize:
                                                            MaterialTapTargetSize
                                                                .shrinkWrap,
                                                      ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),

                            const SizedBox(height: 8),

                            // テンプレート追加ボタン
                            OutlinedButton.icon(
                              onPressed: _addTemplate,
                              icon: const Icon(Icons.add),
                              label: const Text('テンプレート追加'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // 保存ボタン
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _isLoading ? null : _save,
                                icon: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Icon(
                                        widget.existingQuickAction != null
                                            ? Icons.edit
                                            : Icons.add,
                                      ),
                                label: Text(
                                  widget.existingQuickAction != null
                                      ? '更新'
                                      : '作成',
                                ),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

/// ダイアログでテンプレート編集
class _TemplateEditDialog extends StatefulWidget {
  final TemplateItem template;
  final List<Map<String, String>>? availableAssignees;

  const _TemplateEditDialog({required this.template, this.availableAssignees});

  @override
  State<_TemplateEditDialog> createState() => _TemplateEditDialogState();
}

class _TemplateEditDialogState extends State<_TemplateEditDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late int? _deadlineDaysAfter;
  late Set<String> _assignedUserIds;

  @override
  void initState() {
    super.initState();
    // 独自のTextEditingControllerを作成し、元の値で初期化
    _titleController = TextEditingController(
      text: widget.template.titleController.text,
    );
    _descriptionController = TextEditingController(
      text: widget.template.descriptionController.text,
    );
    _deadlineDaysAfter = widget.template.deadlineDaysAfter;
    _assignedUserIds = Set.from(widget.template.assignedUserIds);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 24.0,
      ),
      title: const Text('TODOテンプレート'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // TODOタイトル
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'TODOタイトル',
                  hintText: 'TODOのタイトルを入力',
                  prefixIcon: const Icon(Icons.title),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLength: 15,
              ),
              const SizedBox(height: 12),

              // TODO説明
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'TODO説明（任意）',
                  hintText: 'TODOの詳細を入力',
                  prefixIcon: const Icon(Icons.description),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 2,
                maxLength: 200,
              ),
              const SizedBox(height: 12),

              // 期限設定
              Text(
                '期限設定',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _showDeadlinePicker,
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
                        Icons.calendar_today,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _deadlineDaysAfter == null
                            ? '期限なし'
                            : '$_deadlineDaysAfter日後',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const Spacer(),
                      Icon(
                        Icons.arrow_drop_down,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 担当者
              if (widget.availableAssignees != null &&
                  widget.availableAssignees!.isNotEmpty) ...[
                Text(
                  '担当者',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                // グループに1人のみ：表示のみ（変更不可）
                if (widget.availableAssignees!.length == 1)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.person,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          widget.availableAssignees!.first['name']!,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const Spacer(),
                        Icon(
                          Icons.lock,
                          size: 16,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ],
                    ),
                  ),
                // グループに複数人：選択可能
                if (widget.availableAssignees!.length > 1)
                  InkWell(
                    onTap: _showAssigneePicker,
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
                            Icons.person,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _assignedUserIds.isEmpty
                                ? '担当者を選択'
                                : widget.availableAssignees!.firstWhere(
                                    (a) => a['id'] == _assignedUserIds.first,
                                    orElse: () => {'id': '', 'name': '未設定'},
                                  )['name']!,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const Spacer(),
                          Icon(
                            Icons.arrow_drop_down,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () {
            // OKがタップされた場合、独自のcontrollerの値を元のcontrollerにコピー
            widget.template.titleController.text = _titleController.text;
            widget.template.descriptionController.text =
                _descriptionController.text;
            widget.template.deadlineDaysAfter = _deadlineDaysAfter;
            widget.template.assignedUserIds = _assignedUserIds;
            Navigator.pop(context, true);
          },
          child: const Text('OK'),
        ),
      ],
    );
  }

  void _showDeadlinePicker() {
    final deadlineOptions = <int?>[
      null,
      ...List.generate(30, (index) => index + 1),
    ];
    final deadlineLabels = [
      '期限なし',
      ...List.generate(30, (index) => '${index + 1}日後'),
    ];
    final currentIndex = _deadlineDaysAfter == null
        ? 0
        : deadlineOptions.indexOf(_deadlineDaysAfter);

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
                      _deadlineDaysAfter = deadlineOptions[index];
                    });
                  },
                  children: deadlineLabels
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

  void _showAssigneePicker() {
    if (widget.availableAssignees == null ||
        widget.availableAssignees!.isEmpty) {
      return;
    }

    final assignees = widget.availableAssignees!;
    final currentAssigneeId = _assignedUserIds.isEmpty
        ? null
        : _assignedUserIds.first;
    final currentIndex = assignees.indexWhere(
      (a) => a['id'] == currentAssigneeId,
    );

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        int selectedIndex = currentIndex >= 0 ? currentIndex : 0;

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
                      setState(() {
                        _assignedUserIds = {assignees[selectedIndex]['id']!};
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
                  children: assignees
                      .map((assignee) => Center(child: Text(assignee['name']!)))
                      .toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// テンプレートアイテム
class TemplateItem {
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  int? deadlineDaysAfter;
  Set<String> assignedUserIds;

  TemplateItem({
    required this.titleController,
    required this.descriptionController,
    this.deadlineDaysAfter,
    Set<String>? assignedUserIds,
  }) : assignedUserIds = assignedUserIds ?? {};
}
