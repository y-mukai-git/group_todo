import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/models/user_model.dart';
import '../../services/user_service.dart';
import '../../core/config/environment_config.dart';

/// 設定画面
class SettingsScreen extends StatefulWidget {
  final UserModel user;

  const SettingsScreen({super.key, required this.user});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final UserService _userService = UserService();
  final EnvironmentConfig _config = EnvironmentConfig.instance;

  /// ユーザー名変更ダイアログ表示
  Future<void> _showChangeNameDialog() async {
    final TextEditingController controller = TextEditingController(
      text: widget.user.displayName,
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ユーザー名を変更'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'ユーザー名',
            hintText: 'ユーザー名を入力',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              final displayName = controller.text.trim();
              if (displayName.isNotEmpty) {
                Navigator.pop(context);
                _updateUserName(displayName);
              }
            },
            child: const Text('変更'),
          ),
        ],
      ),
    );

    controller.dispose();
  }

  /// ユーザー名更新実行
  Future<void> _updateUserName(String displayName) async {
    try {
      await _userService.updateUserProfile(
        userId: widget.user.id,
        displayName: displayName,
      );

      _showSuccessSnackBar('ユーザー名を変更しました');
    } catch (e) {
      debugPrint('[SettingsScreen] ❌ ユーザー名変更エラー: $e');
      _showErrorSnackBar('ユーザー名の変更に失敗しました');
    }
  }

  /// 引き継ぎ用パスワード設定
  Future<void> _setupTransferPassword() async {
    final TextEditingController passwordController = TextEditingController();
    final TextEditingController confirmController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('引き継ぎ用パスワード設定'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'データ引き継ぎ用のパスワードを設定してください（8文字以上）',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: 'パスワード',
                hintText: '8文字以上',
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmController,
              decoration: const InputDecoration(
                labelText: 'パスワード（確認）',
                hintText: '再度入力',
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              final password = passwordController.text;
              final confirm = confirmController.text;

              if (password.length < 8) {
                _showErrorSnackBar('パスワードは8文字以上で設定してください');
                return;
              }

              if (password != confirm) {
                _showErrorSnackBar('パスワードが一致しません');
                return;
              }

              Navigator.pop(context);
              _saveTransferPassword(password);
            },
            child: const Text('設定'),
          ),
        ],
      ),
    );

    passwordController.dispose();
    confirmController.dispose();
  }

  /// 引き継ぎ用パスワード保存
  Future<void> _saveTransferPassword(String password) async {
    try {
      final credentials = await _userService.setTransferPassword(
        userId: widget.user.id,
        password: password,
      );

      if (!mounted) return;
      _showTransferCredentialsDialog(
        credentials['display_id']!,
        credentials['password']!,
      );
    } catch (e) {
      debugPrint('[SettingsScreen] ❌ 引き継ぎ用パスワード設定エラー: $e');
      _showErrorSnackBar('パスワードの設定に失敗しました');
    }
  }

  /// 引き継ぎ情報ダイアログ表示
  void _showTransferCredentialsDialog(String displayId, String password) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('データ引き継ぎ情報'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('以下の情報を新しい端末で入力してください', textAlign: TextAlign.center),
              const SizedBox(height: 24),
              const Text(
                'ユーザーID（8桁）',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  displayId,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'パスワード',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  password,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(
                ClipboardData(text: 'ユーザーID: $displayId\nパスワード: $password'),
              );
              _showSuccessSnackBar('引き継ぎ情報をコピーしました');
            },
            child: const Text('コピー'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
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
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          // ユーザー情報セクション
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      child: Text(
                        widget.user.displayName.isNotEmpty
                            ? widget.user.displayName[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(fontSize: 32),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.user.displayName,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ユーザーID: ${widget.user.displayId}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // アカウント設定
          const ListTile(title: Text('アカウント'), dense: true),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('ユーザー名を変更'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showChangeNameDialog,
          ),
          ListTile(
            leading: const Icon(Icons.phone_android),
            title: const Text('データ引き継ぎ'),
            subtitle: const Text('他の端末にデータを移行'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _setupTransferPassword,
          ),

          const Divider(),

          // アプリ情報
          const ListTile(title: Text('アプリ情報'), dense: true),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('バージョン'),
            subtitle: const Text('1.0.0'),
          ),
          // 環境表示（dev/stgのみ、prodでは非表示）
          if (_config.environment != 'prod')
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('環境'),
              subtitle: Text(_config.appTitle),
            ),

          const Divider(),

          // その他
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('プライバシーポリシー'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              debugPrint('[SettingsScreen] プライバシーポリシー画面へ遷移');
            },
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('利用規約'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              debugPrint('[SettingsScreen] 利用規約画面へ遷移');
            },
          ),
        ],
      ),
    );
  }
}
