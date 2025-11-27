import 'package:flutter/material.dart';
import '../../core/constants/error_messages.dart';
import '../../core/utils/api_client.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../services/error_log_service.dart';
import '../../services/user_service.dart';
import 'error_dialog.dart';
import 'maintenance_dialog.dart';

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
  bool _isProcessing = false; // 連続タップ防止フラグ

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  /// エラーメッセージ表示
  void _showErrorSnackBar(String message) {
    SnackBarHelper.showErrorSnackBar(context, message);
  }

  /// パスワード設定実行
  Future<void> _setPassword() async {
    if (_isProcessing) return; // 連続タップ防止

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

    setState(() {
      _isProcessing = true;
    });

    try {
      final credentials = await _userService.setTransferPassword(
        userId: widget.userId,
        password: password,
      );

      if (!mounted) return;

      // 成功メッセージ表示
      SnackBarHelper.showSuccessSnackBar(context, 'パスワードを設定しました');

      // 成功時は認証情報を返す
      Navigator.pop(context, credentials);
    } catch (e, stackTrace) {
      debugPrint('[TransferPasswordBottomSheet] ❌ 引き継ぎ用パスワード設定エラー: $e');

      // メンテナンスモード時は MaintenanceDialog を表示
      if (e is MaintenanceException) {
        if (!mounted) return;
        await MaintenanceDialog.show(
          context: context,
          message: e.message, // api_client.dartで固定メッセージを生成済み
        );
        return;
      }

      // エラーログ記録
      final errorLog = await ErrorLogService().logError(
        userId: widget.userId,
        errorType: 'データ引き継ぎ設定エラー',
        errorMessage: ErrorMessages.transferPasswordSetFailed,
        stackTrace: '${e.toString()}\n${stackTrace.toString()}',
        screenName: 'データ引き継ぎ設定',
      );

      // エラーダイアログ表示
      if (!mounted) return;
      await ErrorDialog.show(
        context: context,
        errorId: errorLog.id,
        errorMessage: '${ErrorMessages.transferPasswordSetFailed}\n${ErrorMessages.retryLater}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: GestureDetector(
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
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
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

                  // コンテンツ
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(24),
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
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'データ引き継ぎについて',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
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
                            onPressed: _isProcessing ? null : _setPassword,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isProcessing
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text('設定'),
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
      },
    );
  }
}
