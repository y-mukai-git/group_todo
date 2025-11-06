-- TODO説明と定期TODO説明の文字数上限を500→200文字に変更
-- 作成日: 2025-11-05

-- ===================================
-- 1. todosテーブルのdescription制約変更
-- ===================================

-- 既存の制約を削除
ALTER TABLE todos DROP CONSTRAINT IF EXISTS todos_description_check;

-- 新しい制約を追加（200文字制限）
ALTER TABLE todos ADD CONSTRAINT todos_description_check CHECK (char_length(description) <= 200);

-- ===================================
-- 2. recurring_todosテーブルのdescription制約変更
-- ===================================

-- 既存の制約を削除
ALTER TABLE recurring_todos DROP CONSTRAINT IF EXISTS recurring_todos_description_check;

-- 新しい制約を追加（200文字制限）
ALTER TABLE recurring_todos ADD CONSTRAINT recurring_todos_description_check CHECK (char_length(description) <= 200);

-- ===================================
-- 3. コメント更新
-- ===================================

COMMENT ON COLUMN todos.description IS 'TODO説明（200文字以内）';
COMMENT ON COLUMN recurring_todos.description IS '定期TODO説明（200文字以内）';
