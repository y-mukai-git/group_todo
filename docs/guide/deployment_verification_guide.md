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

## ✅ デプロイ後の構成検証（標準手順）

デプロイ後、以下の手順で環境間の構成が一致しているかを確認します。

### 手順1: Edge Functions構成の検証

**検証方法**: ローカルのEdge Functionsと各環境を比較します。

#### 1-1. ローカルのFunction一覧を取得

```bash
ls -d supabase/functions/*/ | \
  sed 's|supabase/functions/||' | \
  sed 's|/$||' | \
  grep -v "^_shared$" | \
  sort > /tmp/local_functions.txt

cat /tmp/local_functions.txt
```

#### 1-2. 各環境のFunction一覧を取得

```bash
# DEV環境
supabase functions list --project-ref <dev-project-ref> | \
  grep -E "^\s+[a-f0-9-]{36}" | \
  awk '{print $4}' | \
  sort > /tmp/dev_functions.txt

# STG環境（または確認したい環境）
supabase functions list --project-ref <stg-project-ref> | \
  grep -E "^\s+[a-f0-9-]{36}" | \
  awk '{print $4}' | \
  sort > /tmp/stg_functions.txt
```

#### 1-3. 差分確認

```bash
# ローカルとDEV環境の比較
echo "=== ローカルとDEV環境の比較 ==="
diff /tmp/local_functions.txt /tmp/dev_functions.txt && echo "✅ 完全一致" || echo "❌ 差分あり"

# ローカルとSTG環境の比較
echo "=== ローカルとSTG環境の比較 ==="
diff /tmp/local_functions.txt /tmp/stg_functions.txt && echo "✅ 完全一致" || echo "❌ 差分あり"
```

**期待結果**:
- ローカルとDEV環境: ✅ 完全一致
- ローカルとSTG環境: ✅ 完全一致

**差分がある場合の対応**:
```bash
# 不足しているFunctionを追加デプロイ
supabase functions deploy <missing-function-name> --project-ref <project-ref>

# 再度確認して一致するまで繰り返す
```

#### 1-4. Pythonスクリプトによる詳細比較（オプション）

より詳細な比較が必要な場合：

```bash
python3 <<'EOF'
import subprocess

# ローカルの関数を読み込み
with open('/tmp/local_functions.txt', 'r') as f:
    local_funcs = sorted([line.strip() for line in f if line.strip()])

# DEV環境の関数を読み込み
with open('/tmp/dev_functions.txt', 'r') as f:
    dev_funcs = sorted([line.strip() for line in f if line.strip()])

# STG環境の関数を読み込み
with open('/tmp/stg_functions.txt', 'r') as f:
    stg_funcs = sorted([line.strip() for line in f if line.strip()])

print(f"ローカル: {len(local_funcs)}個の関数")
print(f"DEV環境: {len(dev_funcs)}個の関数")
print(f"STG環境: {len(stg_funcs)}個の関数")

# ローカルとDEV環境の比較
dev_only = set(dev_funcs) - set(local_funcs)
local_only_vs_dev = set(local_funcs) - set(dev_funcs)

print("\n=== ローカルとDEV環境の比較 ===")
if dev_only:
    print(f"DEV環境のみに存在する関数（{len(dev_only)}個）:")
    for func in sorted(dev_only):
        print(f"  - {func}")
if local_only_vs_dev:
    print(f"ローカルのみに存在する関数（{len(local_only_vs_dev)}個）:")
    for func in sorted(local_only_vs_dev):
        print(f"  - {func}")
if not dev_only and not local_only_vs_dev:
    print("✅ 完全一致")

# ローカルとSTG環境の比較
stg_only = set(stg_funcs) - set(local_funcs)
local_only_vs_stg = set(local_funcs) - set(stg_funcs)

print("\n=== ローカルとSTG環境の比較 ===")
if stg_only:
    print(f"STG環境のみに存在する関数（{len(stg_only)}個）:")
    for func in sorted(stg_only):
        print(f"  - {func}")
if local_only_vs_stg:
    print(f"ローカルのみに存在する関数（{len(local_only_vs_stg)}個）:")
    for func in sorted(local_only_vs_stg):
        print(f"  - {func}")
if not stg_only and not local_only_vs_stg:
    print("✅ 完全一致")
EOF
```

---

### 手順2: データベース構成の検証

**検証方法**: psqlで各環境のテーブル構造を取得して比較します。

#### 2-1. テーブル一覧の取得

