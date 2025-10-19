# グループTODO - Claude Code 開発仕様書

## 【最重要】開発ルール（絶対遵守）
### 🚨 絶対ルール（これだけ覚える）

**ユーザーから指示が来たら**：
**必ずWORK_CHECKLIST.mdを実行**（例外なし）これが最重要で絶対のルール

### 📋 チェックリスト実行の徹底（重要）

**チェックリスト確認時は必ず1つ1つ明示的に確認すること**：
- 「チェックリスト確認済み」と言うだけでは不十分
- WORK_CHECKLIST.mdの各項目を1つ1つ確認し、ユーザーに明示すること
- 「適当に見ただけ」「形式的に✅しただけ」は厳禁
- 各チェック項目について「何を確認したか」「実施状況」を明確に示すこと
- チェックリストを形式的に実行せず、実際の行動に反映させること

**ユーザーへの明示方法**：
- チェックリスト各項目を✅マークと共に列挙する
- 各項目について「確認内容」と「実施状況」を具体的に記載する
- 「理解済み」「確認済み」「実施済み」等の状態を明記する

**セッションログへの記録**：
- セッションログには詳細なチェック項目の列挙は記録不要
- ただし、チェックリスト確認開始・完了は必ず記録すること

### ⚠️ 例外は一切なし

- 「簡単な作業」でも上記ルール厳守
- 「緊急時」でも上記ルール厳守
- 「過去に同じ作業」でも毎回許可取得


## プロジェクト概要

- **プロジェクト名**: グループTODO
- **フレームワーク**: Flutter 3.24+
- **状態管理**: StatefulWidget + Service Layer Pattern
- **データベース**: Supabase (PostgreSQL, Authentication, Storage)
- **アーキテクチャ**: Service-based Architecture with Clean separation
- **開発状況**: プロジェクト初期セットアップ段階

### 🏗️ アプリ基本設計方針（重要）
- **DB接続前提**: このアプリはSupabaseデータベースへの接続が必須で動作するアプリ
- **フォールバック禁止**: DB接続失敗時のローカルデータフォールバック機能は実装しない
- **エラー時動作**: API接続失敗・DB接続失敗時はエラー画面に遷移し、正常動作を停止する
- **オンライン必須**: オフライン時やネットワーク障害時はアプリ使用不可として扱う

## 技術スタック

- Flutter SDK 3.24+
- **Supabase**: PostgreSQL データベース・認証・リアルタイム同期
- SharedPreferences (ローカル設定・キャッシュ)
- HTTP client for API calls

## ディレクトリ構成

```
group_todo/
├── 🗄️ **データベース・バックエンド**
│   └── database/               # Supabase PostgreSQL 管理
│       ├── schema/             # テーブル定義・DDL
│       ├── data/               # マスターデータ・テストデータ
│       └── scripts/            # 運用スクリプト
│
├── 📱 **アプリケーション本体**
│   └── lib/
│       ├── core/                    # 共通設定・ユーティリティ
│       │   ├── config/
│       │   │   └── environment_config.dart # 統合環境設定管理
│       │   └── utils/
│       │
│       ├── data/                    # データ層
│       │   └── models/              # Supabase PostgreSQLモデル
│       │
│       ├── presentation/            # UI層
│       │   ├── screens/
│       │   ├── themes/
│       │   │   └── app_theme.dart       # Material Design 3テーマ
│       │   └── widgets/             # 再利用ウィジェット
│       │
│       ├── services/                # ビジネスロジック層
│       │   └── supabase/            # Supabase直接連携
│       │
│       └── main.dart                # アプリエントリーポイント
│
├── 🔧 **設定・環境**
│   ├── android/                     # Android設定
│   ├── ios/                         # iOS設定
│   └── web/                         # Web版設定
│
├── 🗂️ **データ管理**
│   └── assets/                      # アセットファイル
│       ├── config/
│       │   └── environments.json        # 統合環境設定（Supabase）
│       └── icons/                   # アプリアイコン
│
├── 📚 **ドキュメント**
│   ├── docs/                        # 技術ドキュメント
│   │   ├── requirements.md          # 要件定義書
│   │   ├── current_architecture.md  # アーキテクチャ仕様
│   │   └── guide/                   # 各種ガイド
│   ├── CLAUDE.md                    # 開発仕様書（このファイル）
│   └── README.md                    # プロジェクト概要
│
├── 🧪 **テスト・品質管理**
│   ├── test/                        # テストファイル
│   ├── analysis_options.yaml        # Dart解析設定
│   └── pubspec.yaml                 # Flutter依存関係
│
└── 📦 **セッションログ**
    └── session_logs/                # 開発セッションログ
```

