import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/models/todo_model.dart';
import '../../services/data_cache_service.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/utils/content_validator.dart';
import '../screens/content_policy_screen.dart';

/// タスク作成・編集ボトムシート
class CreateTodoBottomSheet extends StatefulWidget {
  final String? fixedGroupId; // グループID（常に固定）
  final String? fixedGroupName; // グループ名（表示用）
  final String? defaultGroupId; // グループID（デフォルト値、変更可能）
  final List<Map<String, String>>? availableAssignees; // 担当者候補リスト [{id, name}]
  final String currentUserId; // 現在のユーザーID
  final String currentUserName; // 現在のユーザー名（固定表示用）
  final TodoModel? existingTodo; // 編集モード時の既存TODOデータ

  const CreateTodoBottomSheet({
    super.key,
    this.fixedGroupId,
    this.fixedGroupName,
    this.defaultGroupId,
    this.availableAssignees,
    required this.currentUserId,
    required this.currentUserName,
    this.existingTodo, // 編集モード用
  });

  @override
  State<CreateTodoBottomSheet> createState() => _CreateTodoBottomSheetState();
}

class _CreateTodoBottomSheetState extends State<CreateTodoBottomSheet> {
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _groupDescriptionController =
      TextEditingController();

  DateTime? _selectedDeadline;
  Set<String> _selectedAssigneeIds = {}; // 選択された担当者IDのセット
  List<Map<String, String>> _availableAssignees = []; // 担当者候補リスト（動的）

  // グループ選択用（fixedGroupIdがnullの場合に使用）
  String? _selectedGroupId;
  bool _isCreatingNewGroup = false;
  String? _selectedCategory = 'none'; // デフォルト：未設定
  String? _selectedGroupImageBase64; // グループ画像（base64）

  // タブ管理
  int _currentTabIndex = 0; // 0: 必須, 1: オプション

