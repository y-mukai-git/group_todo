#!/usr/bin/env python3
"""
Edge Functions一括修正スクリプト
- CORSヘッダー定義を共通モジュールimportに置換
- メンテナンスチェックコードを共通関数呼び出しに置換
"""

import os
import re
from pathlib import Path

# プロジェクトルート
PROJECT_ROOT = Path(__file__).parent.parent
FUNCTIONS_DIR = PROJECT_ROOT / "supabase" / "functions"

# メンテナンスチェックを行わないFunction
SKIP_MAINTENANCE_CHECK = ["check-app-status", "check-maintenance-mode"]

# CORSヘッダー定義のパターン
CORS_PATTERN = re.compile(
    r"const corsHeaders = \{\s*'Access-Control-Allow-Origin': '\*',\s*'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',\s*\}",
    re.DOTALL
)

# メンテナンスチェックコードのパターン
MAINTENANCE_PATTERN = re.compile(
    r"// メンテナンスモードチェック\s*const supabaseUrl = Deno\.env\.get\('SUPABASE_URL'\) \?\? ''\s*const supabaseAnonKey = Deno\.env\.get\('SUPABASE_ANON_KEY'\) \?\? ''\s*const checkResponse = await fetch\(`\$\{supabaseUrl\}/functions/v1/check-maintenance-mode`, \{\s*method: 'POST',\s*headers: \{\s*'Content-Type': 'application/json',\s*'Authorization': `Bearer \$\{supabaseAnonKey\}`,\s*\},\s*\}\)\s*const checkResult = await checkResponse\.json\(\)",
    re.DOTALL
)

# 修正後のメンテナンスチェック
MAINTENANCE_REPLACEMENT = "// メンテナンスモードチェック\n    const checkResult = await checkMaintenanceMode()"


def update_function(function_name):
    """Edge Functionを修正"""
    index_path = FUNCTIONS_DIR / function_name / "index.ts"

    if not index_path.exists():
        print(f"  ⚠️  {function_name}: index.ts not found")
        return False

    # ファイル読み込み
    content = index_path.read_text(encoding='utf-8')
    original_content = content
    modified = False

    # 1. CORSヘッダー定義を削除
    if CORS_PATTERN.search(content):
        content = CORS_PATTERN.sub("", content)
        modified = True

    # 2. import文の追加・修正
    # 既にimportがある場合とない場合で処理を分ける
    if "import { corsHeaders } from '../_shared/cors.ts'" not in content:
        # import文を探す
        import_match = re.search(r"(import .+ from .+\n)+", content)
        if import_match:
            # 最後のimport文の後に追加
            last_import_end = import_match.end()

            # メンテナンスチェックが必要かどうか
            if function_name not in SKIP_MAINTENANCE_CHECK:
                new_imports = "import { corsHeaders } from '../_shared/cors.ts'\nimport { checkMaintenanceMode } from '../_shared/maintenance.ts'\n"
            else:
                new_imports = "import { corsHeaders } from '../_shared/cors.ts'\n"

            content = content[:last_import_end] + new_imports + content[last_import_end:]
            modified = True

    # 3. メンテナンスチェックコードを関数呼び出しに置換
    if function_name not in SKIP_MAINTENANCE_CHECK:
        if MAINTENANCE_PATTERN.search(content):
            content = MAINTENANCE_PATTERN.sub(MAINTENANCE_REPLACEMENT, content)
            modified = True

    # 4. 変更があればファイルに書き込み
    if modified and content != original_content:
        index_path.write_text(content, encoding='utf-8')
        return True

    return False


def main():
    """メイン処理"""
    print("Edge Functions一括修正を開始します...\n")

    # 全Edge Functionを取得
    functions = [d.name for d in FUNCTIONS_DIR.iterdir() if d.is_dir() and d.name != "_shared"]
    functions.sort()

    # 修正済みを除外
    functions = [f for f in functions if f != "create-group"]

    print(f"対象: {len(functions)}個のEdge Functions\n")

    updated_count = 0

    for function_name in functions:
        print(f"修正中: {function_name}...")
        if update_function(function_name):
            print(f"  ✅ 修正完了")
            updated_count += 1
        else:
            print(f"  ⏭️  スキップ（変更なし）")

    print(f"\n修正完了: {updated_count}/{len(functions)}個のEdge Functionsを修正しました")


if __name__ == "__main__":
    main()
