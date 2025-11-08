import 'package:flutter/material.dart';
import '../../services/user_service.dart';
import '../../services/error_log_service.dart';
import '../../services/data_cache_service.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/utils/storage_helper.dart';
import '../widgets/error_dialog.dart';
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

      // SharedPreferencesにユーザー情報を保存
      await StorageHelper.saveUserId(newUser.id);
      await StorageHelper.saveDisplayName(newUser.displayName);

      // キャッシュ初期化
      await DataCacheService().initializeCache(newUser);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MainTabScreen(user: newUser)),
      );
    } catch (e, stackTrace) {
      debugPrint('[DataTransferScreen] ❌ 新規ユーザー作成エラー: $e');

      // エラーログ記録
      final errorLog = await ErrorLogService().logError(
        userId: null, // 新規ユーザー作成失敗時はユーザーIDなし
        errorType: '新規ユーザー作成エラー',
        errorMessage: '新規ユーザーの作成に失敗しました',
        stackTrace: '${e.toString()}\n${stackTrace.toString()}',
        screenName: 'データ引き継ぎ画面',
      );

      // エラーダイアログ表示
      if (!mounted) return;
      await ErrorDialog.show(
        context: context,
        errorId: errorLog.id,
        errorMessage: 'ユーザー作成に失敗しました',
      );
      setState(() => _isLoading = false);
    }
  }

  /// データ引き継ぎ実行
  Future<void> _transferData() async {
    final userId = _userIdController.text.trim();
    final password = _passwordController.text.trim();

    if (userId.isEmpty || password.isEmpty) {
      SnackBarHelper.showErrorSnackBar(context, 'ユーザーIDとパスワードを入力してください');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await _userService.transferUserData(
        userId: userId,
        password: password,
      );

      // ユーザーエラー（ID/パスワード間違い）の場合
      if (user == null) {
        if (!mounted) return;
        SnackBarHelper.showErrorSnackBar(
          context,
          '入力のユーザID、パスワードのユーザ情報は見つかりませんでした',
        );
        setState(() => _isLoading = false);
        return;
      }

      // 成功時
      await StorageHelper.saveUserId(user.id);
      await StorageHelper.saveDisplayName(user.displayName);

      // キャッシュ初期化
      await DataCacheService().initializeCache(user);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MainTabScreen(user: user)),
      );
    } catch (e, stackTrace) {
      debugPrint('[DataTransferScreen] ❌ データ引き継ぎエラー: $e');

      // システムエラーの場合のみエラーログ記録 + ErrorDialog表示
      final errorLog = await ErrorLogService().logError(
        userId: null, // データ引き継ぎ失敗時はユーザーIDなし
        errorType: 'データ引き継ぎエラー',
        errorMessage: 'データの引き継ぎに失敗しました',
        stackTrace: '${e.toString()}\n${stackTrace.toString()}',
        screenName: 'データ引き継ぎ画面',
      );

      if (!mounted) return;
      await ErrorDialog.show(
        context: context,
        errorId: errorLog.id,
        errorMessage: 'データ引き継ぎに失敗しました',
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ようこそ'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
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
                  '家族やチーム、友人と一緒に\nタスクを共有・管理できるアプリです',
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
                        setState(
                          () => _isPasswordVisible = !_isPasswordVisible,
                        );
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

                const SizedBox(height: 32),

                // ローディング表示
                if (_isLoading)
                  const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
