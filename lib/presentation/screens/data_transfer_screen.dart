import 'package:flutter/material.dart';
import '../../services/user_service.dart';
import '../../core/utils/storage_helper.dart';
import 'main_tab_screen.dart';

/// データ引き継ぎ画面（初回起動時のみ表示）
class DataTransferScreen extends StatefulWidget {
  const DataTransferScreen({super.key});

  @override
  State<DataTransferScreen> createState() => _DataTransferScreenState();
}

class _DataTransferScreenState extends State<DataTransferScreen> {
  final UserService _userService = UserService();
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _userIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// 新規ユーザー作成
  Future<void> _createNewUser() async {
    setState(() => _isLoading = true);

    try {
      final newUser = await _userService.createUser();
      debugPrint('[DataTransferScreen] 新規ユーザー作成: ${newUser.displayName}');

      // SharedPreferencesにユーザー情報を保存
      await StorageHelper.saveUserId(newUser.id);
      await StorageHelper.saveDisplayName(newUser.displayName);
      debugPrint('[DataTransferScreen] ✅ ユーザー情報をローカル保存完了');

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MainTabScreen(user: newUser)),
      );
    } catch (e) {
      debugPrint('[DataTransferScreen] ❌ 新規ユーザー作成エラー: $e');
      if (!mounted) return;
      _showErrorSnackBar('ユーザー作成に失敗しました');
      setState(() => _isLoading = false);
    }
  }

  /// データ引き継ぎ実行
  Future<void> _transferData() async {
    final userId = _userIdController.text.trim();
    final password = _passwordController.text.trim();

    if (userId.isEmpty || password.isEmpty) {
      _showErrorSnackBar('ユーザーIDとパスワードを入力してください');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await _userService.transferUserData(
        userId: userId,
        password: password,
      );
      debugPrint('[DataTransferScreen] データ引き継ぎ成功: ${user.displayName}');

      // SharedPreferencesにユーザー情報を保存
      await StorageHelper.saveUserId(user.id);
      await StorageHelper.saveDisplayName(user.displayName);
      debugPrint('[DataTransferScreen] ✅ 引き継ぎユーザー情報をローカル保存完了');

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MainTabScreen(user: user)),
      );
    } catch (e) {
      debugPrint('[DataTransferScreen] ❌ データ引き継ぎエラー: $e');
      if (!mounted) return;
      _showErrorSnackBar('ユーザーIDまたはパスワードが正しくありません');
      setState(() => _isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ようこそ'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              // アプリ説明
              Text(
                'グループTODOへようこそ',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                '家族やチーム、友人と一緒に\nTODOを共有・管理できるアプリです',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // 新規ユーザー作成ボタン
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _createNewUser,
                icon: const Icon(Icons.person_add),
                label: const Text('新規ユーザーとして始める'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),

              const SizedBox(height: 32),

              // 区切り線
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'または',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),

              const SizedBox(height: 32),

              // データ引き継ぎセクション
              Text(
                'データを引き継ぐ',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _userIdController,
                decoration: const InputDecoration(
                  labelText: 'ユーザーID',
                  hintText: 'ユーザーIDを入力',
                  prefixIcon: Icon(Icons.person),
                ),
                keyboardType: TextInputType.text,
                enabled: !_isLoading,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'パスワード',
                  hintText: 'パスワードを入力',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() => _isPasswordVisible = !_isPasswordVisible);
                    },
                  ),
                ),
                obscureText: !_isPasswordVisible,
                keyboardType: TextInputType.text,
                enabled: !_isLoading,
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _transferData,
                icon: const Icon(Icons.download),
                label: const Text('データを引き継ぐ'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),

              const Spacer(),

              // ローディング表示
              if (_isLoading) const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ),
    );
  }
}
