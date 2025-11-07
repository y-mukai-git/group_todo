-- Migration: 011_migrate_to_sql_cron.sql
-- 作成日: 2025-10-20
-- 環境: Development（既存環境向け）
-- 目的: HTTP Cron → PostgreSQL関数 Cronへ移行
--
-- 実行方法:
--   1. Supabase Dashboard → SQL Editor を開く
--   2. このファイルの内容をコピー&ペースト
--   3. 「Run」をクリックして実行
--
-- 注意事項:
--   - このマイグレーションはDevelopment環境専用です
--   - Staging/Production環境では不要です（DDLに統合済み）
--   - 既存のHTTP Cronジョブがあれば削除します

-- ===================================
-- 既存のHTTP Cronジョブ削除（存在する場合）
-- ===================================

-- 既存のexecute-recurring-todosジョブを削除
SELECT cron.unschedule('execute-recurring-todos');

-- ===================================
-- PostgreSQL関数定義
-- ===================================

-- 定期TODO自動生成関数
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
        created_by,
        is_completed,
        created_at,
        updated_at
      ) VALUES (
        recurring_todo_record.group_id,
        recurring_todo_record.title,
        recurring_todo_record.description,
        recurring_todo_record.category,
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

-- 次回生成日時計算関数（JST対応版）
-- generation_timeをJST（Asia/Tokyo）として解釈し、UTCのTIMESTAMPTZを返す
CREATE OR REPLACE FUNCTION calculate_next_generation(
  pattern TEXT,
  days INTEGER[],
  generation_time TIME,
  base_time TIMESTAMPTZ
)
RETURNS TIMESTAMPTZ
LANGUAGE plpgsql
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
        -- 特定の日付の場合
        BEGIN
          next_date := (DATE_TRUNC('month', base_time_jst) + INTERVAL '1 month')::DATE + (target_day - 1 || ' days')::INTERVAL;
          next_time := (next_date + generation_time) AT TIME ZONE 'Asia/Tokyo';
        EXCEPTION
          WHEN OTHERS THEN
            -- 日付が存在しない場合（例：2月30日）は月末に調整
            next_date := (DATE_TRUNC('month', base_time_jst) + INTERVAL '2 month' - INTERVAL '1 day')::DATE;
            next_time := (next_date + generation_time) AT TIME ZONE 'Asia/Tokyo';
        END;
      END IF;

    ELSE
      RAISE EXCEPTION 'Unknown recurrence pattern: %', pattern;
  END CASE;

  RETURN next_time;
END;
$$;

-- ===================================
-- Cron Job設定（PostgreSQL関数版）
-- ===================================

-- 定期TODO自動生成Cron Job（毎分実行）
SELECT cron.schedule(
  'execute-recurring-todos',
  '*/1 * * * *',
  'SELECT execute_recurring_todos();'
);

-- ===================================
-- マイグレーション完了通知
-- ===================================
DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Migration 011: PostgreSQL関数 Cronへ移行完了';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Environment: Development';
  RAISE NOTICE '削除: HTTP Cron (execute-recurring-todos)';
  RAISE NOTICE '作成: PostgreSQL関数 (execute_recurring_todos)';
  RAISE NOTICE '作成: 次回生成日時計算関数 (calculate_next_generation)';
  RAISE NOTICE '設定: Cron Job (*/1 * * * *)';
  RAISE NOTICE '';
  RAISE NOTICE '定期TODO自動生成がPostgreSQL関数版に移行されました！';
  RAISE NOTICE 'プロジェクトURL、Service Role Key不要で全環境統一可能';
  RAISE NOTICE '========================================';
END $$;
