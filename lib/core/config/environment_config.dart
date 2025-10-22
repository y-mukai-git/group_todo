import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// 環境設定管理クラス（Flavor対応）
/// assets/config/environments.json から各環境の設定を読み込み管理する
class EnvironmentConfig {
  static EnvironmentConfig? _instance;
  static EnvironmentConfig get instance => _instance ??= EnvironmentConfig._();

  EnvironmentConfig._();

  Map<String, dynamic>? _config;
  String? _currentEnvironment;

  /// 設定が初期化済みかどうか
  bool get isInitialized => _config != null;

  /// 現在の環境（development/staging/production）
  String get environment => _currentEnvironment ?? 'development';

  /// 環境設定の初期化
  Future<void> initialize({String environment = 'development'}) async {
    try {
      _currentEnvironment = environment;

      debugPrint('[EnvironmentConfig] 🔧 環境設定ファイル読み込み開始: $environment');

      String configString;
      try {
        configString = await rootBundle.loadString(
          'assets/config/environments.json',
        );
      } catch (loadError) {
        debugPrint('[EnvironmentConfig] ❌ 環境設定ファイル読み込みエラー: $loadError');
        rethrow;
      }

      final allConfigs = jsonDecode(configString) as Map<String, dynamic>;

      // 指定された環境の設定を取得
      if (!allConfigs.containsKey(environment)) {
        debugPrint('[EnvironmentConfig] ⚠️ 指定された環境設定が見つかりません: $environment');
        debugPrint(
          '[EnvironmentConfig] 🔍 利用可能な環境: ${allConfigs.keys.join(', ')}',
        );

        // developmentにフォールバック
        if (allConfigs.containsKey('development')) {
          _config = allConfigs['development'] as Map<String, dynamic>;
          _currentEnvironment = 'development';
        } else {
          throw Exception('デフォルト環境設定(development)も見つかりません: $environment');
        }
      } else {
        _config = allConfigs[environment] as Map<String, dynamic>;
      }

      debugPrint('[EnvironmentConfig] ✅ 環境設定初期化完了: $_currentEnvironment');
    } catch (e) {
      debugPrint('[EnvironmentConfig] ❌ 環境設定初期化エラー: $e');
      rethrow;
    }
  }

  // ========================================
  // アプリ基本設定
  // ========================================

  String get appName => _config?['app']?['name'] ?? 'GroupTODO';
  String get appTitle => _config?['app']?['title'] ?? 'GroupTODO';
  String get appVersion => _config?['app']?['version'] ?? '1.0.0';
  bool get isDebug => _config?['app']?['debug'] ?? kDebugMode;

  // ========================================
  // Supabase設定
  // ========================================

  String get supabaseUrl => _config?['supabase']?['url'] ?? '';
  String get supabaseAnonKey => _config?['supabase']?['anonKey'] ?? '';
  String get supabaseServiceRoleKey =>
      _config?['supabase']?['serviceRoleKey'] ?? '';
  String get supabaseProjectRef => _config?['supabase']?['projectRef'] ?? '';

  /// Supabase設定が完全に設定されているかチェック
  bool get isSupabaseConfigured {
    return supabaseUrl.isNotEmpty &&
        supabaseAnonKey.isNotEmpty &&
        supabaseServiceRoleKey.isNotEmpty;
  }

  // ========================================
  // AdMob設定
  // ========================================

  String get admobAppId {
    return defaultTargetPlatform == TargetPlatform.iOS
        ? (_config?['admob']?['appId']?['ios'] ?? '')
        : (_config?['admob']?['appId']?['android'] ?? '');
  }

  String get admobBannerId {
    return defaultTargetPlatform == TargetPlatform.iOS
        ? (_config?['admob']?['adUnitIds']?['ios']?['banner'] ?? '')
        : (_config?['admob']?['adUnitIds']?['android']?['banner'] ?? '');
  }

  // ========================================
  // 機能フラグ
  // ========================================

  bool get enableAds => _config?['features']?['enableAds'] ?? true;
  bool get enableAnalytics => _config?['features']?['enableAnalytics'] ?? false;
  bool get enableCrashlytics =>
      _config?['features']?['enableCrashlytics'] ?? false;

  // ========================================
  // デバッグ・ログ機能
  // ========================================

  /// 設定が適切に構成されているかチェック
  bool validateConfiguration() {
    final issues = <String>[];

    if (!isSupabaseConfigured) {
      issues.add('Supabase設定が不完全です');
    }

    if (enableAds && admobAppId.isEmpty) {
      issues.add('広告機能が有効ですがAdMob設定が不完全です');
    }

    if (issues.isNotEmpty) {
      debugPrint('[EnvironmentConfig] ⚠️ 設定検証エラー:');
      for (final issue in issues) {
        debugPrint('[EnvironmentConfig]    - $issue');
      }
      return false;
    }

    return true;
  }
}
