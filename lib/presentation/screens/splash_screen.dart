import 'package:flutter/material.dart';
import '../../core/utils/storage_helper.dart';
import '../../data/models/user_model.dart';
import '../../services/group_service.dart';
import 'main_tab_screen.dart';
import 'data_transfer_screen.dart';

/// スプラッシュ画面（初回起動・認証チェック）
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // アニメーション設定
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _animationController.forward();
    _initializeApp();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// アプリ初期化処理
  Future<void> _initializeApp() async {
    try {
      // SharedPreferencesからユーザーID取得（ローカルチェック）
      final savedUserId = await StorageHelper.getUserId();

      if (savedUserId != null) {
        // 既存ユーザー：ローカルに保存されたユーザーIDでメイン画面へ
        debugPrint('[SplashScreen] ✅ 既存ユーザー検出: $savedUserId');
        final savedDisplayName = await StorageHelper.getDisplayName();

        // 個人用グループID取得
        String? personalGroupId;
        try {
          final groups = await GroupService().getUserGroups(userId: savedUserId);
          final personalGroup = groups.firstWhere(
            (group) => group.name == '個人TODO',
            orElse: () => throw Exception('Personal group not found'),
          );
          personalGroupId = personalGroup.id;
          debugPrint('[SplashScreen] ✅ 個人用グループID取得: $personalGroupId');
        } catch (e) {
          debugPrint('[SplashScreen] ❌ 個人用グループID取得エラー: $e');
          // エラー時はnullのまま続行（後で再取得可能）
        }

        // ユーザーモデル作成（ローカル保存情報から復元）
        final user = UserModel(
          id: savedUserId,
          displayName: savedDisplayName ?? 'ユーザー',
          deviceId: '', // メイン画面では使わないので空でOK
          personalGroupId: personalGroupId,
          notificationDeadline: true, // デフォルト値
          notificationNewTodo: true, // デフォルト値
          notificationAssigned: true, // デフォルト値
          createdAt: DateTime.now(), // 正確な値は不要
          updatedAt: DateTime.now(), // 正確な値は不要
        );

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => MainTabScreen(user: user)),
        );
      } else {
        // 新規ユーザー：データ引き継ぎ画面へ（API呼び出し不要）
        debugPrint('[SplashScreen] ℹ️ 新規ユーザー（初回起動）');
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DataTransferScreen()),
        );
      }
    } catch (e) {
      debugPrint('[SplashScreen] ❌ 初期化エラー: $e');
      if (!mounted) return;
      _showErrorDialog();
    }
  }

  /// エラーダイアログ表示
  void _showErrorDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('エラー'),
        content: const Text('アプリの初期化に失敗しました。\nネットワーク接続を確認して、アプリを再起動してください。'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _initializeApp();
            },
            child: const Text('再試行'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color(0xFF2C3E50), // primaryColorと直接統一
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // アプリアイコン
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.checklist_rounded,
                      size: 80,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // アプリ名
                  Text(
                    'グループTODO',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.3),
                          offset: const Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'みんなで協力、タスク管理',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.9),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 48),
                  // ローディングインジケーター
                  CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
