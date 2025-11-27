import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/utils/snackbar_helper.dart';

/// システムエラーダイアログ
class ErrorDialog extends StatelessWidget {
  final String errorId;
  final String? errorMessage;
  final bool canDismiss;

  const ErrorDialog({
    super.key,
    required this.errorId,
    this.errorMessage,
    this.canDismiss = true,
  });

  /// エラーダイアログ表示
  static Future<void> show({
    required BuildContext context,
    required String errorId,
    String? errorMessage,
    bool canDismiss = true,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ErrorDialog(
        errorId: errorId,
        errorMessage: errorMessage,
        canDismiss: canDismiss,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Icon(
        Icons.error_outline,
        size: 64,
        color: Theme.of(context).colorScheme.error,
      ),
      title: const Text('エラーが発生しました'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'システムエラーが発生しました。\nシステム管理者にお問い合わせください。',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            const Text(
              'エラーID',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      errorId,
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: errorId));
                      SnackBarHelper.showSuccessSnackBar(
                        context,
                        'エラーIDをコピーしました',
                        duration: const Duration(seconds: 2),
                      );
                    },
                    tooltip: 'コピー',
                  ),
                ],
              ),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 16),
              const Text(
                '詳細',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  errorMessage!,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: canDismiss
          ? [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('閉じる'),
              ),
            ]
          : null,
    );
  }
}
