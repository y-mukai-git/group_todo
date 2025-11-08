# データベースマイグレーションガイド

このドキュメントは、グループTODOアプリのデータベース変更を別環境（STG/PROD）に反映する手順を記載しています。

---

## 📋 マイグレーションの目的

DEV環境で実施したデータベース変更（テーブル追加、カラム追加、Edge Functions追加など）を、STG環境やPROD環境に安全に反映するための手順です。

---

## 🎯 マイグレーション手順

### 手順0: **事前準備 - 環境変数の設定**

```bash
# DEV環境の認証情報（比較元）
export SOURCE_PROJECT_REF="<dev-project-ref>"
export SOURCE_SERVICE_ROLE_KEY="<dev-service-role-key>"

# STG環境の認証情報（反映先）
export TARGET_PROJECT_REF="<stg-project-ref>"
export TARGET_SERVICE_ROLE_KEY="<stg-service-role-key>"
```

**認証情報の確認方法**:
```bash
cat ~/.supabase/group_todo_credentials.json
```

---

### 手順1: **事前チェック - DEV環境との構成比較**

マイグレーション実行前に、現在の環境差分を把握します。

#### 1-1. データベーススキーマのチェック

```bash
# 今日の日付のフォルダを作成
mkdir -p schema_dumps/$(date +%Y-%m-%d)

# DEV環境のスキーマをダンプ
pg_dump "postgresql://postgres:${SOURCE_SERVICE_ROLE_KEY}@db.${SOURCE_PROJECT_REF}.supabase.co:5432/postgres" \
  --schema-only > schema_dumps/$(date +%Y-%m-%d)/dev_schema.sql

# STG環境のスキーマをダンプ
pg_dump "postgresql://postgres:${TARGET_SERVICE_ROLE_KEY}@db.${TARGET_PROJECT_REF}.supabase.co:5432/postgres" \
  --schema-only > schema_dumps/$(date +%Y-%m-%d)/stg_schema.sql

# 差分確認
diff schema_dumps/$(date +%Y-%m-%d)/dev_schema.sql schema_dumps/$(date +%Y-%m-%d)/stg_schema.sql
```

**確認ポイント**:
- 新規追加されたテーブルの有無
- カラム変更の有無
- インデックスの差異

**差分の記録**:
```
【確認日時】: ____年__月__日 __:__
【実施者】: ________

■ DB構成の差分
□ 新規テーブル: ________________
□ 変更テーブル: ________________
□ その他差異: ________________
```

#### 1-2. Edge Functionsのチェック（必須・全体比較）

**⚠️ 重要**: 特定機能のみではなく、**必ず全体のEdge Functionsを比較**してください。

```bash
# DEV環境のFunction一覧を取得（名前のみ、ソート済み）
supabase functions list --project-ref ${SOURCE_PROJECT_REF} | awk 'NR>1 {print $3}' | sort > /tmp/dev_functions.txt

# STG環境のFunction一覧を取得（名前のみ、ソート済み）
supabase functions list --project-ref ${TARGET_PROJECT_REF} | awk 'NR>1 {print $3}' | sort > /tmp/stg_functions.txt

# DEVにあってSTGにないFunctionsを確認
echo "=== DEVにあってSTGにないFunctions ==="
comm -23 /tmp/dev_functions.txt /tmp/stg_functions.txt

# STGにあってDEVにないFunctionsを確認
echo "=== STGにあってDEVにないFunctions ==="
comm -13 /tmp/dev_functions.txt /tmp/stg_functions.txt
```

**確認ポイント**:
- **DEVにあってSTGにないFunctionsを全てリストアップ**
- **STGにあってDEVにないFunctions（不要なものがないか確認）**
- ローカルディレクトリ `supabase/functions/` と照合し、実際に使用されているか確認

**差分の記録**（必須）:
```
■ Edge Functionsの差分
【DEVにあってSTGにない】:
  □ ________________
  □ ________________
  □ ________________

【STGにあってDEVにない】:
  □ ________________
  □ ________________

【デプロイが必要なFunctions】:
  □ ________________
  □ ________________
```

---

### 手順2: **データベースマイグレーションの実行**

#### 2-1. マイグレーションファイルの確認

適用するマイグレーションファイルを確認します：

```bash
# マイグレーションファイル一覧
ls -la database/migrations/
```

#### 2-2. マイグレーションの実行

```bash
# マイグレーションファイルを指定して実行
PGPASSWORD="${TARGET_SERVICE_ROLE_KEY}" psql "postgresql://postgres@db.${TARGET_PROJECT_REF}.supabase.co:5432/postgres" \
  -f database/migrations/YYYYMMDD_migration_name.sql
```