## 環境設定

### 開発環境
- **dev**: 開発環境（デバッグ・機能開発用）
- **stg**: ステージング環境（リリース前検証用）
- **prod**: 本番環境（一般ユーザー向け）

### Flavor設定
- Flavorを利用した環境切り替え
- 各環境で独立したSupabaseプロジェクト
- Bundle ID・アプリ名の環境別設定

## 実装品質・エラー対応方針

### 📋 技術実装ルール
1. **Supabase運用**
   - 全データはSupabase PostgreSQLで管理
   - 適切なエラーハンドリングと空データ対応
   - Row Level Security (RLS) ポリシー遵守

2. **品質保証**
   - 実装後は必ず `flutter analyze` でエラーチェック
   - `dart format` でコード整形
   - 未使用インポート・変数の削除

3. **動作確認の分担**
   - ユーザー側でhot reloadによる動作確認を実施
   - 開発者は品質チェックと許可確認のみ実行
   - 画面修正時は影響範囲を事前確認し許可を得る

4. **依存関係管理の原則**
   - 依存関係を直す場合は、基本的にバージョンが新しい方に合わせる
   - パッケージ、ライブラリを利用する際は最新バージョンで利用を検討する

5. **ドキュメント更新の義務化**
   - 機能実装完了時は必ずdocsフォルダのMDファイルに反映する
   - 実装状況・技術仕様・使用方法を詳細に記録する
   - 未来の開発・保守での参照性を重視する
   - 実装と同時にドキュメント更新することで情報の整合性を保つ

### 自動品質チェック（必須実行）
実装後は必ず以下を自動実行してください：

1. **Dart Analyzer チェック**
   ```bash
   flutter analyze
   ```
   - すべてのエラーを修正
   - 重要な警告も解消
   - 未使用インポート・変数の削除

2. **コードフォーマット適用**
   ```bash
   dart format .
   ```
   - Dart標準フォーマットに準拠
   - インデント・改行の統一
   - 可読性の向上

### エラー対応の原則
- **コンパイルエラーは即座に修正**
- **警告も可能な限り解消**
- **Null safety の適切な対応**
- **未使用コードの除去**
- **適切な例外処理の実装**

### 実装完了の定義
以下がすべて満たされた状態を「実装完了」とします：
- ✅ `flutter analyze` でエラー・重要警告なし
- ✅ `dart format .` 適用済み
- ✅ 実装した機能のコードが完成
- ✅ 開発ルールを遵守

## コーディング規約
- Dart effective dart に準拠
- Clean Architecture パターン
- コンポーネントの再利用性重視
- 適切なコメントとドキュメント

## データベース命名規則

### テーブル命名規則（プレフィックスベース）
- **ユーザー系**: `users` (単一テーブル)
- **グループ系**: `groups`, `group_members` (例: groups, group_members)
- **TODO系**: `todos`, `todo_assignments`, `todo_comments` (例: todos, todo_assignments)
- **定期TODO系**: `recurring_todos` (例: recurring_todos)
- **招待系**: `invite_codes` (例: invite_codes)

この命名規則により、テーブル名から管理対象が即座に判別できます。

## よく使用するコマンド

```bash
# アプリ起動
flutter run

# ホットリロード（アプリ起動中）
r キー

# 依存関係更新
flutter pub get

# 分析・リント
flutter analyze

# フォーマット
dart format .
```

## 関連ドキュメント

- `docs/requirements.md`: プロジェクト要件定義書
- `docs/guide/flutter_flavors_setup_guide.md`: Flutter Flavors設定ガイド
- `docs/guide/environment_setup_guide.md`: 環境設定ガイド

## 開発フェーズ

現在は **Phase 0: プロジェクト初期セットアップ** 段階です。

### Phase 0: プロジェクト初期セットアップ
- ✅ プロジェクト要件定義書作成
- ✅ CLAUDE.md作成
- 🔄 Flutter Flavors設定
- 🔄 Supabase環境構築
- 🔄 基本的なディレクトリ構造作成

### Phase 1: MVP（最小限の機能）
- ユーザー管理（デバイスベース認証）
- グループ作成・招待
- 基本的なTODO管理（作成・編集・削除・完了）
- リアルタイム同期

### Phase 2: 基本機能拡充
- TODO担当者設定
- カテゴリ・フィルター機能
- 期限設定・通知
- コメント機能

### Phase 3: 高度な機能
- 定期TODO機能
- データ引き継ぎ機能
- TODOテンプレート機能

## 最新の実装状況

### 現在の状況
- プロジェクト初期段階
- ドキュメント整備中
- 環境設定準備中

---

**最終更新日**: 2025-09-30