```bash
# DEV環境
PGPASSWORD="<dev-db-password>" psql "postgresql://postgres@db.<dev-project-ref>.supabase.co:5432/postgres" \
  -c "\dt public.*" > /tmp/dev_tables.txt

# STG環境
PGPASSWORD="<stg-db-password>" psql "postgresql://postgres@db.<stg-project-ref>.supabase.co:5432/postgres" \
  -c "\dt public.*" > /tmp/stg_tables.txt

# テーブル一覧の比較
diff /tmp/dev_tables.txt /tmp/stg_tables.txt
```

**期待結果**: テーブル一覧が一致

#### 2-2. 主要テーブルの構造確認

重要なテーブルの構造を確認します：

```bash
# 確認するテーブルリスト
TABLES="users groups group_members todos todo_assignments recurring_todos group_invitations announcements"

# DEV環境とSTG環境の各テーブル構造を比較
for table in $TABLES; do
    echo "=== $table テーブルの比較 ==="

    # DEV環境
    PGPASSWORD="<dev-db-password>" psql "postgresql://postgres@db.<dev-project-ref>.supabase.co:5432/postgres" \
      -c "\d $table" > /tmp/dev_${table}.txt 2>&1

    # STG環境
    PGPASSWORD="<stg-db-password>" psql "postgresql://postgres@db.<stg-project-ref>.supabase.co:5432/postgres" \
      -c "\d $table" > /tmp/stg_${table}.txt 2>&1

    # 差分確認
    if diff /tmp/dev_${table}.txt /tmp/stg_${table}.txt > /dev/null 2>&1; then
        echo "✅ $table: 完全一致"
    else
        echo "⚠️  $table: 差分あり（カラム順序の違いの可能性）"
    fi
done
```

#### 2-3. Pythonスクリプトによる構造比較（オプション）

より詳細な比較が必要な場合：

```bash
python3 <<'EOF'
import subprocess

tables = [
    'users', 'groups', 'group_members', 'todos', 'todo_assignments',
    'recurring_todos', 'group_invitations', 'announcements'
]

dev_conn = "postgresql://postgres@db.<dev-project-ref>.supabase.co:5432/postgres"
stg_conn = "postgresql://postgres@db.<stg-project-ref>.supabase.co:5432/postgres"

print("=== テーブル構造の比較 ===\n")

all_match = True
for table in tables:
    # DEV環境
    dev_cmd = f'PGPASSWORD="<dev-db-password>" psql "{dev_conn}" -c "\\d {table}" 2>&1'
    dev_result = subprocess.run(dev_cmd, shell=True, capture_output=True, text=True)
    dev_output = dev_result.stdout

    # STG環境
    stg_cmd = f'PGPASSWORD="<stg-db-password>" psql "{stg_conn}" -c "\\d {table}" 2>&1'
    stg_result = subprocess.run(stg_cmd, shell=True, capture_output=True, text=True)
    stg_output = stg_result.stdout

    if dev_output == stg_output:
        print(f"✅ {table}: 完全一致")
    else:
        print(f"⚠️  {table}: 差分あり（カラム順序の違いの可能性）")
        all_match = False

if all_match:
    print("\n✅ 全テーブルの構造が完全一致しています")
else:
    print("\n⚠️  一部のテーブルに差分があります（通常はカラム順序の違いのみ）")
EOF
```

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

## 📊 検証完了チェックリスト

デプロイ後、以下を確認してください：

```
【デプロイ検証完了確認】
日時: ____年__月__日 __:__
実施者: ________
対象環境: □ DEV  □ STG  □ PROD

■ Edge Functions検証
□ ローカルとデプロイ先環境のFunction一覧が完全一致
□ Function数: ローカル __個、デプロイ先 __個
□ 差分: なし

■ データベース構成検証
□ テーブル一覧が一致（__個のテーブル）
□ 主要テーブルの構造が実質的に一致
□ カラム名、型、制約が一致
□ インデックス、外部キー、RLSポリシーが一致

■ 総合判定
□ ✅ 構成が一致している
□ ❌ 差分あり → 追加デプロイが必要

■ 備考
_________________________________________________
_________________________________________________
```

---

## 🔧 トラブルシューティング

### Edge Functions差分がある場合

**症状**: ローカルとデプロイ先環境でFunction一覧が一致しない

**原因と対処**:
1. **デプロイ漏れ**: 不足しているFunctionを個別デプロイ
   ```bash
   supabase functions deploy <function-name> --project-ref <project-ref>
   ```

2. **古いFunctionが残っている**: Supabaseダッシュボードから削除を検討
   - 注意: 削除前に本当に不要か確認してください

### データベース構造差分がある場合

**症状**: テーブル構造に差分がある

**原因と対処**:
1. **マイグレーション未実行**: `supabase db push` を実行
2. **カラム順序の違い**: 機能に影響しないため、そのままでOK
3. **実際の差異**: 不足しているカラムや制約を追加するマイグレーションを作成

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

**最終更新日**: 2025-11-08
