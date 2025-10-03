import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/user_model.dart';
import '../../data/models/todo_model.dart';
import '../../services/todo_service.dart';

/// TODO詳細画面
class TodoDetailScreen extends StatefulWidget {
  final UserModel user;
  final TodoModel todo;
  final List<Map<String, String>>? availableAssignees; // 担当者候補リスト

  const TodoDetailScreen({
    super.key,
    required this.user,
    required this.todo,
    this.availableAssignees,
  });

  @override
  State<TodoDetailScreen> createState() => _TodoDetailScreenState();
}

class _TodoDetailScreenState extends State<TodoDetailScreen> {
  final TodoService _todoService = TodoService();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late DateTime? _selectedDeadline;
  late Set<String> _selectedAssigneeIds;

  bool _isEditing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.todo.title);
    _descriptionController = TextEditingController(text: widget.todo.description ?? '');
    _selectedDeadline = widget.todo.dueDate;
    _selectedAssigneeIds = widget.todo.assignedUserIds?.toSet() ?? {widget.user.id};
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
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

  /// TODO更新実行
  Future<void> _updateTodo() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('タイトルを入力してください')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _todoService.updateTodo(
        userId: widget.user.id,
        todoId: widget.todo.id,
        title: title,
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        dueDate: _selectedDeadline,
        assignedUserIds: _selectedAssigneeIds.toList(),
      );

      if (!mounted) return;
      setState(() {
        _isEditing = false;
        _isLoading = false;
      });
      _showSuccessSnackBar('TODOを更新しました');
      Navigator.pop(context, true); // 更新完了を通知
    } catch (e) {
      debugPrint('[TodoDetailScreen] ❌ TODO更新エラー: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showErrorSnackBar('TODOの更新に失敗しました');
    }
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

  /// 成功メッセージ表示
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TODO詳細'),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
              tooltip: '編集',
            ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  // 元の値に戻す
                  _titleController.text = widget.todo.title;
                  _descriptionController.text = widget.todo.description ?? '';
                  _selectedDeadline = widget.todo.dueDate;
                  _selectedAssigneeIds = widget.todo.assignedUserIds?.toSet() ?? {widget.user.id};
                });
              },
              tooltip: 'キャンセル',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // タイトル
                  if (_isEditing)
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
                    )
                  else
                    Text(
                      widget.todo.title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),

                  const SizedBox(height: 24),

                  // 説明
                  Text(
                    '説明',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  if (_isEditing)
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
                      maxLines: 5,
                      textInputAction: TextInputAction.done,
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.todo.description?.isNotEmpty == true
                            ? widget.todo.description!
                            : '説明なし',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: widget.todo.description?.isNotEmpty == true
                                  ? Theme.of(context).colorScheme.onSurface
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // 期限
                  Text(
                    '期限',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  if (_isEditing)
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
                            // クリアボタンのスペースを常に確保
                            SizedBox(
                              width: 48,
                              height: 48,
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
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            color: Theme.of(context).colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            widget.todo.dueDate != null
                                ? DateFormat('yyyy年MM月dd日（E）', 'ja')
                                    .format(widget.todo.dueDate!)
                                : '期限なし',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),

                  // 担当者
                  Text(
                    '担当者',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  if (_isEditing && widget.availableAssignees != null && widget.availableAssignees!.isNotEmpty)
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
                    })
                  else
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
                        ],
                      ),
                    ),

                  if (_isEditing) ...[
                    const SizedBox(height: 32),
                    // 更新ボタン
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _updateTodo,
                        icon: const Icon(Icons.check),
                        label: const Text('更新'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
