import 'package:flutter/material.dart';
import '../../services/user_service.dart';

/// データ引き継ぎ用パスワード設定ボトムシート
class TransferPasswordBottomSheet extends StatefulWidget {
  final String userId;

  const TransferPasswordBottomSheet({super.key, required this.userId});

  @override
  State<TransferPasswordBottomSheet> createState() =>
      _TransferPasswordBottomSheetState();
}

class _TransferPasswordBottomSheetState
    extends State<TransferPasswordBottomSheet> {
  final UserService _userService = UserService();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
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

  /// パスワード設定実行
  Future<void> _setPassword() async {
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (password.length < 8) {
      _showErrorSnackBar('パスワードは8文字以上で設定してください');
      return;
    }

    if (password != confirm) {
      _showErrorSnackBar('パスワードが一致しません');
      return;
    }

    try {
      final credentials = await _userService.setTransferPassword(
        userId: widget.userId,
        password: password,
      );

      if (!mounted) return;

      // 成功時は認証情報を返す
      Navigator.pop(context, credentials);
    } catch (e) {
      debugPrint('[TransferPasswordBottomSheet] ❌ 引き継ぎ用パスワード設定エラー: $e');
      _showErrorSnackBar('パスワードの設定に失敗しました');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        height: screenHeight * 0.7,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // ヘッダー
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Row(
                children: [
                  Icon(
                    Icons.phone_android,
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'データ引き継ぎ設定',
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

            // コンテンツ
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 説明
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 20,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'データ引き継ぎについて',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '新しい端末でデータを引き継ぐには、ユーザーID（8桁）とパスワードの両方が必要です。',
                            style: TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'パスワード設定後に表示される情報を必ず控えておいてください。',
                            style: TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // パスワード入力
                    TextField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'パスワード',
                        hintText: '8文字以上',
                        prefixIcon: Icon(Icons.lock),
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                    ),

                    const SizedBox(height: 16),

                    // パスワード確認入力
                    TextField(
                      controller: _confirmController,
                      decoration: const InputDecoration(
                        labelText: 'パスワード（確認）',
                        hintText: '再度入力',
                        prefixIcon: Icon(Icons.lock),
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                    ),

                    const SizedBox(height: 24),

                    // 設定ボタン
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _setPassword,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('設定'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
