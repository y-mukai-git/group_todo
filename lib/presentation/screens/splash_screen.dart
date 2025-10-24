import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/utils/storage_helper.dart';
import '../../data/models/user_model.dart';
import '../../services/app_status_service.dart';
import '../../services/data_cache_service.dart';
import '../../services/error_log_service.dart';
import '../../services/user_service.dart';
import '../widgets/error_dialog.dart';
import 'main_tab_screen.dart';
import 'data_transfer_screen.dart';

/// スプラッシュ画面（初回起動・認証チェック）
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
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
      // アプリ状態チェック（メンテナンス・強制アップデート）
      final appStatus = await AppStatusService().checkAppStatus();

      // メンテナンス中チェック
      if (appStatus.maintenance.isMaintenance) {
        if (!mounted) return;
        await _showMaintenanceDialog(
          appStatus.maintenance.message ?? 'システムメンテナンス中です',
        );
        return;
      }

      // 強制アップデートチェック
      if (appStatus.forceUpdate.required) {
        if (!mounted) return;
        await _showForceUpdateDialog(
          message: appStatus.forceUpdate.message ?? '新しいバージョンへのアップデートが必要です',
          storeUrl: appStatus.forceUpdate.storeUrl,
        );
        return;
      }

      // SharedPreferencesからユーザーID取得（ローカルチェック）
      final savedUserId = await StorageHelper.getUserId();

      if (savedUserId != null) {
        // 既存ユーザー：APIから最新のユーザー情報を取得

        // APIから最新のユーザー情報と署名付きURLを取得
        final userResponse = await UserService().getUserByDevice();

        if (userResponse == null) {
          // ユーザーが見つからない場合はデータ引き継ぎ画面へ
          debugPrint('[SplashScreen] ⚠️ ユーザーが見つかりません');
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DataTransferScreen()),
          );
          return;
        }

        final user = userResponse['user'] as UserModel;
        final signedAvatarUrl = userResponse['signed_avatar_url'] as String?;

        // キャッシュ初期化（全データ取得）
        debugPrint('[SplashScreen] 📦 キャッシュ初期化開始');
        await DataCacheService().initializeCache(
          user,
          signedAvatarUrl: signedAvatarUrl,
        );

        // 未送信エラーログの再送信
        debugPrint('[SplashScreen] 📤 未送信エラーログ再送信開始');
        await ErrorLogService().sendPendingErrors();

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
    } catch (e, stackTrace) {
      debugPrint('[SplashScreen] ❌ 初期化エラー: $e');

      // エラーログ記録
      final errorLog = await ErrorLogService().logError(
        userId: null, // 初期化失敗時はユーザーIDなし
        errorType: 'アプリ初期化エラー',
        errorMessage: e.toString(),
        stackTrace: stackTrace.toString(),
        screenName: 'スプラッシュ画面',
      );

      // エラーダイアログ表示
      if (!mounted) return;
      await ErrorDialog.show(
        context: context,
        errorId: errorLog.id,
        errorMessage: 'アプリの初期化に失敗しました',
      );
    }
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
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
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
                          color: Colors.black.withValues(alpha: 0.3),
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
                      color: Colors.white.withValues(alpha: 0.9),
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

  /// メンテナンスダイアログ表示
  Future<void> _showMaintenanceDialog(String message) async {
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

  /// 強制アップデートダイアログ表示
  Future<void> _showForceUpdateDialog({
    required String message,
    required String? storeUrl,
  }) async {
    // storeUrlがnull/空の場合はシステムエラー
    if (storeUrl == null || storeUrl.isEmpty) {
      debugPrint('[SplashScreen] ❌ 強制アップデート必須だがストアURLが未設定');

      // エラーログ記録
      final errorLog = await ErrorLogService().logError(
        userId: null,
        errorType: '強制アップデートURL未設定エラー',
        errorMessage: '強制アップデートが必要ですが、ストアURLが設定されていません',
        stackTrace: null,
        screenName: 'スプラッシュ画面',
      );

      // システムエラーダイアログ表示
      if (!mounted) return;
      await ErrorDialog.show(
        context: context,
        errorId: errorLog.id,
        errorMessage: 'アップデート情報の取得に失敗しました',
      );
      return;
    }

    // ストアURLが有効な場合はアップデートダイアログ表示
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            icon: Icon(
              Icons.system_update,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: const Text('アップデートが必要です'),
            content: Text(message),
            actions: [
              FilledButton.icon(
                onPressed: () async {
                  final url = Uri.parse(storeUrl);
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } else {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('ストアを開けませんでした'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.download),
                label: const Text('アップデートする'),
              ),
            ],
          ),
        );
      },
    );
  }
}
