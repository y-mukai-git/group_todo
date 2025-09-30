# Flutter Flavors 設定ガイド - グループTODO

## 概要

本アプリでは、Dev・Staging・Production 環境を区別するために Flutter Flavors を使用します。
各環境で独立したSupabaseプロジェクトを使用し、開発・検証・本番を完全に分離します。

## 環境設定

### 3つの環境
- **development (dev)**: 開発環境
  - Bundle ID: `com.grouptodo.dev`
  - アプリ名: `GroupTODO (DEV)`
  - Supabase: 開発用プロジェクト

- **staging (stg)**: ステージング環境
  - Bundle ID: `com.grouptodo.staging`
  - アプリ名: `GroupTODO (STG)`
  - Supabase: ステージング用プロジェクト

- **production (prod)**: 本番環境
  - Bundle ID: `com.grouptodo`
  - アプリ名: `GroupTODO`
  - Supabase: 本番用プロジェクト

## Android 設定

### build.gradle 設定

`android/app/build.gradle` にて Product Flavors を設定：

```gradle
android {
    // ...existing configuration...

    flavorDimensions "environment"

    productFlavors {
        development {
            dimension "environment"
            applicationId "com.grouptodo.dev"
            versionNameSuffix "-dev"
            resValue "string", "app_name", "GroupTODO (DEV)"
        }
        staging {
            dimension "environment"
            applicationId "com.grouptodo.staging"
            versionNameSuffix "-staging"
            resValue "string", "app_name", "GroupTODO (STG)"
        }
        production {
            dimension "environment"
            applicationId "com.grouptodo"
            resValue "string", "app_name", "GroupTODO"
        }
    }
}
```

### strings.xml の設定

`android/app/src/main/res/values/strings.xml` を以下のように修正：

```xml
<resources>
    <string name="app_name">@string/app_name</string>
</resources>
```

これにより、Flavor設定のresValueが使用されます。

## iOS 設定

### 1. Xcode での Configuration 作成

1. Xcode でプロジェクトを開く：
   ```bash
   open ios/Runner.xcworkspace
   ```

2. プロジェクト設定 > Info > Configurations

3. 既存の Debug・Release をそれぞれ複製して以下を作成：
   - Debug-Development
   - Debug-Staging
   - Debug-Production
   - Release-Development
   - Release-Staging
   - Release-Production

### 2. Build Settings でユーザー定義変数を追加

各Configuration に以下を設定（Build Settings > User-Defined）：

**Development:**
- `APP_DISPLAY_NAME` = `GroupTODO (DEV)`
- `PRODUCT_BUNDLE_IDENTIFIER` = `com.grouptodo.dev`

**Staging:**
- `APP_DISPLAY_NAME` = `GroupTODO (STG)`
- `PRODUCT_BUNDLE_IDENTIFIER` = `com.grouptodo.staging`

**Production:**
- `APP_DISPLAY_NAME` = `GroupTODO`
- `PRODUCT_BUNDLE_IDENTIFIER` = `com.grouptodo`

### 3. Info.plist の設定

`ios/Runner/Info.plist` でBundle IDとアプリ名を変数参照に変更：

```xml
<key>CFBundleIdentifier</key>
<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
<key>CFBundleDisplayName</key>
<string>$(APP_DISPLAY_NAME)</string>
```

### 4. Scheme の作成・設定

1. Product > Scheme > Manage Schemes

2. 各環境用の Scheme を作成：
   - Runner (Development)
   - Runner (Staging)
   - Runner (Production)

3. 各 Scheme の設定：
   - Run: 対応する Debug Configuration
   - Archive: 対応する Release Configuration

## 環境設定ファイル

### assets/config/environments.json

各環境のSupabase設定を管理：

```json
{
  "development": {
    "supabaseUrl": "https://your-dev-project.supabase.co",
    "supabaseAnonKey": "your-dev-anon-key"
  },
  "staging": {
    "supabaseUrl": "https://your-staging-project.supabase.co",
    "supabaseAnonKey": "your-staging-anon-key"
  },
  "production": {
    "supabaseUrl": "https://your-prod-project.supabase.co",
    "supabaseAnonKey": "your-prod-anon-key"
  }
}
```

### lib/core/config/environment_config.dart

環境設定を管理するシングルトンクラス：

```dart
import 'dart:convert';
import 'package:flutter/services.dart';

class EnvironmentConfig {
  static EnvironmentConfig? _instance;
  static EnvironmentConfig get instance => _instance!;

  final String environment;
  final String supabaseUrl;
  final String supabaseAnonKey;

  EnvironmentConfig._({
    required this.environment,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
  });

  static Future<void> initialize() async {
    const environment = String.fromEnvironment(
      'ENVIRONMENT',
      defaultValue: 'development',
    );

    final configString = await rootBundle.loadString(
      'assets/config/environments.json',
    );
    final config = json.decode(configString);
    final envConfig = config[environment];

    _instance = EnvironmentConfig._(
      environment: environment,
      supabaseUrl: envConfig['supabaseUrl'],
      supabaseAnonKey: envConfig['supabaseAnonKey'],
    );
  }

  String get appTitle {
    switch (environment) {
      case 'development':
        return 'GroupTODO (DEV)';
      case 'staging':
        return 'GroupTODO (STG)';
      case 'production':
        return 'GroupTODO';
      default:
        return 'GroupTODO';
    }
  }

  bool get isDevelopment => environment == 'development';
  bool get isStaging => environment == 'staging';
  bool get isProduction => environment == 'production';
}
```

