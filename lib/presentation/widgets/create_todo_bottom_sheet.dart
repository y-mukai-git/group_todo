import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// TODO作成ボトムシート
class CreateTodoBottomSheet extends StatefulWidget {
  final String? fixedGroupId; // グループID（常に固定）
  final String? fixedGroupName; // グループ名（表示用）
  final List<Map<String, String>>? availableAssignees; // 担当者候補リスト [{id, name}]
  final String currentUserId; // 現在のユーザーID

  const CreateTodoBottomSheet({
    super.key,
    this.fixedGroupId,
    this.fixedGroupName,
    this.availableAssignees,
    required this.currentUserId,
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
    // 初期状態：自分を担当者に設定
    _selectedAssigneeIds = {widget.currentUserId};

    // アニメーション設定
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1), // 画面下から
      end: Offset.zero, // 通常位置へ
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

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

  /// 期限選択ダイアログ
  Future<void> _selectDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDeadline ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 1),
    );

    if (picked != null) {
      setState(() {
        _selectedDeadline = picked;
      });
    }
  }

  /// 期限クリア
  void _clearDeadline() {
    setState(() {
      _selectedDeadline = null;
    });
  }

  /// TODO作成実行
  void _createTodo() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('タイトルを入力してください')),
      );
      return;
    }

    // 結果を返す
    Navigator.pop(context, {
      'title': title,
      'description': _descriptionController.text.trim(),
      'deadline': _selectedDeadline,
      'assignee_ids': _selectedAssigneeIds.toList(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: AnimatedPadding(
        padding: MediaQuery.of(context).viewInsets,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: Container(
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
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                // ハンドル
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

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
                              '新しいTODO',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            if (widget.fixedGroupName != null)
                              Text(
                                widget.fixedGroupName!,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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

                // コンテンツ
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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

                      const SizedBox(height: 16),

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
                        maxLines: 3,
                        textInputAction: TextInputAction.done,
                      ),

                      const SizedBox(height: 24),

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
                          padding: const EdgeInsets.all(16),
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
                                      ? DateFormat('yyyy年MM月dd日（E）', 'ja')
                                          .format(_selectedDeadline!)
                                      : '期限なし',
                                  style: TextStyle(
                                    color: _selectedDeadline != null
                                        ? Theme.of(context).colorScheme.onSurface
                                        : Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              if (_selectedDeadline != null)
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: _clearDeadline,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 担当者選択
                      if (widget.availableAssignees != null && widget.availableAssignees!.isNotEmpty) ...[
                        Text(
                          '担当者',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 8),
                        ...widget.availableAssignees!.map((assignee) {
                          final assigneeId = assignee['id']!;
                          final assigneeName = assignee['name']!;
                          final isSelected = _selectedAssigneeIds.contains(assigneeId);

                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedAssigneeIds.add(assigneeId);
                                } else {
                                  _selectedAssigneeIds.remove(assigneeId);
                                }
                              });
                            },
                            title: Text(assigneeName),
                            secondary: CircleAvatar(
                              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                              child: Text(
                                assigneeName.isNotEmpty ? assigneeName[0] : '?',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: EdgeInsets.zero,
                          );
                        }),
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
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                child: Icon(
                                  Icons.person,
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '自分',
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

                      const SizedBox(height: 32),

                      // 作成ボタン
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _createTodo,
                          icon: const Icon(Icons.add),
                          label: const Text('作成'),
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
      ),
      ),
    );
  }
}