#### 2-3. マイグレーション実行後の確認

```bash
# テーブル一覧を確認
PGPASSWORD="${TARGET_SERVICE_ROLE_KEY}" psql "postgresql://postgres@db.${TARGET_PROJECT_REF}.supabase.co:5432/postgres" \
  -c "\dt"

# 特定のテーブルの存在確認
PGPASSWORD="${TARGET_SERVICE_ROLE_KEY}" psql "postgresql://postgres@db.${TARGET_PROJECT_REF}.supabase.co:5432/postgres" \
  -c "\d <table_name>"
```

---

### 手順3: **Edge Functionsのデプロイ**

#### 3-1. 新規Functionsのデプロイ

```bash
# 新規追加されたFunctionsを個別にデプロイ
supabase functions deploy <function-name> --project-ref ${TARGET_PROJECT_REF}
```

#### 3-2. 既存Functionsの更新

```bash
# 更新が必要なFunctionsをデプロイ
supabase functions deploy <function-name> --project-ref ${TARGET_PROJECT_REF}
```

#### 3-3. デプロイ後の確認

```bash
# デプロイ済みFunctions一覧を確認
supabase functions list --project-ref ${TARGET_PROJECT_REF}
```

---

### 手順4: **最終確認 - DEVとの構成完全一致チェック**

マイグレーション実行後、DEV環境と**完全に同じ構成**になったかを確認します。

**⚠️ 重要**: 差分が0件になるまで確認してください。差分がある場合は追加デプロイが必要です。

**📘 詳細な手順**: `docs/guide/deployment_verification_guide.md` を参照してください。

#### 4-1. Edge Functions構成の検証

**検証方法**: ローカルのEdge Functionsと各環境を比較します。

```bash
# ローカルのFunction一覧を取得
ls -d supabase/functions/*/ | \
  sed 's|supabase/functions/||' | \
  sed 's|/$||' | \
  grep -v "^_shared$" | \
  sort > /tmp/local_functions.txt

# STG環境のFunction一覧を取得
supabase functions list --project-ref ${TARGET_PROJECT_REF} | \
  grep -E "^\s+[a-f0-9-]{36}" | \
  awk '{print $4}' | \
  sort > /tmp/stg_functions.txt

# ローカルとSTG環境の比較
echo "=== ローカルとSTG環境の比較 ==="
diff /tmp/local_functions.txt /tmp/stg_functions.txt && echo "✅ 完全一致" || echo "❌ 差分あり"
```

**期待結果**: ✅ 完全一致

**差分があった場合の対応**:
```bash
# 不足しているFunctionを追加デプロイ
supabase functions deploy <missing-function-name> --project-ref ${TARGET_PROJECT_REF}

# 再度確認して一致するまで繰り返す
```

#### 4-2. データベース構成の検証

**検証方法**: psqlで各環境のテーブル構造を取得して比較します。

```bash
# テーブル一覧の取得と比較
PGPASSWORD="${SOURCE_SERVICE_ROLE_KEY}" psql "postgresql://postgres@db.${SOURCE_PROJECT_REF}.supabase.co:5432/postgres" \
  -c "\dt public.*" > /tmp/dev_tables.txt

PGPASSWORD="${TARGET_SERVICE_ROLE_KEY}" psql "postgresql://postgres@db.${TARGET_PROJECT_REF}.supabase.co:5432/postgres" \
  -c "\dt public.*" > /tmp/stg_tables.txt

diff /tmp/dev_tables.txt /tmp/stg_tables.txt
```

**主要テーブルの構造確認**:
```bash
# 重要なテーブルの構造を確認
TABLES="users groups group_members todos todo_assignments recurring_todos group_invitations announcements"

for table in $TABLES; do
    echo "=== $table テーブルの比較 ==="

    PGPASSWORD="${SOURCE_SERVICE_ROLE_KEY}" psql "postgresql://postgres@db.${SOURCE_PROJECT_REF}.supabase.co:5432/postgres" \
      -c "\d $table" > /tmp/dev_${table}.txt 2>&1

    PGPASSWORD="${TARGET_SERVICE_ROLE_KEY}" psql "postgresql://postgres@db.${TARGET_PROJECT_REF}.supabase.co:5432/postgres" \
      -c "\d $table" > /tmp/stg_${table}.txt 2>&1

    if diff /tmp/dev_${table}.txt /tmp/stg_${table}.txt > /dev/null 2>&1; then
        echo "✅ $table: 完全一致"
    else
        echo "⚠️  $table: 差分あり（カラム順序の違いの可能性）"
    fi
done
```

