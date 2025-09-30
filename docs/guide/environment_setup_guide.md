# 環境設定ガイド - グループTODO

## 概要

本ドキュメントでは、グループTODOアプリの開発環境構築手順を説明します。

## 前提条件

### 必須ツール

- **Flutter SDK**: 3.24以上
- **Dart SDK**: 3.2.5以上
- **Xcode**: 15.0以上（iOS開発の場合）
- **Android Studio**: 2023.1以上（Android開発の場合）
- **Git**: 2.40以上

### 推奨ツール

- **VS Code**: 最新版（Flutter拡張機能含む）
- **CocoaPods**: 1.14以上（iOS開発の場合）

## 開発環境セットアップ

### 1. リポジトリのクローン

```bash
git clone [repository-url]
cd group_todo
```

### 2. Flutter依存関係のインストール

```bash
flutter pub get
```

### 3. 環境設定ファイルの準備

#### assets/config/environments.json の作成

```bash
# テンプレートファイルをコピー（将来的に用意）
cp assets/config/environments.json.template assets/config/environments.json
```

または、以下の内容で新規作成：

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

**注意**: このファイルは `.gitignore` に追加し、リポジトリにコミットしないでください。

### 4. Android設定

#### build.gradle の Flavor 設定確認

`android/app/build.gradle` が正しく設定されているか確認：

```gradle
android {
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

### 5. iOS設定

#### CocoaPodsのインストール

```bash
cd ios
pod install
cd ..
```

#### Xcode Configuration の設定

詳細は `docs/guide/flutter_flavors_setup_guide.md` を参照してください。

1. Xcode で `ios/Runner.xcworkspace` を開く
2. Configuration を作成（Debug-Development, Debug-Staging, etc.）
3. Build Settings でユーザー定義変数を追加
4. Scheme を環境別に作成

### 6. VS Code Launch設定

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

## Supabaseプロジェクト設定

### 1. Supabaseアカウント作成

1. [Supabase](https://supabase.com/) にアクセス
2. アカウント登録（GitHubアカウント連携推奨）

### 2. プロジェクト作成

各環境ごとにプロジェクトを作成：

1. **Development**: `group-todo-dev`
2. **Staging**: `group-todo-staging`
3. **Production**: `group-todo-prod`

### 3. 認証設定

各プロジェクトで以下を設定：

1. Authentication > Providers
2. Anonymous Sign-In を有効化
3. Email Authentication を無効化（デバイスベース認証のため）

### 4. データベーススキーマ適用

```bash
# SQL Editorで以下のファイルを実行
database/schema/01_create_tables.sql
```

または、Supabase CLI を使用：

```bash
supabase db push
```

### 5. Row Level Security (RLS) の設定

各テーブルにRLSポリシーを適用：

```sql
-- usersテーブルのRLS例
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own data"
  ON users FOR SELECT
  USING (auth.uid()::text = id);

CREATE POLICY "Users can update their own data"
  ON users FOR UPDATE
  USING (auth.uid()::text = id);
```

詳細は `database/schema/` のSQLファイルを参照してください。

### 6. API Key の取得

1. Settings > API
2. `anon` `public` key をコピー
3. Project URL をコピー
4. `assets/config/environments.json` に設定

## 動作確認

### 1. 依存関係の確認

```bash
flutter doctor -v
```

すべての項目が✓であることを確認してください。

### 2. アプリの起動

```bash
# Development環境で起動
flutter run --dart-define=ENVIRONMENT=development --flavor development
```

または、VS Code の Debug メニューから `GroupTODO (DEV)` を選択して起動。

### 3. Supabase接続確認

アプリ起動後、Supabaseへの接続が成功していることを確認：

- ログにエラーが出ていないこと
- 匿名認証が完了していること

## 開発ワークフロー

### 日常的な開発

1. **開発環境で作業**
   ```bash
   flutter run --dart-define=ENVIRONMENT=development --flavor development
   ```

2. **ホットリロードで動作確認**
   - 変更を保存後、`r` キーでホットリロード

3. **コード品質チェック**
   ```bash
   flutter analyze
   dart format .
   ```

### ステージング環境でのテスト

1. **ステージング環境で起動**
   ```bash
   flutter run --dart-define=ENVIRONMENT=staging --flavor staging
   ```

2. **実機でのテスト**
   - iOS: TestFlight配信
   - Android: 内部テストトラック配信

### 本番環境へのリリース

1. **リリースビルド**
   ```bash
   # Android
   flutter build appbundle --dart-define=ENVIRONMENT=production --flavor production

   # iOS
   flutter build ipa --dart-define=ENVIRONMENT=production
   ```

2. **App Store / Play Store へアップロード**

## トラブルシューティング

### Flutter Doctor でエラーが出る

```bash
# Flutterの再インストール
flutter upgrade

# 依存関係の再取得
flutter pub get
flutter clean
```

### CocoaPods でエラーが出る

```bash
cd ios
pod deintegrate
pod install
cd ..
```

### Android ビルドエラー

```bash
# Gradleキャッシュのクリア
cd android
./gradlew clean
cd ..

# Flutterのクリーン
flutter clean
flutter pub get
```

### Supabase接続エラー

1. `assets/config/environments.json` のURL・Keyが正しいか確認
2. Supabaseプロジェクトが稼働しているか確認
3. ネットワーク接続を確認

### Flavor が認識されない

1. Android: `android/app/build.gradle` を確認
2. iOS: Xcode の Configuration・Scheme を確認
3. `flutter clean` を実行後、再ビルド

## 開発時の注意事項

### gitignore設定

以下のファイルは `.gitignore` に追加：

```
# 環境設定ファイル
assets/config/environments.json

# ビルド成果物
build/
*.iml
.gradle/
.dart_tool/

# IDE設定（個人設定）
.vscode/settings.json
.idea/workspace.xml
```

### API Key管理

- 本番環境のAPI Keyは厳重に管理
- GitHubなどにコミットしない
- 定期的にローテーション

### データベース変更

- マイグレーションファイルとして管理
- `database/schema/` に変更履歴を記録
- 環境ごとに同じスキーマを適用

## 参考資料

- [Flutter公式ドキュメント](https://docs.flutter.dev/)
- [Supabase公式ドキュメント](https://supabase.com/docs)
- [Flutter Flavors設定ガイド](./flutter_flavors_setup_guide.md)

---

**最終更新日**: 2025-09-30