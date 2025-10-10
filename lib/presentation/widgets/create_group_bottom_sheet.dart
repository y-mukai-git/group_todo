import 'package:flutter/material.dart';

/// グループ作成ボトムシート
class CreateGroupBottomSheet extends StatefulWidget {
  const CreateGroupBottomSheet({super.key});

  @override
  State<CreateGroupBottomSheet> createState() => _CreateGroupBottomSheetState();
}

class _CreateGroupBottomSheetState extends State<CreateGroupBottomSheet>
    with SingleTickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String? _selectedCategory = 'none'; // デフォルト：未設定

  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

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

  final Map<String, String> _categoryNames = {
    'none': '未設定',
    'shopping': '買い物',
    'housework': '家事',
    'work': '仕事',
    'hobby': '趣味',
    'other': 'その他',
  };

  final Map<String, IconData> _categoryIcons = {
    'none': Icons.label_off,
    'shopping': Icons.shopping_cart,
    'housework': Icons.home,
    'work': Icons.work,
    'hobby': Icons.palette,
    'other': Icons.label,
  };

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  /// グループ作成実行
  void _createGroup() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('グループ名を入力してください')));
      return;
    }

    // 結果を返す
    Navigator.pop(context, {
      'name': name,
      'description': _descriptionController.text.trim(),
      'category': _selectedCategory,
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return SlideTransition(
      position: _slideAnimation,
      child: GestureDetector(
        onTap: () {},
        child: Container(
          height: screenHeight - 100,
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
                      Icons.group_add,
                      color: Theme.of(context).colorScheme.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '新しいグループ',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
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
                    // グループ名入力
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'グループ名',
                        hintText: 'グループ名を入力',
                        prefixIcon: const Icon(Icons.group),
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
                        hintText: 'グループの説明を入力',
                        prefixIcon: const Icon(Icons.description),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      maxLines: 3,
                      textInputAction: TextInputAction.done,
                    ),

                    const SizedBox(height: 24),

                    // カテゴリ選択
                    Text(
                      'カテゴリ',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categoryNames.entries.map((entry) {
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
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer
                                  : Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
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
                                  _categoryIcons[entry.key],
                                  color: isSelected
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.onPrimaryContainer
                                      : Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  entry.value,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isSelected
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.onPrimaryContainer
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
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

                    const SizedBox(height: 32),

                    // 作成ボタン
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _createGroup,
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
    );
  }
}