**期待結果**:
- テーブル一覧: ✅ 完全一致
- 各テーブル構造: ✅ 実質的に一致（カラム順序の違いは許容）

**注意**: カラムの順序が異なる場合がありますが、以下が一致していれば問題ありません：
- カラム名
- カラムの型
- NOT NULL制約
- DEFAULT値
- インデックス
- 外部キー制約
- RLSポリシー
- トリガー

---

### 手順5: **動作確認**

#### 5-1. データベース接続確認

```bash
# テーブルのレコード数を確認
psql "postgresql://postgres:${TARGET_SERVICE_ROLE_KEY}@db.${TARGET_PROJECT_REF}.supabase.co:5432/postgres" \
  -c "SELECT COUNT(*) FROM <new_table_name>;"
```

#### 5-2. Edge Functions動作確認

```bash
# 新規Functionの動作確認（例）
ANON_KEY="<環境のanon_key>"

curl -X POST "https://${TARGET_PROJECT_REF}.supabase.co/functions/v1/<function-name>" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{}'
```

#### 5-3. アプリ側での動作確認

- アプリをSTG環境向けにビルド
- 新機能が正常に動作することを確認

---

## 📝 マイグレーション完了チェックリスト

マイグレーション完了時に以下をチェックしてください：

```
【マイグレーション完了確認】
日時: ____年__月__日 __:__
実施者: ________

■ 事前チェック（手順1）
□ DEV環境とSTG環境のスキーマ差分を確認済み
□ DEV環境とSTG環境のEdge Functions差分を【全体比較】で確認済み
□ 差分をすべてリストアップし、デプロイが必要なFunctionsを特定済み

■ マイグレーション実行（手順2）
□ データベースマイグレーションファイルを実行済み
□ マイグレーション実行後、エラーなし
□ 新規テーブルが作成されている

■ Edge Functionsデプロイ（手順3）
□ 新規Functionsをデプロイ済み
□ 既存Functions更新をデプロイ済み
□ デプロイ後、Functionsが正常に表示されている

■ 最終確認（手順4）- **完全一致確認**
□ DEV環境とSTG環境のスキーマが一致している
□ **DEVにあってSTGにないEdge Functions: 0件を確認済み**
□ STGにあってDEVにないEdge Functions: 不要なもののみ（または0件）
□ 差分がある場合は追加デプロイを実施し、差分0になるまで確認済み

■ 動作確認（手順5）
□ データベース接続が成功する
□ Edge Functionsが動作する
□ アプリ側で新機能が動作する

■ 備考
_________________________________________________
_________________________________________________
```

---

## 🔧 トラブルシューティング

### マイグレーション実行時のエラー

**エラー**: `relation already exists`
```
原因: テーブルが既に存在する
解決策:
- マイグレーションファイルに CREATE TABLE IF NOT EXISTS を使用
- 既存テーブルの場合はスキップ
```

**エラー**: `permission denied`
```
原因: Service Role Keyが正しくない
解決策:
- Service Role Keyを確認
- ~/.supabase/group_todo_credentials.json を確認
```

### Edge Functionsデプロイ時のエラー

**エラー**: `Unauthorized`
```
原因: Supabase CLIでログインしていない
解決策:
- supabase login を実行してログイン
```

**エラー**: `Project not found`
```
原因: Project Referenceが正しくない
解決策:
- PROJECT_REF環境変数を確認
- ~/.supabase/group_todo_credentials.json を確認
```

---

## 📚 関連ドキュメント

- `database/ENVIRONMENT_SETUP.md` - 環境構築手順書
- `database/migrations/` - マイグレーションファイル
- `database/ddl/` - DDLファイル
- `~/.supabase/group_todo_credentials.json` - 認証情報ファイル

---

## 📌 重要な注意事項

1. **バックアップの取得**
   - マイグレーション実行前に必ずデータベースのバックアップを取得してください

2. **段階的な反映**
   - DEV → STG → PROD の順に段階的に反映してください
   - 各環境で動作確認を実施してから次の環境に進んでください

3. **ロールバック計画**
   - マイグレーション失敗時のロールバック手順を事前に確認してください

4. **スキーマダンプファイルの管理**
   - `schema_dumps/` フォルダは `.gitignore` で管理対象外
   - 日付単位でフォルダを作成し、履歴を保持してください

---

**最終更新日**: 2025-11-04
