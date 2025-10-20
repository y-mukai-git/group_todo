# グループTODO - データベース環境構築ガイド

このディレクトリには、GroupTODOアプリケーションのデータベーススキーマと設定ファイルが含まれています。

## 📁 ディレクトリ構成

```
database/
├── ddl/
│   └── 01_create_tables.sql         # データベーススキーマ定義（テーブル、インデックス、RLS、Cron設定）
│
├── migrations/
│   ├── 001_add_display_id.sql       # マイグレーション: display_id追加
│   ├── 002_cleanup_display_id_functions.sql
│   ├── 003_add_groups_category.sql
│   ├── 004_add_announcements_table.sql
│   ├── 005_modify_groups_icon.sql
│   ├── 007_add_contact_inquiries_table.sql
│   ├── 008_add_error_logs_table.sql
│   ├── 009_add_recurring_todos.sql
│   └── 011_migrate_to_sql_cron.sql  # PostgreSQL関数 Cronへ移行（dev環境のみ）
│
├── data/                            # マスターデータ・初期データ
├── schema/                          # スキーマ補助ファイル
└── scripts/                         # 運用スクリプト
```

---

## 🚀 環境構築手順

### 前提条件
- Supabaseプロジェクトが作成済みであること
- Supabase Dashboard へのアクセス権限があること

---

## 📋 新規環境構築（初回セットアップ）

新しいSupabase環境（Staging/Production）を構築する際の手順です。

**重要**: Development環境は既存環境のため、migrationファイル（`011_migrate_to_sql_cron.sql`）で対応します。

### データベーススキーマの作成（全環境共通）

1. **Supabase Dashboardを開く**
   - 対象環境のSupabaseプロジェクトにアクセス

2. **SQL Editorを開く**
   - 左メニュー「SQL Editor」をクリック
   - 「New query」をクリック

3. **DDLファイルを実行**
   - `database/ddl/01_create_tables.sql` の内容をコピー
   - SQL Editorにペースト
   - 「Run」をクリックして実行

4. **実行結果確認**
   - エラーが表示されないことを確認
   - 以下のメッセージが表示されることを確認：
     ```
     GroupTODO Database Schema Created Successfully
     Tables Created: 10
     ```

**作成されるもの**:
- テーブル: users, groups, group_members, todos, todo_assignments, todo_comments, recurring_todos, recurring_todo_assignments, announcements, contact_inquiries, error_logs
- インデックス: 各テーブルの最適化インデックス
- RLSポリシー: Row Level Security設定
- トリガー: updated_at自動更新トリガー
- **PostgreSQL関数**: execute_recurring_todos(), calculate_next_generation()
- **Cron Job**: 定期TODO自動生成（毎分実行）

**これで環境構築完了です！** 追加の手順は不要です。

---

## ✅ 環境構築完了チェックリスト

以下の項目を確認してください：

- [ ] DDL実行完了（`01_create_tables.sql`）
- [ ] 全テーブルが作成されている
- [ ] PostgreSQL関数が作成されている
- [ ] Cron Job設定が完了している
- [ ] 定期TODO自動生成が有効化されている

### 確認方法

#### テーブル作成確認
```sql
-- Supabase SQL Editorで実行
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;
```

**期待される結果**: 以下のテーブルが表示される
- announcements
- contact_inquiries
- error_logs
- group_members
- groups
- recurring_todo_assignments
- recurring_todos
- todo_assignments
- todo_comments
- todos
- users

#### PostgreSQL関数作成確認
```sql
-- Supabase SQL Editorで実行
SELECT proname
FROM pg_proc
WHERE proname IN ('execute_recurring_todos', 'calculate_next_generation');
```

**期待される結果**: 2つの関数が表示される
- execute_recurring_todos
- calculate_next_generation

#### Cron Job設定確認
```sql
-- Supabase SQL Editorで実行
SELECT * FROM cron.job;
```

**期待される結果**: `execute-recurring-todos` という名前のジョブが表示される

---

## 🔧 トラブルシューティング

### DDL実行時にエラーが発生する場合

**エラー**: `permission denied to create extension "uuid-ossp"`

**対処法**: Supabaseプロジェクトでは通常有効化済みのため、無視して構いません。

---

### Cron Job設定時にエラーが発生する場合

**エラー**: `extension "pg_cron" does not exist`

**対処法**: Supabase Dashboardで以下を確認：
1. Database → Extensions
2. `pg_cron` を検索して有効化

---

### 定期TODOが自動生成されない場合

**確認項目**:
1. Cron Jobが正しく設定されているか確認（上記「Cron Job設定確認」参照）
2. PostgreSQL関数が作成されているか確認（上記「PostgreSQL関数作成確認」参照）
3. `recurring_todos` テーブルに有効なレコードが存在するか確認
4. `next_generation_at` が現在時刻より前になっているか確認

```sql
-- 有効な定期TODOを確認
SELECT id, title, next_generation_at, is_active
FROM recurring_todos
WHERE is_active = true
ORDER BY next_generation_at;
```

---

## 📚 関連ドキュメント

- [プロジェクト要件定義書](../docs/requirements.md)
- [アーキテクチャ仕様](../docs/current_architecture.md)
- [環境設定ガイド](../docs/guide/environment_setup_guide.md)

---

## 🔐 セキュリティ注意事項

- **データベーススキーマは全環境統一** - 環境別の設定値は不要です
- **Cronジョブは自動設定** - プロジェクトURLやService Role Keyは不要です
- **PostgreSQL関数で完結** - 外部APIキーの管理が不要で安全です

---

## 📝 更新履歴

- **2025-10-20**: PostgreSQL関数版Cronに移行（環境別ファイル不要化）
- **2025-10-20**: 初版作成、Cron設定を環境別migrationに分離
- **2025-10-14**: recurring_todos関連マイグレーション追加
- **2025-10-13**: contact_inquiries テーブル追加
- **2025-10-12**: announcements テーブル追加

---

**最終更新日**: 2025-10-20
