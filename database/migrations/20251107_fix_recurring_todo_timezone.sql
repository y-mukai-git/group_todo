-- Migration: 20251107_fix_recurring_todo_timezone.sql
-- 作成日: 2025-11-07
-- 目的: 定期TODO生成時刻をJST（Asia/Tokyo）として解釈するように修正
--
-- 問題: generation_time (TIME型) がUTCとして解釈され、9時間ずれていた
-- 解決: generation_timeをJST（Asia/Tokyo）として扱うように変更
--
-- 実行方法:
--   1. Supabase Dashboard → SQL Editor を開く
--   2. このファイルの内容をコピー&ペースト
--   3. 「Run」をクリックして実行
--
-- 注意事項:
--   - 全環境（dev, stg, prod）で実行が必要です
--   - 既存の定期TODO設定のnext_generation_atは手動で再計算されます

-- ===================================
-- 次回生成日時計算関数（修正版）
-- ===================================
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
-- 既存の定期TODO設定のnext_generation_at再計算
-- ===================================
DO $$
DECLARE
  recurring_todo_record RECORD;
  new_next_generation TIMESTAMPTZ;
BEGIN
  RAISE NOTICE 'Recalculating next_generation_at for all active recurring todos...';

  FOR recurring_todo_record IN
    SELECT id, recurrence_pattern, recurrence_days, generation_time, next_generation_at
    FROM recurring_todos
    WHERE is_active = true
  LOOP
    -- 現在時刻を基準に次回生成日時を再計算
    new_next_generation := calculate_next_generation(
      recurring_todo_record.recurrence_pattern,
      recurring_todo_record.recurrence_days,
      recurring_todo_record.generation_time,
      NOW()
    );

    -- next_generation_atを更新
    UPDATE recurring_todos
    SET next_generation_at = new_next_generation,
        updated_at = NOW()
    WHERE id = recurring_todo_record.id;

    RAISE NOTICE 'Updated recurring_todo %: % -> %',
      recurring_todo_record.id,
      recurring_todo_record.next_generation_at,
      new_next_generation;
  END LOOP;

  RAISE NOTICE 'Recalculation completed!';
END $$;

-- ===================================
-- マイグレーション完了通知
-- ===================================
DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Migration: Fix Recurring TODO Timezone';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Updated: calculate_next_generation() function';
  RAISE NOTICE 'Timezone: generation_time now treated as JST (Asia/Tokyo)';
  RAISE NOTICE 'Recalculated: All active recurring_todos.next_generation_at';
  RAISE NOTICE '';
  RAISE NOTICE 'Expected behavior:';
  RAISE NOTICE '  - generation_time: 09:00 → JST 09:00 generation';
  RAISE NOTICE '  - generation_time: 13:00 → JST 13:00 generation';
  RAISE NOTICE '========================================';
END $$;
