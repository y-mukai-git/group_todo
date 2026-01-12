# デプロイ検証ガイド - グループTODO

このドキュメントは、Supabase環境（DEV/STG/PROD）へのデプロイ後に、正しく構成が反映されているかを検証する手順を記載しています。

---

## 📋 目的

デプロイ後に以下を確認します：
1. **Edge Functions**がローカルと同じ構成でデプロイされているか
2. **データベース構成**（テーブル、カラム、制約など）が正しく反映されているか

---

## 🔑 Supabaseへのアクセス方法

### 認証情報の確認

認証情報は `~/.supabase/group_todo_credentials.json` に保存されています：

```bash
cat ~/.supabase/group_todo_credentials.json
```

ファイル構造：
```json
{
  "development": {
    "project_ref": "your-dev-project-ref",
    "service_role_key": "your-dev-service-role-key",
    "db_password": "your-dev-db-password"
  },
  "staging": {
    "project_ref": "your-stg-project-ref",
    "service_role_key": "your-stg-service-role-key",
    "db_password": "your-stg-db-password"
  },
  "production": {
    "project_ref": "your-prod-project-ref",
    "service_role_key": "your-prod-service-role-key",
    "db_password": "your-prod-db-password"
  }
}
```

### Supabase CLIでの環境接続

```bash
# DEV環境に接続
supabase link --project-ref <dev-project-ref> --password "<dev-db-password>"

# STG環境に接続
supabase link --project-ref <stg-project-ref> --password "<stg-db-password>"

# PROD環境に接続
supabase link --project-ref <prod-project-ref> --password "<prod-db-password>"
```

### データベースへの直接接続

```bash
# psqlで接続（パスワード認証）
PGPASSWORD="<db-password>" psql "postgresql://postgres@db.<project-ref>.supabase.co:5432/postgres"
```

---

## 🗄️ データベースマイグレーション

### マイグレーション実行方法

#### Supabase CLIを使用する方法（推奨）

```bash
# 環境に接続
supabase link --project-ref <project-ref> --password "<db-password>"

# マイグレーションを実行
supabase db push -p "<db-password>"
```

**結果の確認**：
- 新規マイグレーションがある場合: 適用されたマイグレーションが表示される
- すべて適用済みの場合: "Remote database is up to date" と表示される

#### psqlで個別マイグレーションを実行する方法

```bash
# マイグレーションファイルを指定して実行
PGPASSWORD="<db-password>" psql "postgresql://postgres@db.<project-ref>.supabase.co:5432/postgres" \
  -f database/migrations/YYYYMMDD_migration_name.sql
```

### マイグレーション確認方法

#### テーブル一覧の確認

```bash
PGPASSWORD="<db-password>" psql "postgresql://postgres@db.<project-ref>.supabase.co:5432/postgres" \
  -c "\dt public.*"
```

#### 特定テーブルの構造確認

```bash
PGPASSWORD="<db-password>" psql "postgresql://postgres@db.<project-ref>.supabase.co:5432/postgres" \
  -c "\d <table_name>"
```

**確認項目**：
- ✅ カラム名
- ✅ カラムの型
- ✅ NOT NULL制約
- ✅ DEFAULT値
- ✅ PRIMARY KEY
- ✅ UNIQUE制約
- ✅ インデックス
- ✅ 外部キー制約
- ✅ RLSポリシー
- ✅ トリガー

**注意**: カラムの**順序**が異なる場合がありますが、これは機能に影響しません。後から追加したカラムは最後に配置されるため、このような違いが生じます。

---

## ⚡ Edge Functionsデプロイ

### 全Edge Functionsの一括デプロイ

```bash
# 環境に接続（まだの場合）
supabase link --project-ref <project-ref> --password "<db-password>"

# 全Functionsをデプロイ
supabase functions deploy --project-ref <project-ref>
```

### 特定Functionの個別デプロイ

```bash
# 特定のFunctionのみデプロイ
supabase functions deploy <function-name> --project-ref <project-ref>
```

### デプロイ確認方法

#### デプロイ済みFunction一覧の確認

```bash
supabase functions list --project-ref <project-ref>
```

**出力例**：
```
ID                                   | NAME                  | SLUG                  | STATUS | VERSION | UPDATED_AT (UTC)
-------------------------------------|----------------------|----------------------|--------|---------|---------------------
6cac1eaa-cff9-4ae9-a4d7-c3782edd8028 | add-group-member     | add-group-member     | ACTIVE | 10      | 2025-11-07 15:29:06
...
```

**注意**: VERSION列は「デプロイ回数」を示すカウンターであり、コードの内容を表すものではありません。

