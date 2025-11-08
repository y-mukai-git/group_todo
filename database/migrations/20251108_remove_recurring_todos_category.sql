-- ===================================
-- recurring_todosテーブルとDB関数からcategoryを削除
-- ===================================
-- 作成日: 2025-11-08
-- 理由: categoryはグループにのみ関連し、TODOや定期TODOには不要なため削除

-- recurring_todosテーブルからcategoryカラムを削除
ALTER TABLE recurring_todos DROP COLUMN IF EXISTS category;

-- generate_recurring_todos関数を更新（categoryカラムを参照しないように）
CREATE OR REPLACE FUNCTION generate_recurring_todos()
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  recurring_todo_record RECORD;
  new_todo_id UUID;
  now_time TIMESTAMPTZ;
BEGIN
  now_time := NOW();

  -- アクティブな定期TODOで生成時刻を過ぎたものを取得
  FOR recurring_todo_record IN
    SELECT *
    FROM recurring_todos
    WHERE is_active = true
      AND next_generation_at <= now_time
  LOOP
    BEGIN
      -- 1. TODOを作成
      INSERT INTO todos (
        group_id,
        title,
        description,
        deadline,
        created_by,
        is_completed,
        created_at,
        updated_at
      ) VALUES (
        recurring_todo_record.group_id,
        recurring_todo_record.title,
        recurring_todo_record.description,
        -- 期限計算：deadline_days_after が NULL なら期限なし、値があればN日後
        CASE
          WHEN recurring_todo_record.deadline_days_after IS NOT NULL
          THEN now_time + (recurring_todo_record.deadline_days_after || ' days')::INTERVAL
          ELSE NULL
        END,
        recurring_todo_record.created_by,
        false,
        now_time,
        now_time
      )
      RETURNING id INTO new_todo_id;

      -- 2. 担当者を割り当て
      INSERT INTO todo_assignments (todo_id, user_id, assigned_at)
      SELECT new_todo_id, user_id, now_time
      FROM recurring_todo_assignments
      WHERE recurring_todo_id = recurring_todo_record.id;

      -- 3. 次回生成日時を更新
      UPDATE recurring_todos
      SET next_generation_at = calculate_next_generation(
        recurring_todo_record.recurrence_pattern,
        recurring_todo_record.recurrence_days,
        recurring_todo_record.generation_time,
        now_time
      ),
      updated_at = now_time
      WHERE id = recurring_todo_record.id;

      RAISE NOTICE 'Generated TODO from recurring_todo_id: %', recurring_todo_record.id;

    EXCEPTION
      WHEN OTHERS THEN
        RAISE WARNING 'Failed to generate TODO for recurring_todo_id %: %', recurring_todo_record.id, SQLERRM;
    END;
  END LOOP;
END;
$$;

-- マイグレーション完了確認
SELECT 'Migration 20251108_remove_recurring_todos_category.sql completed successfully' AS status;
