import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'core/config/environment_config.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/themes/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Flavor環境取得（デフォルトはdevelopment）
  const environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  );

  debugPrint('[main] 🚀 アプリ起動開始: $environment 環境');

  // 環境設定初期化
  await EnvironmentConfig.instance.initialize(environment: environment);
  debugPrint('[main] ✅ 環境設定初期化完了');

  // AdMob初期化（広告有効時のみ）
  if (EnvironmentConfig.instance.enableAds) {
    await MobileAds.instance.initialize();
    debugPrint('[main] ✅ AdMob初期化完了');
  } else {
    debugPrint('[main] ⚠️ 広告機能無効（$environment環境）');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final config = EnvironmentConfig.instance;

    return MaterialApp(
      title: config.appTitle,
      debugShowCheckedModeBanner: config.isDebug,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
    );
  }
}