---

## 🗂️ デプロイ時の環境状態記録（JSONファイル更新）

デプロイを実行したら、該当環境のJSONファイルを更新して環境の状態を記録します。

### JSONファイルの配置

- `supabase/deployment_history_dev.json` - DEV環境
- `supabase/deployment_history_stg.json` - STG環境
- `supabase/deployment_history_prod.json` - PROD環境

### Edge Functionデプロイ時の手順

#### 1. Edge Functionのハッシュ値を計算

```bash
cd supabase/functions/<function-name>
sha256sum index.ts | awk '{print $1}'
```

**例**:
```bash
cd supabase/functions/create-todo
sha256sum index.ts | awk '{print $1}'
# 出力: 6eb37a86f800d2e429cf5af204c3b3810e8e4c878f3d76c67111694911c28ef8
```

#### 2. Edge Functionをデプロイ

```bash
supabase functions deploy <function-name> --project-ref <project-ref>
```

#### 3. 該当環境のJSONファイルを更新

デプロイした環境のJSONファイル（例: `supabase/deployment_history_dev.json`）を編集：

```json
{
  "edge_functions": {
    "<function-name>": "<手順1で計算したハッシュ値>"
  }
}
```

### データベースマイグレーション実行時の手順

#### 1. マイグレーションを実行

```bash
supabase db push -p "<db-password>"
```

#### 2. 該当環境のJSONファイルを更新

Pythonスクリプトで全テーブルの構造を取得してJSONファイルを更新：

```bash
python3 <<'PYTHON_EOF'
import subprocess
import json

# 環境情報（例: DEV環境）
project_ref = "your-project-ref"
db_password = "your-password"
conn_str = f"postgresql://postgres@db.{project_ref}.supabase.co:5432/postgres"

# テーブル一覧を取得
get_tables_cmd = f'PGPASSWORD="{db_password}" psql "{conn_str}" -t -c "SELECT table_name FROM information_schema.tables WHERE table_schema = \'public\' ORDER BY table_name"'
result = subprocess.run(get_tables_cmd, shell=True, capture_output=True, text=True)
tables = [t.strip() for t in result.stdout.strip().split('\n') if t.strip()]

# RLS設定を取得
get_rls_cmd = f'PGPASSWORD="{db_password}" psql "{conn_str}" -t -c "SELECT jsonb_object_agg(tablename, rowsecurity) FROM pg_tables WHERE schemaname = \'public\'"'
result = subprocess.run(get_rls_cmd, shell=True, capture_output=True, text=True)
rls_settings = json.loads(result.stdout.strip()) if result.stdout.strip() else {}

# 各テーブルの構造を取得
db_structure = {}
for table in tables:
    get_columns_cmd = f'''PGPASSWORD="{db_password}" psql "{conn_str}" -t -c "
    SELECT jsonb_object_agg(
      column_name,
      jsonb_build_object(
        'type', data_type,
        'nullable', is_nullable = 'YES',
        'default', column_default
      )
    )
    FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = '{table}'"'''

    result = subprocess.run(get_columns_cmd, shell=True, capture_output=True, text=True)
    columns = json.loads(result.stdout.strip())
    db_structure[table] = {
        "columns": columns,
        "rls_enabled": rls_settings.get(table, False)
    }

# 既存のJSONファイルを読み込み
with open('supabase/deployment_history_dev.json', 'r') as f:
    deployment_history = json.load(f)

# database.tablesを更新
deployment_history['database']['tables'] = db_structure

# JSONファイルに書き出し
with open('supabase/deployment_history_dev.json', 'w') as f:
    json.dump(deployment_history, f, indent=2, sort_keys=True)

print("✅ JSONファイルを更新しました")
PYTHON_EOF
```

---

## ✅ デプロイ後の構成検証（標準手順）

デプロイ後、以下の手順で環境間の構成が一致しているかを確認します。

### 手順1: Edge Functions・Database構成の検証（環境間比較）

**検証方法**: DEV環境とSTG環境のJSONファイルを比較します。

#### 1-1. 環境間の差分確認（diffコマンド）

```bash
diff supabase/deployment_history_dev.json supabase/deployment_history_stg.json
```

**期待結果**:
- 出力なし → ✅ 完全一致（DEV環境 = STG環境）
- 差分表示 → ❌ 不一致（どのEdge Functionまたはテーブルが違うかが表示される）

**例（一致している場合）**:
```bash
$ diff supabase/deployment_history_dev.json supabase/deployment_history_stg.json
（出力なし）
→ ✅ DEV環境とSTG環境が完全に一致
```

