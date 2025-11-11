-- ===================================
-- execute_recurring_todos関数の修正
-- ===================================
-- 作成日: 2025-11-11
-- 理由: categoryカラム参照によるエラーを修正
--
-- 問題:
--   - 11月8日のマイグレーション(20251108_remove_recurring_todos_category.sql)で
--     間違った関数名(generate_recurring_todos)を更新してしまった
--   - 実際にCron Jobで使われているのはexecute_recurring_todos関数
--   - この関数が古い定義のままでcategoryカラムを参照し続けている
--
-- 影響:
--   - STG/DEV環境で毎分2件のエラーが発生
--   - エラー: "TODO creation failed: column "category" of relation "todos" does not exist"
--
-- 修正内容:
--   - execute_recurring_todos関数をcategoryカラムを参照しない正しい定義に更新
--   - deadline計算ロジックも含む正しい定義に更新

-- execute_recurring_todos関数を正しい定義に更新
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

-- マイグレーション完了確認
SELECT 'Migration 20251111_fix_execute_recurring_todos.sql completed successfully' AS status;
