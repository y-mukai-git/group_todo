import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// メンテナンスダイアログ
class MaintenanceDialog {
  /// メンテナンスダイアログを表示
  static Future<void> show({
    required BuildContext context,
    required String message,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.build, color: Colors.orange),
                SizedBox(width: 8),
                Text('メンテナンス中'),
              ],
            ),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () {
                  SystemNavigator.pop(); // アプリ終了
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      },
    );
  }
}