**例（不一致の場合）**:
```bash
$ diff supabase/deployment_history_dev.json supabase/deployment_history_stg.json
< "invite-user": "07df375e67df004644ae327659543e80a8fbc994cbfda61cfe8c66f5fdd294fa",
---
> "invite-user": "abc123def456...",

→ ❌ invite-user関数のコード内容が異なる
```

#### 1-2. 差分がある場合の対応

**Edge Functionに差分がある場合**:

1. どの関数が異なるかを確認
2. DEV環境と同じコードをSTG環境にデプロイ
3. STG環境のJSONファイルを更新
4. 再度diffコマンドで確認

**Databaseに差分がある場合**:

1. どのテーブルが異なるかを確認
2. 不足しているマイグレーションをSTG環境に実行
3. STG環境のJSONファイルを更新
4. 再度diffコマンドで確認

### 手順2: RLS設定の直接確認（補助的な確認）

JSONファイルにRLS情報が含まれていない場合や、直接DBを確認したい場合に使用します。

```bash
# DEV環境のRLS設定を確認
PGPASSWORD="<dev-db-password>" psql "postgresql://postgres@db.<dev-project-ref>.supabase.co:5432/postgres" \
  -c "SELECT tablename, rowsecurity FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename;"

# STG環境のRLS設定を確認
PGPASSWORD="<stg-db-password>" psql "postgresql://postgres@db.<stg-project-ref>.supabase.co:5432/postgres" \
  -c "SELECT tablename, rowsecurity FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename;"
```

**期待結果**: 両環境で全テーブルの`rowsecurity`が`t`（有効）であること

**RLSが無効なテーブルがある場合**:
1. 該当するマイグレーションファイルを特定（`database/migrations/`内を検索）
2. マイグレーションを対象環境に実行
3. 再度RLS設定を確認

---

## 📊 検証完了チェックリスト

デプロイ後、以下を確認してください：

```
【デプロイ検証完了確認】
日時: ____年__月__日 __:__
実施者: ________
対象環境: □ DEV  □ STG  □ PROD

■ デプロイ時の環境状態記録
□ デプロイしたEdge FunctionsのSHA256ハッシュをJSONファイルに記録済み
□ 実行したマイグレーションの結果をJSONファイルに反映済み
□ JSONファイルのコミット完了

■ 環境間構成比較（JSON diff）
□ デプロイ元環境とデプロイ先環境のJSONファイルを比較
□ Edge Functions構成が一致（Function数: __個）
□ Database構成が一致（テーブル数: __個）
□ RLS設定が一致（全テーブルでrowsecurity = t）
□ diffコマンドで差分なしを確認

■ 総合判定
□ ✅ 構成が完全一致している
□ ❌ 差分あり → 追加デプロイまたはマイグレーションが必要

■ 備考
_________________________________________________
_________________________________________________
```

---

## 🔧 トラブルシューティング

### JSON diff で差分が検出された場合

**症状**: `diff` コマンドで環境間のJSONファイルに差分が表示される

**原因と対処**:

1. **Edge Functions の差分**
   - **原因**: デプロイ漏れ、または古いFunctionが残っている
   - **対処**:
     - 不足しているFunctionを個別デプロイ:
       ```bash
       cd supabase/functions/<function-name>
       sha256sum index.ts | awk '{print $1}'
       supabase functions deploy <function-name> --project-ref <project-ref>
       ```
     - デプロイ後、JSONファイルを更新して再度確認

2. **Database の差分**
   - **原因**: マイグレーション未実行、または構造の不一致
   - **対処**:
     - マイグレーション実行: `supabase db push --project-ref <project-ref>`
     - 実行後、Pythonスクリプトで環境のDB構造を取得してJSONファイルを更新
     - 再度diffコマンドで確認

3. **JSONファイル更新漏れ**
   - **原因**: デプロイ/マイグレーション後にJSONファイルを更新していない
   - **対処**: 本ガイドの「デプロイ時の環境状態記録」手順に従ってJSONファイルを更新

### 接続エラー

**症状**: `failed to connect` や `permission denied`

**原因と対処**:
1. **認証情報の誤り**: `~/.supabase/group_todo_credentials.json` を確認
2. **環境変数の誤り**: project_refやpasswordが正しいか確認
3. **ネットワーク問題**: インターネット接続を確認

---

## 📚 関連ドキュメント

- `database/ENVIRONMENT_SETUP.md` - 環境構築手順書
- `database/MIGRATION_GUIDE.md` - マイグレーションガイド
- `~/.supabase/group_todo_credentials.json` - 認証情報ファイル

---

**最終更新日**: 2025-11-10
