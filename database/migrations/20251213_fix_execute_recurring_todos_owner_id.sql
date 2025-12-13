-- =====================================================
-- Migration: 定期TODO生成関数のバグ修正
-- Date: 2025-12-13
-- Description: g.created_by を g.owner_id に修正
--              groups テーブルには created_by カラムが存在しない
-- =====================================================

CREATE OR REPLACE FUNCTION execute_recurring_todos()
RETURNS void
LANGUAGE plpgsql
SET search_path TO 'public'
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

      -- 2. 担当者を割り当て（グループ離脱者は自動割り振り）
      INSERT INTO todo_assignments (todo_id, user_id, assigned_at)
      SELECT
        new_todo_id,
        CASE
          -- 担当者がまだグループメンバーの場合はそのまま割り当て
          WHEN EXISTS (
            SELECT 1 FROM group_members
            WHERE group_members.group_id = recurring_todo_record.group_id
            AND group_members.user_id = rta.user_id
          ) THEN rta.user_id
          -- グループから離脱している場合、フォールバック
          ELSE COALESCE(
            -- 優先順位1: 定期TODO作成者（グループメンバーの場合）
            (SELECT recurring_todo_record.created_by
             WHERE EXISTS (
               SELECT 1 FROM group_members
               WHERE group_members.group_id = recurring_todo_record.group_id
               AND group_members.user_id = recurring_todo_record.created_by
             )),
            -- 優先順位2: グループオーナー（owner_id）（グループメンバーの場合）
            (SELECT g.owner_id FROM groups g
             WHERE g.id = recurring_todo_record.group_id
             AND EXISTS (
               SELECT 1 FROM group_members
               WHERE group_members.group_id = g.id
               AND group_members.user_id = g.owner_id
             )),
            -- 優先順位3: グループオーナー（role='owner'のメンバー）
            (SELECT gm.user_id FROM group_members gm
             WHERE gm.group_id = recurring_todo_record.group_id
             AND gm.role = 'owner'
             LIMIT 1)
          )
        END as assigned_user_id,
        now_time
      FROM recurring_todo_assignments rta
      WHERE rta.recurring_todo_id = recurring_todo_record.id
      -- 割り当て先ユーザーが確定した場合のみINSERT
      AND CASE
        WHEN EXISTS (
          SELECT 1 FROM group_members
          WHERE group_members.group_id = recurring_todo_record.group_id
          AND group_members.user_id = rta.user_id
        ) THEN TRUE
        ELSE COALESCE(
          (SELECT recurring_todo_record.created_by
           WHERE EXISTS (
             SELECT 1 FROM group_members
             WHERE group_members.group_id = recurring_todo_record.group_id
             AND group_members.user_id = recurring_todo_record.created_by
           )) IS NOT NULL,
          (SELECT g.owner_id FROM groups g
           WHERE g.id = recurring_todo_record.group_id
           AND EXISTS (
             SELECT 1 FROM group_members
             WHERE group_members.group_id = g.id
             AND group_members.user_id = g.owner_id
           )) IS NOT NULL,
          (SELECT gm.user_id FROM group_members gm
           WHERE gm.group_id = recurring_todo_record.group_id
           AND gm.role = 'owner'
           LIMIT 1) IS NOT NULL,
          FALSE
        )
      END;

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
