-- ===================================
-- Migration: 009_add_recurring_todos
-- 定期TODO機能のテーブル追加
-- 作成日: 2025-10-14
-- ===================================

-- ===================================
-- 1. Recurring Todos (定期TODO)
-- ===================================
CREATE TABLE IF NOT EXISTS recurring_todos (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  title TEXT NOT NULL CHECK (char_length(title) <= 100),
  description TEXT CHECK (char_length(description) <= 500),
  category TEXT NOT NULL CHECK (category IN ('shopping', 'housework', 'other')),

  -- 繰り返し設定
  recurrence_pattern TEXT NOT NULL CHECK (recurrence_pattern IN ('daily', 'weekly', 'monthly')),
  recurrence_days INTEGER[], -- 曜日指定（0=日曜, 6=土曜）または日付指定（1-31, -1=月末）
  generation_time TIME NOT NULL DEFAULT '09:00:00', -- 生成時刻
  next_generation_at TIMESTAMPTZ NOT NULL, -- 次回生成日時

  is_active BOOLEAN NOT NULL DEFAULT true, -- 有効/一時停止

  created_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 定期TODOテーブルのインデックス
CREATE INDEX IF NOT EXISTS idx_recurring_todos_group_id ON recurring_todos(group_id);
CREATE INDEX IF NOT EXISTS idx_recurring_todos_next_generation_at ON recurring_todos(next_generation_at) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_recurring_todos_is_active ON recurring_todos(is_active);

COMMENT ON TABLE recurring_todos IS '定期TODO設定テーブル';
COMMENT ON COLUMN recurring_todos.recurrence_pattern IS '繰り返しパターン（daily: 毎日, weekly: 毎週, monthly: 毎月）';
COMMENT ON COLUMN recurring_todos.recurrence_days IS '繰り返し曜日または日付（weekly: 0-6, monthly: 1-31/-1）';
COMMENT ON COLUMN recurring_todos.next_generation_at IS '次回TODO自動生成日時';

-- ===================================
-- 2. Recurring Todo Assignments (定期TODO担当者)
-- ===================================
CREATE TABLE IF NOT EXISTS recurring_todo_assignments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  recurring_todo_id UUID NOT NULL REFERENCES recurring_todos(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE(recurring_todo_id, user_id)
);

-- 定期TODO担当者テーブルのインデックス
CREATE INDEX IF NOT EXISTS idx_recurring_todo_assignments_recurring_todo_id ON recurring_todo_assignments(recurring_todo_id);
CREATE INDEX IF NOT EXISTS idx_recurring_todo_assignments_user_id ON recurring_todo_assignments(user_id);

COMMENT ON TABLE recurring_todo_assignments IS '定期TODO担当者管理テーブル';

-- ===================================
-- 3. Row Level Security (RLS) ポリシー
-- ===================================

-- RLS有効化
ALTER TABLE recurring_todos ENABLE ROW LEVEL SECURITY;
ALTER TABLE recurring_todo_assignments ENABLE ROW LEVEL SECURITY;

-- Recurring Todos: 所属グループメンバーのみアクセス
CREATE POLICY recurring_todos_select_member ON recurring_todos FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM group_members
    WHERE group_members.group_id = recurring_todos.group_id
    AND group_members.user_id = auth.uid()
  ));

CREATE POLICY recurring_todos_insert_member ON recurring_todos FOR INSERT
  WITH CHECK (
    created_by = auth.uid()
    AND EXISTS (
      SELECT 1 FROM group_members
      WHERE group_members.group_id = recurring_todos.group_id
      AND group_members.user_id = auth.uid()
    )
  );

CREATE POLICY recurring_todos_update_creator_or_owner ON recurring_todos FOR UPDATE
  USING (
    created_by = auth.uid()
    OR EXISTS (
      SELECT 1 FROM groups
      WHERE groups.id = recurring_todos.group_id
      AND groups.owner_id = auth.uid()
    )
  );

CREATE POLICY recurring_todos_delete_creator_or_owner ON recurring_todos FOR DELETE
  USING (
    created_by = auth.uid()
    OR EXISTS (
      SELECT 1 FROM groups
      WHERE groups.id = recurring_todos.group_id
      AND groups.owner_id = auth.uid()
    )
  );

-- Recurring Todo Assignments: 所属グループメンバーのみアクセス
CREATE POLICY recurring_todo_assignments_select_member ON recurring_todo_assignments FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM recurring_todos
    JOIN group_members ON group_members.group_id = recurring_todos.group_id
    WHERE recurring_todos.id = recurring_todo_assignments.recurring_todo_id
    AND group_members.user_id = auth.uid()
  ));

CREATE POLICY recurring_todo_assignments_insert_member ON recurring_todo_assignments FOR INSERT
  WITH CHECK (EXISTS (
    SELECT 1 FROM recurring_todos
    JOIN group_members ON group_members.group_id = recurring_todos.group_id
    WHERE recurring_todos.id = recurring_todo_assignments.recurring_todo_id
    AND group_members.user_id = auth.uid()
  ));

CREATE POLICY recurring_todo_assignments_delete_member ON recurring_todo_assignments FOR DELETE
  USING (EXISTS (
    SELECT 1 FROM recurring_todos
    JOIN group_members ON group_members.group_id = recurring_todos.group_id
    WHERE recurring_todos.id = recurring_todo_assignments.recurring_todo_id
    AND group_members.user_id = auth.uid()
  ));

-- ===================================
-- 4. 自動更新トリガー
-- ===================================

-- recurring_todosテーブルにupdated_at自動更新トリガーを設定
CREATE TRIGGER update_recurring_todos_updated_at BEFORE UPDATE ON recurring_todos
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ===================================
-- マイグレーション完了通知
-- ===================================
DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Migration 009: Recurring Todos - Completed';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Tables Added:';
  RAISE NOTICE '  - recurring_todos';
  RAISE NOTICE '  - recurring_todo_assignments';
  RAISE NOTICE 'RLS Policies: Enabled';
  RAISE NOTICE 'Indexes: Created';
  RAISE NOTICE '========================================';
END $$;
