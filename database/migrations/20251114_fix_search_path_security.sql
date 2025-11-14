-- ===================================
-- PostgreSQL関数のsearch_pathセキュリティ修正
-- ===================================
-- 作成日: 2025-11-14
-- 理由: Supabase Security Advisorの指摘対応
--       PostgreSQL関数で search_path が role mutable になっているセキュリティリスクを修正
--
-- 対象関数:
--   1. update_updated_at_column
--   2. execute_recurring_todos
--   3. calculate_next_generation
--   4. generate_recurring_todos (不要な関数のため削除)
--
-- 修正内容:
--   - 各関数に SET search_path = public を追加
--   - generate_recurring_todos関数を削除（execute_recurring_todosが正しい関数名）

-- ===================================
-- 1. update_updated_at_column の修正
-- ===================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- ===================================
-- 2. execute_recurring_todos の修正
-- ===================================
CREATE OR REPLACE FUNCTION execute_recurring_todos()
RETURNS void
LANGUAGE plpgsql
SET search_path = public
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
            -- 優先順位2: グループ作成者（グループメンバーの場合）
            (SELECT g.created_by FROM groups g
             WHERE g.id = recurring_todo_record.group_id
             AND EXISTS (
               SELECT 1 FROM group_members
               WHERE group_members.group_id = g.id
               AND group_members.user_id = g.created_by
             )),
            -- 優先順位3: グループオーナー
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
          (SELECT g.created_by FROM groups g
           WHERE g.id = recurring_todo_record.group_id
           AND EXISTS (
             SELECT 1 FROM group_members
             WHERE group_members.group_id = g.id
             AND group_members.user_id = g.created_by
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

-- ===================================
-- 3. calculate_next_generation の修正
-- ===================================
CREATE OR REPLACE FUNCTION calculate_next_generation(
  pattern TEXT,
  days INTEGER[],
  generation_time TIME,
  base_time TIMESTAMPTZ
)
RETURNS TIMESTAMPTZ
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  next_time TIMESTAMPTZ;
  current_day INTEGER;
  target_day INTEGER;
  days_to_add INTEGER;
  i INTEGER;
  base_time_jst TIMESTAMP;
  next_date DATE;
BEGIN
  -- 基準時刻をJSTに変換
  base_time_jst := base_time AT TIME ZONE 'Asia/Tokyo';

  CASE pattern
    -- 毎日：翌日のJST指定時刻
    WHEN 'daily' THEN
      -- JSTで翌日の日付を取得
      next_date := (base_time_jst + INTERVAL '1 day')::DATE;
      -- JSTの日付 + 時刻をTIMESTAMPTZに変換
      next_time := (next_date + generation_time) AT TIME ZONE 'Asia/Tokyo';

    -- 毎週：次の該当曜日のJST指定時刻
    WHEN 'weekly' THEN
      IF days IS NULL OR array_length(days, 1) = 0 THEN
        RAISE EXCEPTION 'Weekly pattern requires recurrence_days';
      END IF;

      current_day := EXTRACT(DOW FROM base_time_jst)::INTEGER;
      days_to_add := 7; -- デフォルトは1週間後

      -- 次の該当曜日を探す
      FOR i IN 1..7 LOOP
        target_day := (current_day + i) % 7;
        IF target_day = ANY(days) THEN
          days_to_add := i;
          EXIT;
        END IF;
      END LOOP;

      -- JSTで該当曜日の日付を取得
      next_date := (base_time_jst + (days_to_add || ' days')::INTERVAL)::DATE;
      -- JSTの日付 + 時刻をTIMESTAMPTZに変換
      next_time := (next_date + generation_time) AT TIME ZONE 'Asia/Tokyo';

    -- 毎月：次の該当日のJST指定時刻
    WHEN 'monthly' THEN
      IF days IS NULL OR array_length(days, 1) = 0 THEN
        RAISE EXCEPTION 'Monthly pattern requires recurrence_days';
      END IF;

      target_day := days[1];

      IF target_day = -1 THEN
        -- 月末の場合
        next_date := (DATE_TRUNC('month', base_time_jst) + INTERVAL '1 month' - INTERVAL '1 day')::DATE;
        next_time := (next_date + generation_time) AT TIME ZONE 'Asia/Tokyo';
      ELSE
        -- 指定日の場合
        next_date := (DATE_TRUNC('month', base_time_jst) + INTERVAL '1 month' + ((target_day - 1) || ' days')::INTERVAL)::DATE;
        next_time := (next_date + generation_time) AT TIME ZONE 'Asia/Tokyo';

        -- 月末を超えた場合は次の月の該当日にする
        IF EXTRACT(DAY FROM next_date)::INTEGER != target_day THEN
          next_date := (DATE_TRUNC('month', next_date) + INTERVAL '1 month' + ((target_day - 1) || ' days')::INTERVAL)::DATE;
          next_time := (next_date + generation_time) AT TIME ZONE 'Asia/Tokyo';
        END IF;
      END IF;

    ELSE
      RAISE EXCEPTION 'Invalid recurrence pattern: %', pattern;
  END CASE;

  RETURN next_time;
END;
$$;

-- ===================================
-- 4. generate_recurring_todos 関数の削除
-- ===================================
-- この関数は古い関数名で、現在は使われていない（execute_recurring_todosが正しい関数）
-- セキュリティリスクを減らすため削除
DROP FUNCTION IF EXISTS generate_recurring_todos();

-- ===================================
-- マイグレーション完了確認
-- ===================================
DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Migration: Fix search_path Security';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Updated: update_updated_at_column (SET search_path = public)';
  RAISE NOTICE 'Updated: execute_recurring_todos (SET search_path = public)';
  RAISE NOTICE 'Updated: calculate_next_generation (SET search_path = public)';
  RAISE NOTICE 'Dropped: generate_recurring_todos (unused function)';
  RAISE NOTICE '';
  RAISE NOTICE 'Security: All functions now have immutable search_path';
  RAISE NOTICE '========================================';
END $$;

SELECT 'Migration 20251114_fix_search_path_security.sql completed successfully' AS status;
