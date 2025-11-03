import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../data/models/recurring_todo_model.dart';
import '../../services/recurring_todo_service.dart';
import '../../services/error_log_service.dart';
import 'error_dialog.dart';
import '../../core/utils/content_validator.dart';
import '../screens/content_policy_screen.dart';

/// 定期タスク作成・編集ボトムシート
class CreateRecurringTodoBottomSheet extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String userId;
  final List<Map<String, String>>? availableAssignees; // 担当者候補リスト [{id, name}]
  final RecurringTodoModel? existingRecurringTodo; // 編集モード時の既存データ

  const CreateRecurringTodoBottomSheet({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.userId,
    this.availableAssignees,
    this.existingRecurringTodo,
  });

  @override
  State<CreateRecurringTodoBottomSheet> createState() =>
      _CreateRecurringTodoBottomSheetState();
}

class _CreateRecurringTodoBottomSheetState
    extends State<CreateRecurringTodoBottomSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final RecurringTodoService _recurringTodoService = RecurringTodoService();

  String _selectedPattern = 'daily'; // daily, weekly, monthly
  Set<int> _selectedWeekdays = {}; // 0=日曜, 6=土曜
  int _selectedMonthDay = 1; // 1-31, -1=月末
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  Set<String> _selectedAssigneeIds = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    // 編集モード時：既存データを初期値として設定
    if (widget.existingRecurringTodo != null) {
      final existing = widget.existingRecurringTodo!;
      _titleController.text = existing.title;
      _descriptionController.text = existing.description ?? '';
      _selectedPattern = existing.recurrencePattern;

      if (existing.recurrenceDays != null) {
        if (existing.recurrencePattern == 'weekly') {
          _selectedWeekdays = existing.recurrenceDays!.toSet();
        } else if (existing.recurrencePattern == 'monthly') {
          _selectedMonthDay = existing.recurrenceDays!.first;
        }
      }

      // generationTime（HH:mm:ss）をTimeOfDayに変換
      final timeParts = existing.generationTime.split(':');
      _selectedTime = TimeOfDay(
        hour: int.parse(timeParts[0]),
        minute: int.parse(timeParts[1]),
      );

      _selectedAssigneeIds = existing.assignedUserIds?.toSet() ?? {};
    } else {
      // 新規作成モード：自分を担当者に設定
      _selectedAssigneeIds = {widget.userId};
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// 繰り返しパターン選択ピッカー表示
  void _showPatternPicker() {
    final patterns = ['daily', 'weekly', 'monthly'];
    final labels = ['毎日', '毎週', '毎月'];
    final currentIndex = patterns.indexOf(_selectedPattern);

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
                      _selectedPattern = patterns[index];
                    });
                  },
                  children: labels
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

  /// 時刻選択ピッカー表示
  void _showTimePicker() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        int selectedHour = _selectedTime.hour;
        int selectedMinute = _selectedTime.minute;

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
                        _selectedTime = TimeOfDay(
                          hour: selectedHour,
                          minute: selectedMinute,
                        );
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('完了'),
                  ),
                ],
              ),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoPicker(
                        itemExtent: 40,
                        scrollController: FixedExtentScrollController(
                          initialItem: _selectedTime.hour,
                        ),
                        onSelectedItemChanged: (index) {
                          selectedHour = index;
                        },
                        children: List.generate(
                          24,
                          (index) => Center(child: Text('$index')),
                        ),
                      ),
                    ),
                    const Text(':', style: TextStyle(fontSize: 20)),
                    Expanded(
                      child: CupertinoPicker(
                        itemExtent: 40,
                        scrollController: FixedExtentScrollController(
                          initialItem: _selectedTime.minute,
                        ),
                        onSelectedItemChanged: (index) {
                          selectedMinute = index;
                        },
                        children: List.generate(
                          60,
                          (index) => Center(
                            child: Text(index.toString().padLeft(2, '0')),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
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

  /// 定期タスク作成・更新実行
  Future<void> _saveTodo() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('タイトルを入力してください'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // コンテンツバリデーション
    final validationError = ContentValidator.validate(title);
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError), backgroundColor: Colors.red),
      );
      return;
    }

    // パターン別のバリデーション
    if (_selectedPattern == 'weekly' && _selectedWeekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('曜日を選択してください'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // recurrence_days準備
      List<int>? recurrenceDays;
      if (_selectedPattern == 'weekly') {
        recurrenceDays = _selectedWeekdays.toList()..sort();
      } else if (_selectedPattern == 'monthly') {
        recurrenceDays = [_selectedMonthDay];
      }

      // generation_time（HH:mm:ss形式）
      final generationTime =
          '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}:00';

      if (widget.existingRecurringTodo != null) {
        // 更新モード
        await _recurringTodoService.updateRecurringTodo(
          userId: widget.userId,
          recurringTodoId: widget.existingRecurringTodo!.id,
          title: title,
          description: _descriptionController.text.trim(),
          category: 'other',
          recurrencePattern: _selectedPattern,
          recurrenceDays: recurrenceDays,
          generationTime: generationTime,
          assignedUserIds: _selectedAssigneeIds.toList(),
        );
      } else {
        // 作成モード
        await _recurringTodoService.createRecurringTodo(
          userId: widget.userId,
          groupId: widget.groupId,
          title: title,
          description: _descriptionController.text.trim(),
          category: 'other',
          recurrencePattern: _selectedPattern,
          recurrenceDays: recurrenceDays,
          generationTime: generationTime,
          assignedUserIds: _selectedAssigneeIds.toList(),
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true); // 成功フラグを返す
    } catch (e, stackTrace) {
      debugPrint('[CreateRecurringTodoBottomSheet] ❌ エラー: $e');

      // エラーログ記録
      final errorLog = await ErrorLogService().logError(
        userId: widget.userId,
        errorType: widget.existingRecurringTodo != null
            ? '定期タスク更新エラー'
            : '定期タスク作成エラー',
        errorMessage: e.toString(),
        stackTrace: stackTrace.toString(),
        screenName: '定期タスク作成・編集',
      );

      // エラーダイアログ表示
      if (!mounted) return;
      await ErrorDialog.show(
        context: context,
        errorId: errorLog.id,
        errorMessage: '定期タスクの保存に失敗しました',
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
                        Icons.repeat,
                        color: Theme.of(context).colorScheme.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.existingRecurringTodo != null
                                  ? '定期TODO編集'
                                  : '定期タスク作成',
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
                            'コンテンツポリシー',
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

                      // タイトル入力
                      TextField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: 'タイトル',
                          hintText: '定期タスクのタイトルを入力',
                          prefixIcon: const Icon(Icons.title),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        autofocus: false,
                        textInputAction: TextInputAction.next,
                        maxLength: 15,
                      ),

                      const SizedBox(height: 12),

                      // 説明入力
                      TextField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          labelText: '説明（任意）',
                          hintText: 'タスクの詳細を入力',
                          prefixIcon: const Icon(Icons.description),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        maxLines: 2,
                        textInputAction: TextInputAction.done,
                      ),

                      const SizedBox(height: 16),

                      // 繰り返しパターン選択
                      Text(
                        '繰り返しパターン',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _showPatternPicker,
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
                                Icons.repeat,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _selectedPattern == 'daily'
                                    ? '毎日'
                                    : _selectedPattern == 'weekly'
                                    ? '毎週'
                                    : '毎月',
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

                      // 曜日選択（weeklyの場合のみ）
                      if (_selectedPattern == 'weekly') ...[
                        const SizedBox(height: 8),
                        Text(
                          '曜日選択',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (int i = 0; i < 7; i++)
                              FilterChip(
                                label: Text(
                                  ['日', '月', '火', '水', '木', '金', '土'][i],
                                ),
                                selected: _selectedWeekdays.contains(i),
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedWeekdays.add(i);
                                    } else {
                                      _selectedWeekdays.remove(i);
                                    }
                                  });
                                },
                              ),
                          ],
                        ),
                      ],

                      // 日付選択（monthlyの場合のみ）
                      if (_selectedPattern == 'monthly') ...[
                        const SizedBox(height: 8),
                        Text(
                          '日付選択',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          initialValue: _selectedMonthDay,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: [
                            ...List.generate(31, (index) => index + 1).map(
                              (day) => DropdownMenuItem(
                                value: day,
                                child: Text('$day日'),
                              ),
                            ),
                            const DropdownMenuItem(
                              value: -1,
                              child: Text('月末'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedMonthDay = value;
                              });
                            }
                          },
                        ),
                      ],

                      const SizedBox(height: 16),

                      // 生成時刻選択
                      Text(
                        '生成時刻',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _showTimePicker,
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
                                Icons.access_time,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                                style: Theme.of(context).textTheme.bodyLarge,
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
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
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
                          )
                        // グループに複数人：ピッカーで選択可能
                        else
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
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
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
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge,
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
                      ],

                      const SizedBox(height: 20),

                      // 保存ボタン
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isLoading ? null : _saveTodo,
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
                                  widget.existingRecurringTodo != null
                                      ? Icons.edit
                                      : Icons.add,
                                ),
                          label: Text(
                            widget.existingRecurringTodo != null ? '更新' : '作成',
                          ),
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
        );
      },
    );
  }
}