## ビルド・実行コマンド

### VS Code での実行設定

`.vscode/launch.json` を作成：

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "GroupTODO (DEV)",
      "request": "launch",
      "type": "dart",
      "args": ["--dart-define=ENVIRONMENT=development", "--flavor", "development"]
    },
    {
      "name": "GroupTODO (STG)",
      "request": "launch",
      "type": "dart",
      "args": ["--dart-define=ENVIRONMENT=staging", "--flavor", "staging"]
    },
    {
      "name": "GroupTODO (PROD)",
      "request": "launch",
      "type": "dart",
      "args": ["--dart-define=ENVIRONMENT=production", "--flavor", "production"]
    }
  ]
}
```

### コマンドラインからの実行

#### Debug ビルド

```bash
# Development
flutter run --dart-define=ENVIRONMENT=development --flavor development

# Staging
flutter run --dart-define=ENVIRONMENT=staging --flavor staging

# Production
flutter run --dart-define=ENVIRONMENT=production --flavor production
```

#### Release ビルド

**Android:**

```bash
# APK ビルド（Development）
flutter build apk --dart-define=ENVIRONMENT=development --flavor development

# APK ビルド（Staging）
flutter build apk --dart-define=ENVIRONMENT=staging --flavor staging

# App Bundle ビルド（Production - Play Store 用）
flutter build appbundle --dart-define=ENVIRONMENT=production --flavor production
```

**iOS:**

```bash
# Xcode プロジェクトを開いてビルド
open ios/Runner.xcworkspace

# または、コマンドラインビルド
flutter build ipa --dart-define=ENVIRONMENT=development
flutter build ipa --dart-define=ENVIRONMENT=staging
flutter build ipa --dart-define=ENVIRONMENT=production
```

## Supabase プロジェクト設定

### 各環境でのSupabaseプロジェクト作成

1. **Development**: テスト・開発用
   - データの変更・削除が自由
   - 開発者のみアクセス

2. **Staging**: リリース前検証用
   - 本番環境に近い設定
   - テストユーザーでの動作確認

3. **Production**: 本番環境
   - 一般ユーザー向け
   - 厳格なセキュリティ設定

### 環境別のSupabase設定手順

1. Supabaseダッシュボードで各環境用のプロジェクトを作成
2. 各プロジェクトのURL・Anon Keyを取得
3. `assets/config/environments.json` に設定を記載
4. 各環境で同じデータベーススキーマを適用

## App Store・Play Store リリース

### Android (Google Play Console)

1. Production flavor でビルド：
   ```bash
   flutter build appbundle --dart-define=ENVIRONMENT=production --flavor production
   ```

2. `build/app/outputs/bundle/productionRelease/app-production-release.aab` をアップロード

### iOS (App Store Connect)

1. Xcode で Runner (Production) Scheme を選択
2. Product > Archive でアーカイブ作成
3. Xcode Organizer から App Store Connect へアップロード

## TestFlight 配信

### Staging 版の TestFlight 配信

1. iOS: Runner (Staging) Scheme でアーカイブ作成
2. 別の Bundle ID (`com.grouptodo.staging`) で TestFlight に配信
3. 本番環境に影響せず、テストユーザーに配信可能

## 環境判定の利用例

```dart
import 'package:group_todo/core/config/environment_config.dart';

// 現在の環境
String currentEnv = EnvironmentConfig.instance.environment; // "development", "staging", "production"

// 環境別の表示タイトル
String appTitle = EnvironmentConfig.instance.appTitle; // "GroupTODO (DEV)" など

// 環境判定
if (EnvironmentConfig.instance.isDevelopment) {
  // 開発環境のみの処理
  print('Development mode');
}

// Supabase接続情報
String supabaseUrl = EnvironmentConfig.instance.supabaseUrl;
String supabaseKey = EnvironmentConfig.instance.supabaseAnonKey;
```

## 利点

1. **環境完全分離**: 各環境が独立したデータベース・設定を持つ
2. **Bundle ID 分離**: 各環境のアプリが同時にインストール可能
3. **TestFlight 活用**: Staging 版を TestFlight で配信可能
4. **開発効率**: VS Code から簡単に環境切り替え可能
5. **CI/CD 対応**: GitHub Actions 等での自動ビルドに対応

## 注意事項

- iOS の Xcode Configuration・Scheme 設定は手動で行う必要があります
- Supabase プロジェクトも環境別に作成することを推奨
- 各環境の設定ファイルは適切に管理してください（.gitignoreに追加推奨）
- 本番環境のAPI Keyは厳重に管理してください

## トラブルシューティング

### Android で Flavor が認識されない

- `android/app/build.gradle` の `flavorDimensions` と `productFlavors` を確認
- `flutter clean` を実行後、再ビルド

### iOS で Bundle ID が切り替わらない

- Xcode の Build Settings で `PRODUCT_BUNDLE_IDENTIFIER` が正しく設定されているか確認
- Scheme の Configuration が正しく設定されているか確認

### 環境設定が読み込まれない

- `assets/config/environments.json` が `pubspec.yaml` の assets に追加されているか確認
- `EnvironmentConfig.initialize()` が main.dart で呼ばれているか確認

---

**最終更新日**: 2025-09-30