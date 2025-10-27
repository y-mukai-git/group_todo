# Supabase環境構築手順書

このドキュメントは、グループTODOアプリのStaging/Production環境を構築する手順を記載しています。

---

## 📋 前提条件

### 必要なツール
- Supabase CLI（v2.39.2以上）
- PostgreSQL CLIツール（psql）

### 必要な情報
以下の情報を事前に準備してください：

1. **Supabaseプロジェクト情報**
   - Project Reference ID（例: `vnhclkfeijmoidkksmxi`）
   - Project URL（例: `https://vnhclkfeijmoidkksmxi.supabase.co`）
   - Anon Key
   - Service Role Key

2. **環境設定ファイル**
   - `~/.supabase/group_todo_credentials.json` に認証情報を保存
   - `assets/config/environments.json` に環境設定を記載

---

## 🎯 構築手順

### 手順1: データベーススキーマの構築

#### 1-1. 認証情報の確認

```bash
# credentials.jsonの確認
cat ~/.supabase/group_todo_credentials.json
```

以下の形式で情報が保存されていることを確認：
```json
{
  "staging": {
    "project_ref": "vnhclkfeijmoidkksmxi",
    "service_role_key": "eyJhbGci..."
  }
}
```

#### 1-2. 環境変数の設定

```bash
# Staging環境の場合
export PROJECT_REF="vnhclkfeijmoidkksmxi"
export SERVICE_ROLE_KEY="<staging環境のservice_role_key>"

# Production環境の場合
export PROJECT_REF="<production-project-ref>"
export SERVICE_ROLE_KEY="<production環境のservice_role_key>"
```

#### 1-3. DDLファイルの実行

```bash
psql "postgresql://postgres:${SERVICE_ROLE_KEY}@db.${PROJECT_REF}.supabase.co:5432/postgres" \
  -f database/ddl/01_create_tables.sql
```

#### 1-4. 実行結果の確認

```bash
# テーブル一覧を確認
psql "postgresql://postgres:${SERVICE_ROLE_KEY}@db.${PROJECT_REF}.supabase.co:5432/postgres" \
  -c "\dt"
```

以下のテーブルが作成されていることを確認：
- users
- groups
- group_members
- todos
- todo_assignments
- todo_comments
- recurring_todos
- recurring_todo_assignments
- announcements
- contact_inquiries
- error_logs
- app_versions
- maintenance_mode

---

### 手順2: Storageバケットの作成

#### 2-1. user-avatarsバケットの作成

```bash
curl -X POST "https://${PROJECT_REF}.supabase.co/storage/v1/bucket" \
  -H "Authorization: Bearer ${SERVICE_ROLE_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "user-avatars",
    "name": "user-avatars",
    "public": true,
    "file_size_limit": 5242880,
    "allowed_mime_types": ["image/jpeg", "image/png"]
  }'
```

#### 2-2. group-iconsバケットの作成

```bash
curl -X POST "https://${PROJECT_REF}.supabase.co/storage/v1/bucket" \
  -H "Authorization: Bearer ${SERVICE_ROLE_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "group-icons",
    "name": "group-icons",
    "public": true,
    "file_size_limit": 5242880,
    "allowed_mime_types": ["image/jpeg", "image/png"]
  }'
```

#### 2-3. バケット作成の確認

```bash
# バケット一覧を取得
curl "https://${PROJECT_REF}.supabase.co/storage/v1/bucket" \
  -H "Authorization: Bearer ${SERVICE_ROLE_KEY}"
```

以下のバケットが含まれていることを確認：
- ✅ user-avatars
- ✅ group-icons

---

### 手順3: Edge Functionsのデプロイ

#### 3-1. Supabase CLIのログイン確認

```bash
# Supabase CLIがインストールされているか確認
supabase --version

# ログイン状態を確認（必要に応じてログイン）
supabase login
```

#### 3-2. 全Edge Functionsのデプロイ

```bash
# Staging環境の場合
supabase functions deploy --project-ref vnhclkfeijmoidkksmxi

# Production環境の場合
supabase functions deploy --project-ref <production-project-ref>
```

#### 3-3. デプロイ済みFunctionの確認

```bash
# デプロイ済みFunction一覧を確認
supabase functions list --project-ref ${PROJECT_REF}
```

または、Supabaseダッシュボードの「Edge Functions」で確認。

---

### 手順4: 環境間構成チェック

この手順は、STG環境がDEV環境と同じ構成か、PROD環境がSTG環境と同じ構成かをチェックします。

#### 4-1. データベーススキーマのチェック

**スキーマダンプファイルの格納先**:
- スキーマダンプファイルは `schema_dumps/YYYY-MM-DD/` に日付単位で保存してください
- ファイル名の例: `dev_schema.sql`, `stg_schema.sql`, `prod_schema.sql`
- このフォルダは `.gitignore` に追加されており、git管理対象外です