  @override
  void initState() {
    super.initState();

    // 担当者候補リストを初期化
    _availableAssignees = widget.availableAssignees ?? [];

    // 編集モード時：既存TODOデータを初期値として設定
    if (widget.existingTodo != null) {
      _titleController.text = widget.existingTodo!.title;
      _descriptionController.text = widget.existingTodo!.description ?? '';
      _selectedDeadline = widget.existingTodo!.dueDate;
      // 担当者なし（null or 空配列）の場合は空のセット、指定ありの場合はそのまま
      final existingAssignees = widget.existingTodo!.assignedUserIds;
      if (existingAssignees != null && existingAssignees.isNotEmpty) {
        _selectedAssigneeIds = existingAssignees.toSet();
      } else {
        _selectedAssigneeIds = {}; // 担当者なし（全員に表示）
      }
    } else {
      // 新規作成モード：デフォルトは「指定なし」（全員に表示）
      _selectedAssigneeIds = {};

      // デフォルトグループが設定されている場合は初期値として設定
      if (widget.defaultGroupId != null) {
        _selectedGroupId = widget.defaultGroupId;
      } else {
        // グループが0件の場合は新規グループ作成モードをデフォルトに
        final groups = DataCacheService().groups;
        if (groups.isEmpty) {
          _isCreatingNewGroup = true;
          _groupNameController.text = 'マイタスク'; // デフォルトグループ名
        }
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _groupNameController.dispose();
    _groupDescriptionController.dispose();
    super.dispose();
  }

  /// グループ変更時に担当者候補リストを更新
  void _updateAvailableAssignees(String groupId) {
    final cacheService = DataCacheService();
    final membersData = cacheService.getGroupMembers(groupId);

    if (membersData != null && membersData['success'] == true) {
      final membersList = membersData['members'] as List<dynamic>;
      setState(() {
        _availableAssignees = membersList.map((m) {
          final memberId = m['id'] as String;
          final memberName = memberId == widget.currentUserId
              ? cacheService.currentUser!.displayName
              : m['display_name'] as String;
          return {'id': memberId, 'name': memberName};
        }).toList();
      });
    } else {
      // メンバー情報取得失敗時は空リスト
      setState(() {
        _availableAssignees = [];
      });
    }
  }

  /// グループ画像選択
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        final base64Image = base64Encode(bytes);
        final mimeType = pickedFile.mimeType ?? 'image/jpeg';

        setState(() {
          _selectedGroupImageBase64 = 'data:$mimeType;base64,$base64Image';
        });
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showErrorSnackBar(context, '画像の読み込みに失敗しました: $e');
      }
    }
  }

  /// グループ画像ソース選択ダイアログ
  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('画像を選択'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('ギャラリーから選択'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('カメラで撮影'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            if (_selectedGroupImageBase64 != null)
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('画像を削除'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _selectedGroupImageBase64 = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  /// 期限選択ピッカー表示
  Future<void> _selectDeadline() async {
    final now = DateTime.now();
    DateTime tempDate = _selectedDeadline ?? now;

    // minimumDateの計算：既存の期限が現在時刻より僅かに過去の場合でも編集可能にする
    final minimumDate =
        _selectedDeadline != null && _selectedDeadline!.isBefore(now)
        ? _selectedDeadline!
        : now;

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
                  minimumDate: minimumDate,
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
    // 「指定なし」を先頭に追加（担当者候補が空でも自分を含める）
    final assigneeOptions = [
      {'id': '', 'name': '指定なし（全員に表示）'},
      if (_availableAssignees.isNotEmpty)
        ..._availableAssignees
      else
        {'id': widget.currentUserId, 'name': widget.currentUserName},
    ];

    // 現在選択中のインデックスを計算
    int currentIndex;
    if (_selectedAssigneeIds.isEmpty) {
      currentIndex = 0; // 「指定なし」
    } else {
      final currentAssigneeId = _selectedAssigneeIds.first;
      currentIndex = assigneeOptions.indexWhere(
        (a) => a['id'] == currentAssigneeId,
      );
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
                      final selectedId = assigneeOptions[selectedIndex]['id']!;
                      setState(() {
                        if (selectedId.isEmpty) {
                          // 「指定なし」選択時は空のセット
                          _selectedAssigneeIds = {};
                        } else {
                          _selectedAssigneeIds = {selectedId};
                        }
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
                  children: assigneeOptions
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

  /// 作成先グループ名を取得
  String _getTargetGroupName() {
    if (widget.fixedGroupId != null) {
      return widget.fixedGroupName ?? 'グループ';
    }
    if (_isCreatingNewGroup) {
      return _groupNameController.text.isNotEmpty
          ? _groupNameController.text
          : 'マイタスク';
    }
    if (_selectedGroupId != null) {
      final cacheService = DataCacheService();
      final groups = cacheService.groups;
      final group = groups.firstWhere(
        (g) => g.id == _selectedGroupId,
        orElse: () => groups.first,
      );
      return group.name;
    }
    return 'グループ';
  }

  /// タスク作成・更新実行
  void _createTodo() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      SnackBarHelper.showErrorSnackBar(context, 'タイトルを入力してください');
      return;
    }

    // コンテンツバリデーション
    final validationError = ContentValidator.validate(title);
    if (validationError != null) {
      SnackBarHelper.showErrorSnackBar(context, validationError);
      return;
    }

    // グループ選択モードの場合、グループが選択されているかチェック
    if (widget.fixedGroupId == null) {
      if (!_isCreatingNewGroup && _selectedGroupId == null) {
        SnackBarHelper.showErrorSnackBar(context, 'グループを選択してください');
        return;
      }
      if (_isCreatingNewGroup && _groupNameController.text.trim().isEmpty) {
        SnackBarHelper.showErrorSnackBar(context, 'グループ名を入力してください');
        return;
      }
    }

    // 結果を返す（編集モード時はtodo_idも含める）
    Navigator.pop(context, {
      if (widget.existingTodo != null) 'todo_id': widget.existingTodo!.id,
      'title': title,
      'description': _descriptionController.text.trim(),
      'deadline': _selectedDeadline,
      'assignee_ids': _selectedAssigneeIds.toList(),
      // グループ選択モードの場合の情報
      if (widget.fixedGroupId == null) ...{
        'is_creating_new_group': _isCreatingNewGroup,
        if (!_isCreatingNewGroup) 'group_id': _selectedGroupId,
        if (_isCreatingNewGroup) ...{
          'group_name': _groupNameController.text.trim(),
          'group_description': _groupDescriptionController.text.trim(),
          'group_category': _selectedCategory,
          'group_image_data': _selectedGroupImageBase64,
        },
      },
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.existingTodo != null;

    return GestureDetector(
      onTap: () {
        // キーボードを閉じる
        FocusScope.of(context).unfocus();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ヘッダー（固定）
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
                          isEditMode ? 'TODO編集' : '新しいTODO',
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

            // タブ切り替え
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _currentTabIndex = 0;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _currentTabIndex == 0
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.edit_note,
                                size: 20,
                                color: _currentTabIndex == 0
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '基本',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: _currentTabIndex == 0
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.onPrimary
                                          : Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _currentTabIndex = 1;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _currentTabIndex == 1
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.tune,
                                size: 20,
                                color: _currentTabIndex == 1
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'オプション',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: _currentTabIndex == 1
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.onPrimary
                                          : Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // タブコンテンツ
            Expanded(
              child: _currentTabIndex == 0
                  ? _buildRequiredTab()
                  : _buildOptionalTab(),
            ),
          ],
        ),
      ),
    );
  }

  /// 必須タブ
  Widget _buildRequiredTab() {
    final isEditMode = widget.existingTodo != null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        // コンテンツポリシーリンク
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ContentPolicyScreen(),
                ),
              );
            },
            child: Text(
              '入力における注意事項',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // タイトル入力
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: 'タイトル',
            hintText: 'タスクのタイトルを入力',
            prefixIcon: const Icon(Icons.title),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          autofocus: false,
          textInputAction: TextInputAction.done,
          maxLength: 15,
        ),

        const SizedBox(height: 8),

        // 担当者選択
        Text(
          '担当者',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        // 担当者選択（常にピッカーで選択可能：「指定なし」+ メンバー一覧）
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
                  _selectedAssigneeIds.isEmpty ? Icons.group : Icons.person,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  _selectedAssigneeIds.isEmpty
                      ? '指定なし（全員に表示）'
                      : _availableAssignees.firstWhere(
                              (a) => a['id'] == _selectedAssigneeIds.first,
                              orElse: () => {'id': '', 'name': widget.currentUserName},
                            )['name'] ??
                            widget.currentUserName,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_drop_down,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 期限設定
        Text(
          '期限',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _selectDeadline,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outline),
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
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                // クリアボタン
                SizedBox(
                  width: 40,
                  height: 24,
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

        const SizedBox(height: 24),

        // グループ表示（編集モード以外、かつ固定グループがない場合）
        if (!isEditMode && widget.fixedGroupId == null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              '「${_getTargetGroupName()}」に作成します',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),

        // 作成・更新ボタン
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _createTodo,
            icon: Icon(isEditMode ? Icons.edit : Icons.add),
            label: Text(isEditMode ? '更新' : '作成'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// オプションタブ
  Widget _buildOptionalTab() {
    final isEditMode = widget.existingTodo != null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        // コンテンツポリシーリンク
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ContentPolicyScreen(),
                ),
              );
            },
            child: Text(
              '入力における注意事項',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 説明入力
        TextField(
          controller: _descriptionController,
          decoration: InputDecoration(
            labelText: '説明',
            hintText: 'タスクの詳細を入力',
            prefixIcon: const Icon(Icons.description),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          maxLines: 3,
          maxLength: 200,
          textInputAction: TextInputAction.done,
        ),

        const SizedBox(height: 16),

        // グループ選択（編集モード以外、かつ固定グループがない場合）
        if (!isEditMode && widget.fixedGroupId == null) ...[
          Text(
            'グループ',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _buildGroupSelector(),
          const SizedBox(height: 16),
          // 新規グループ作成時の入力項目
          if (_isCreatingNewGroup) ...[
            // グループアイコン画像選択
            Center(
              child: GestureDetector(
                onTap: _showImageSourceDialog,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      backgroundImage: _selectedGroupImageBase64 != null
                          ? MemoryImage(
                              base64Decode(
                                _selectedGroupImageBase64!.split(',')[1],
                              ),
                            )
                          : null,
                      child: _selectedGroupImageBase64 == null
                          ? Icon(
                              Icons.group,
                              size: 50,
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: Icon(
                          Icons.camera_alt,
                          size: 18,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _groupNameController,
              decoration: InputDecoration(
                labelText: 'グループ名',
                hintText: 'グループ名を入力',
                prefixIcon: const Icon(Icons.group),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _groupDescriptionController,
              decoration: InputDecoration(
                labelText: 'グループ説明（任意）',
                hintText: 'グループの説明を入力',
                prefixIcon: const Icon(Icons.description),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              maxLines: 2,
              maxLength: 200,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            _buildCategorySelector(),
            const SizedBox(height: 16),
          ],
        ],

        // 作成・更新ボタン
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _createTodo,
            icon: Icon(isEditMode ? Icons.edit : Icons.add),
            label: Text(isEditMode ? '更新' : '作成'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// グループ選択ピッカー表示
  void _showGroupPicker() {
    final cacheService = DataCacheService();
    final groups = cacheService.groups;

    // グループリスト（既存グループ + 新規作成）
    final groupItems = [
      ...groups.map((g) => {'id': g.id, 'name': g.name}),
      {'id': 'new', 'name': '新しいグループを作成'},
    ];

    // 現在選択されているインデックスを取得
    int currentIndex = 0;
    if (_isCreatingNewGroup) {
      currentIndex = groupItems.length - 1; // 「新しいグループを作成」
    } else if (_selectedGroupId != null) {
      currentIndex = groupItems.indexWhere(
        (item) => item['id'] == _selectedGroupId,
      );
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
                      final selectedItem = groupItems[selectedIndex];
                      setState(() {
                        if (selectedItem['id'] == 'new') {
                          _isCreatingNewGroup = true;
                          _selectedGroupId = null;
                          _availableAssignees = []; // 新規グループ作成時は担当者リストをクリア
                        } else {
                          _isCreatingNewGroup = false;
                          _selectedGroupId = selectedItem['id'];
                        }
                      });
                      // グループ変更時に担当者候補リストを更新
                      if (selectedItem['id'] != 'new') {
                        _updateAvailableAssignees(selectedItem['id']!);
                      }
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
                  children: groupItems
                      .map((item) => Center(child: Text(item['name']!)))
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
    final cacheService = DataCacheService();
    final groups = cacheService.groups;

    // 選択されているグループ名を取得
    String displayText;
    if (_isCreatingNewGroup) {
      displayText = '新しいグループを作成';
    } else if (_selectedGroupId != null) {
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
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  /// カテゴリ選択（カード形式）
  Widget _buildCategorySelector() {
    final categoryMap = {
      'none': {'name': '未設定', 'icon': Icons.label_off},
      'shopping': {'name': '買い物', 'icon': Icons.shopping_cart},
      'housework': {'name': '家事', 'icon': Icons.home},
      'work': {'name': '仕事', 'icon': Icons.work},
      'hobby': {'name': '趣味', 'icon': Icons.palette},
      'other': {'name': 'その他', 'icon': Icons.label},
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'タグ',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: categoryMap.entries.map((entry) {
            final isSelected = _selectedCategory == entry.key;
            return InkWell(
              onTap: () {
                setState(() {
                  _selectedCategory = entry.key;
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: (MediaQuery.of(context).size.width - 72) / 3,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      entry.value['icon'] as IconData,
                      color: isSelected
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.value['name'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
