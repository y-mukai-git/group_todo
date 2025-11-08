-- ===================================
-- todosテーブルからcategoryカラムを削除
-- ===================================
-- 作成日: 2025-11-08
-- 理由: todosテーブルのcategoryは不要なため削除

-- categoryカラムを削除
ALTER TABLE todos DROP COLUMN IF EXISTS category;

-- マイグレーション完了確認
SELECT 'Migration 20251108_remove_todos_category.sql completed successfully' AS status;