```bash
# 今日の日付のフォルダを作成
mkdir -p schema_dumps/$(date +%Y-%m-%d)

# 比較元環境（例: DEV）のスキーマをダンプ
pg_dump "postgresql://postgres:${SOURCE_SERVICE_ROLE_KEY}@db.${SOURCE_PROJECT_REF}.supabase.co:5432/postgres" \
  --schema-only > schema_dumps/$(date +%Y-%m-%d)/dev_schema.sql

# 比較先環境（例: STG）のスキーマをダンプ
pg_dump "postgresql://postgres:${TARGET_SERVICE_ROLE_KEY}@db.${TARGET_PROJECT_REF}.supabase.co:5432/postgres" \
  --schema-only > schema_dumps/$(date +%Y-%m-%d)/stg_schema.sql

# 差分確認
diff schema_dumps/$(date +%Y-%m-%d)/dev_schema.sql schema_dumps/$(date +%Y-%m-%d)/stg_schema.sql
```

**期待結果**: 差分がない（または環境固有の差分のみ）

#### 4-2. Edge Functionsのチェック

```bash
# 比較元環境（例: DEV）のFunction一覧を取得
supabase functions list --project-ref ${SOURCE_PROJECT_REF} > source_functions.txt

# 比較先環境（例: STG）のFunction一覧を取得
supabase functions list --project-ref ${TARGET_PROJECT_REF} > target_functions.txt

# 差分確認
diff source_functions.txt target_functions.txt
```

**期待結果**: 差分がない（同じFunctionがデプロイされている）

#### 4-3. Storageバケットのチェック

```bash
# 比較元環境（例: DEV）のバケット一覧を取得
curl "https://${SOURCE_PROJECT_REF}.supabase.co/storage/v1/bucket" \
  -H "Authorization: Bearer ${SOURCE_SERVICE_ROLE_KEY}" > source_buckets.json

# 比較先環境（例: STG）のバケット一覧を取得
curl "https://${TARGET_PROJECT_REF}.supabase.co/storage/v1/bucket" \
  -H "Authorization: Bearer ${TARGET_SERVICE_ROLE_KEY}" > target_buckets.json

# 差分確認（jqでフォーマットして比較）
diff <(jq -S '.' source_buckets.json) <(jq -S '.' target_buckets.json)
```

**期待結果**: 差分がない（同じバケットが作成されている）

#### 4-4. チェック結果の確認

- データベーススキーマ: 差分なし ✅
- Edge Functions: 差分なし ✅
- Storageバケット: 差分なし ✅

すべて差分がなければ、環境間の構成が同じであることが確認できます。

---

### 手順5: 動作確認

#### 5-1. メンテナンスモードチェック

```bash
ANON_KEY="<環境のanon_key>"

curl -X POST "https://${PROJECT_REF}.supabase.co/functions/v1/check-maintenance-mode" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "Content-Type: application/json"
```

期待されるレスポンス：
```json
{
  "status": "ok"
}
```

#### 5-2. データベース接続確認

```bash
# テーブルのレコード数を確認
psql "postgresql://postgres:${SERVICE_ROLE_KEY}@db.${PROJECT_REF}.supabase.co:5432/postgres" \
  -c "SELECT COUNT(*) FROM users;"
```

#### 5-3. Storageバケット確認

```bash
# バケット一覧を取得
curl "https://${PROJECT_REF}.supabase.co/storage/v1/bucket" \
  -H "Authorization: Bearer ${SERVICE_ROLE_KEY}"
```

以下のバケットが含まれていることを確認：
- ✅ user-avatars
- ✅ group-icons

---

## 🔧 トラブルシューティング

### DDL実行時のエラー

**エラー**: `connection refused`
```
解決策:
- SupabaseプロジェクトがPausedになっていないか確認
- Database Passwordが正しいか確認
- Project Referenceが正しいか確認
```

**エラー**: `permission denied`
```
解決策:
- Service Role Keyを使用しているか確認
- Anon Keyではなく、Service Role Keyを使用してください
```

### Edge Functionsデプロイ時のエラー

**エラー**: `Unauthorized`
```
解決策:
- Supabase CLIでログインしているか確認
- supabase login を実行してログイン
```

**エラー**: `Project not found`
```
解決策:
- Project Referenceが正しいか確認
- ~/.supabase/group_todo_credentials.json の内容を確認
```

### Storageバケット作成時のエラー

**エラー**: バケットが作成できない
```
解決策:
- 既に同名のバケットが存在しないか確認
- プロジェクトのStorage容量を確認
```

---

## 📝 完了チェックリスト

環境構築完了時に以下をチェックしてください：

- [ ] データベーススキーマが構築されている（13テーブル）
- [ ] user-avatarsバケットが作成されている
- [ ] group-iconsバケットが作成されている
- [ ] Edge Functions（34個）がデプロイされている
- [ ] メンテナンスモードチェックが動作する
- [ ] データベース接続が成功する

---

## 📚 関連ドキュメント

- `database/ddl/01_create_tables.sql` - データベーススキーマDDL
- `assets/config/environments.json` - 環境設定ファイル
- `~/.supabase/group_todo_credentials.json` - 認証情報ファイル
- `CLAUDE.md` - 開発仕様書

---

**最終更新日**: 2025-10-27 19:51
