import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/models/user_model.dart';
import '../../services/user_service.dart';
import '../../services/error_log_service.dart';
import 'error_dialog.dart';

/// プロフィール編集ボトムシート
class EditUserProfileBottomSheet extends StatefulWidget {
  final UserModel user;
  final String? currentSignedAvatarUrl;
  final VoidCallback onProfileUpdated;

  const EditUserProfileBottomSheet({
    super.key,
    required this.user,
    this.currentSignedAvatarUrl,
    required this.onProfileUpdated,
  });

  @override
  State<EditUserProfileBottomSheet> createState() =>
      _EditUserProfileBottomSheetState();
}

class _EditUserProfileBottomSheetState
    extends State<EditUserProfileBottomSheet> {
  final UserService _userService = UserService();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _nameController = TextEditingController();

  String? _selectedImageBase64;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.user.displayName;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// 画像選択（カメラ/ギャラリー）
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
          _selectedImageBase64 = 'data:$mimeType;base64,$base64Image';
        });
      }
    } catch (e, stackTrace) {
      debugPrint('[EditUserProfileBottomSheet] ❌ 画像選択エラー: $e');

      // エラーログ記録
      final errorLog = await ErrorLogService().logError(
        userId: widget.user.id,
        errorType: '画像選択エラー',
        errorMessage: e.toString(),
        stackTrace: stackTrace.toString(),
        screenName: 'プロフィール編集',
      );

      // エラーダイアログ表示
      if (!mounted) return;
      await ErrorDialog.show(
        context: context,
        errorId: errorLog.id,
        errorMessage: '画像の選択に失敗しました',
      );
    }
  }

  /// 画像選択ボタン表示
  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('画像を選択'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('カメラで撮影'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('ギャラリーから選択'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// プロフィール保存
  Future<void> _saveProfile() async {
    final displayName = _nameController.text.trim();

    if (displayName.isEmpty) {
      _showErrorSnackBar('ユーザー名を入力してください');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _userService.updateUserProfile(
        userId: widget.user.id,
        displayName: displayName,
        imageData: _selectedImageBase64,
      );

      if (!mounted) return;

      _showSuccessSnackBar('プロフィールを更新しました');
      widget.onProfileUpdated();
      Navigator.pop(context);
    } catch (e, stackTrace) {
      debugPrint('[EditUserProfileBottomSheet] ❌ プロフィール更新エラー: $e');

      // エラーログ記録
      final errorLog = await ErrorLogService().logError(
        userId: widget.user.id,
        errorType: 'プロフィール更新エラー',
        errorMessage: e.toString(),
        stackTrace: stackTrace.toString(),
        screenName: 'プロフィール編集',
      );

      // エラーダイアログ表示
      if (!mounted) return;
      await ErrorDialog.show(
        context: context,
        errorId: errorLog.id,
        errorMessage: 'プロフィールの更新に失敗しました',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 成功メッセージ表示
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ヘッダー
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            child: Row(
              children: [
                Icon(
                  Icons.person,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'プロフィール編集',
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
          const SizedBox(height: 24),

          // アバター画像
          GestureDetector(
            onTap: _showImageSourceDialog,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundImage: _selectedImageBase64 != null
                      ? MemoryImage(
                          base64Decode(_selectedImageBase64!.split(',')[1]),
                        )
                      : (widget.currentSignedAvatarUrl != null
                                ? NetworkImage(widget.currentSignedAvatarUrl!)
                                : null)
                            as ImageProvider?,
                  child:
                      (_selectedImageBase64 == null &&
                          widget.currentSignedAvatarUrl == null)
                      ? Text(
                          widget.user.displayName.isNotEmpty
                              ? widget.user.displayName[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(fontSize: 48),
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    radius: 18,
                    child: const Icon(
                      Icons.camera_alt,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ユーザー名入力
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'ユーザー名',
              hintText: 'ユーザー名を入力',
              border: OutlineInputBorder(),
            ),
            enabled: !_isLoading,
          ),
          const SizedBox(height: 24),

          // 保存ボタン
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isLoading ? null : _saveProfile,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('保存'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
