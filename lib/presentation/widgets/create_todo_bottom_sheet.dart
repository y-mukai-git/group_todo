import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import '../../data/models/todo_model.dart';

/// TODO作成・編集ボトムシート
class CreateTodoBottomSheet extends StatefulWidget {
  final String? fixedGroupId; // グループID（常に固定）
  final String? fixedGroupName; // グループ名（表示用）
  final List<Map<String, String>>? availableAssignees; // 担当者候補リスト [{id, name}]
  final String currentUserId; // 現在のユーザーID
  final String currentUserName; // 現在のユーザー名（固定表示用）
  final TodoModel? existingTodo; // 編集モード時の既存TODOデータ

  const CreateTodoBottomSheet({
    super.key,
    this.fixedGroupId,
    this.fixedGroupName,
    this.availableAssignees,
    required this.currentUserId,
    required this.currentUserName,
    this.existingTodo, // 編集モード用
  });

  @override
  State<CreateTodoBottomSheet> createState() => _CreateTodoBottomSheetState();
}

class _CreateTodoBottomSheetState extends State<CreateTodoBottomSheet>
    with SingleTickerProviderStateMixin {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  DateTime? _selectedDeadline;
  Set<String> _selectedAssigneeIds = {}; // 選択された担当者IDのセット

  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // 編集モード時：既存TODOデータを初期値として設定
    if (widget.existingTodo != null) {
      _titleController.text = widget.existingTodo!.title;
      _descriptionController.text = widget.existingTodo!.description ?? '';
      _selectedDeadline = widget.existingTodo!.dueDate;
      _selectedAssigneeIds =
          widget.existingTodo!.assignedUserIds?.toSet() ??
          {widget.currentUserId};
    } else {
      // 新規作成モード：自分を担当者に設定
      _selectedAssigneeIds = {widget.currentUserId};
    }

    // アニメーション設定
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation =
        Tween<Offset>(
          begin: const Offset(0, 1), // 画面下から
          end: Offset.zero, // 通常位置へ
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    // アニメーション開始
    _animationController.forward();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  /// 期限選択ピッカー表示
  Future<void> _selectDeadline() async {
    final now = DateTime.now();
    DateTime tempDate = _selectedDeadline ?? now;

    await showModalBottomSheet(
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
                      setState(() {
                        _selectedDeadline = tempDate;
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('完了'),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: _selectedDeadline ?? now,
                  minimumDate: now,
                  maximumDate: DateTime(now.year + 1),
                  onDateTimeChanged: (DateTime newDate) {
                    tempDate = newDate;
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 期限クリア
  void _clearDeadline() {
    setState(() {
      _selectedDeadline = null;
    });
  }

  /// 担当者選択ピッカー表示
  void _showAssigneePicker() {
    if (widget.availableAssignees == null ||
        widget.availableAssignees!.isEmpty) {
      return;
    }

    final assignees = widget.availableAssignees!;
    final currentAssigneeId = _selectedAssigneeIds.isEmpty
        ? null
        : _selectedAssigneeIds.first;
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
                        _selectedAssigneeIds = {
                          assignees[selectedIndex]['id']!,
                        };
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

  /// TODO作成・更新実行
  void _createTodo() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('タイトルを入力してください')));
      return;
    }

    // 結果を返す（編集モード時はtodo_idも含める）
    Navigator.pop(context, {
      if (widget.existingTodo != null) 'todo_id': widget.existingTodo!.id,
      'title': title,
      'description': _descriptionController.text.trim(),
      'deadline': _selectedDeadline,
      'assignee_ids': _selectedAssigneeIds.toList(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return SlideTransition(
      position: _slideAnimation,
      child: GestureDetector(
        onTap: () {}, // シート内のタップが外側（バリア）に抜けないように
        child: Container(
          height: screenHeight * 0.7,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
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
                      Icons.add_task,
                      color: Theme.of(context).colorScheme.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.existingTodo != null ? 'TODO編集' : '新しいTODO',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (widget.fixedGroupName != null)
                            Text(
                              widget.fixedGroupName!,
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
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // コンテンツ（スクロール可能）
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    // タイトル入力
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'タイトル',
                        hintText: 'TODOのタイトルを入力',
                        prefixIcon: const Icon(Icons.title),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      autofocus: true,
                      textInputAction: TextInputAction.next,
                    ),

                    const SizedBox(height: 12),

                    // 説明入力
                    TextField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: '説明（任意）',
                        hintText: 'TODOの詳細を入力',
                        prefixIcon: const Icon(Icons.description),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      maxLines: 2,
                      textInputAction: TextInputAction.done,
                    ),

                    const SizedBox(height: 16),

                    // 期限設定
                    Text(
                      '期限',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _selectDeadline,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
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
                            Expanded(
                              child: Text(
                                _selectedDeadline != null
                                    ? DateFormat(
                                        'yyyy年MM月dd日（E）',
                                        'ja',
                                      ).format(_selectedDeadline!)
                                    : '期限なし',
                                style: TextStyle(
                                  color: _selectedDeadline != null
                                      ? Theme.of(context).colorScheme.onSurface
                                      : Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            // クリアボタンのスペースを常に確保（非表示時は透明）
                            SizedBox(
                              width: 40,
                              height: 40,
                              child: _selectedDeadline != null
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 20),
                                      onPressed: _clearDeadline,
                                      padding: EdgeInsets.zero,
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 担当者選択
                    if (widget.availableAssignees != null &&
                        widget.availableAssignees!.isNotEmpty) ...[
                      Text(
                        '担当者',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // グループに1人のみ：表示のみ（変更不可）
                      if (widget.availableAssignees!.length == 1)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.person,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                widget.availableAssignees!.first['name']!,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ],
                          ),
                        )
                      // グループに複数人：ピッカーで選択可能
                      else
                        InkWell(
                          onTap: _showAssigneePicker,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
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
                                  _selectedAssigneeIds.isEmpty
                                      ? '担当者を選択'
                                      : widget.availableAssignees!.firstWhere(
                                          (a) =>
                                              a['id'] ==
                                              _selectedAssigneeIds.first,
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
                      const SizedBox(height: 8),
                    ] else ...[
                      // MY TODO: 自分のみ固定（表示のみ）
                      Text(
                        '担当者',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
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
                            CircleAvatar(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              child: Icon(
                                Icons.person,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              widget.currentUserName,
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
                    ],

                    const SizedBox(height: 20),

                    // 作成・更新ボタン
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _createTodo,
                        icon: Icon(
                          widget.existingTodo != null ? Icons.edit : Icons.add,
                        ),
                        label: Text(widget.existingTodo != null ? '更新' : '作成'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
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
      ),
    );
  }
}
