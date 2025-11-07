-- Migration: 20251107_add_recurring_todo_deadline.sql
-- 作成日: 2025-11-07
-- 目的: 定期TODOに期限設定機能を追加
--
-- 概要:
--   - recurring_todosテーブルにdeadline_days_afterカラムを追加
--   - execute_recurring_todos関数を更新し、TODO生成時に期限を計算・設定
--
-- 実行方法:
--   1. Supabase Dashboard → SQL Editor を開く
--   2. このファイルの内容をコピー&ペースト
--   3. 「Run」をクリックして実行
--
-- 注意事項:
--   - 全環境（dev, stg, prod）で実行が必要です
--   - 既存の定期TODO設定には影響しません（deadline_days_after = NULL）

-- ===================================
-- 1. recurring_todosテーブルにカラム追加
-- ===================================
ALTER TABLE recurring_todos
ADD COLUMN deadline_days_after INTEGER CHECK (deadline_days_after > 0);

COMMENT ON COLUMN recurring_todos.deadline_days_after IS '生成から何日後に期限を設定するか（NULL = 期限なし、1以上 = 生成日からN日後）';

-- ===================================
-- 2. execute_recurring_todos関数の更新
-- ===================================
CREATE OR REPLACE FUNCTION execute_recurring_todos()
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  recurring_todo_record RECORD;
  new_todo_id UUID;
  next_generation TIMESTAMPTZ;
  now_time TIMESTAMPTZ;
BEGIN
  -- 現在時刻取得（UTC）
  now_time := NOW();

  -- 該当するrecurring_todosを取得してループ処理
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
        category,
        deadline,
        created_by,
        is_completed,
        created_at,
        updated_at
      ) VALUES (
        recurring_todo_record.group_id,
        recurring_todo_record.title,
        recurring_todo_record.description,
        recurring_todo_record.category,
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

      -- 3. 次回生成日時を計算
      next_generation := calculate_next_generation(
        recurring_todo_record.recurrence_pattern,
        recurring_todo_record.recurrence_days,
        recurring_todo_record.generation_time,
        now_time
      );

      -- 4. recurring_todosのnext_generation_atを更新
      UPDATE recurring_todos
      SET next_generation_at = next_generation,
          updated_at = now_time
      WHERE id = recurring_todo_record.id;

      RAISE NOTICE 'Successfully processed recurring_todo: %', recurring_todo_record.id;

    EXCEPTION
      WHEN OTHERS THEN
        -- エラーログ記録
        INSERT INTO error_logs (
          user_id,
          error_type,
          error_message,
          stack_trace,
          screen_name,
          created_at
        ) VALUES (
          NULL,
          'recurring_todo_generation_error',
          'TODO creation failed: ' || SQLERRM,
          'recurring_todo_id: ' || recurring_todo_record.id,
          'Cron Job: execute_recurring_todos',
          now_time
        );

        RAISE NOTICE 'Failed to process recurring_todo %: %', recurring_todo_record.id, SQLERRM;
    END;
  END LOOP;
END;
$$;

-- ===================================
-- マイグレーション完了通知
-- ===================================
DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Migration: Add Recurring TODO Deadline';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Added: recurring_todos.deadline_days_after column';
  RAISE NOTICE 'Updated: execute_recurring_todos() function';
  RAISE NOTICE '';
  RAISE NOTICE 'Expected behavior:';
  RAISE NOTICE '  - deadline_days_after: NULL → 期限なしのTODO生成';
  RAISE NOTICE '  - deadline_days_after: 3 → 生成日から3日後に期限設定';
  RAISE NOTICE '========================================';
END $$;
