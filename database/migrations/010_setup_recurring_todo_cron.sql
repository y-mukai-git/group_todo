-- Migration: 010_setup_recurring_todo_cron.sql
-- 作成日: 2025-10-14
-- 目的: 定期TODO自動生成Cron Job設定（既存環境向け）
--
-- 実行前準備:
--   このファイルを実行する前に、以下のプレースホルダーを環境固有の値に置換してください:
--   - {{SUPABASE_PROJECT_URL}} → 環境のSupabase URL (例: https://xxxxx.supabase.co)
--   - {{SERVICE_ROLE_KEY}} → 環境のService Role Key
--
-- 実行方法:
--   1. ファイルをコピー
--   2. プレースホルダーを環境固有の値に置換
--   3. Supabase SQL Editorで実行
--
-- 注意事項:
--   - Service Role Keyはシークレットキーのため、本番環境では適切に管理してください

-- ===================================
-- Cron Job設定
-- ===================================

-- pg_cron エクステンション有効化
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- 定期TODO自動生成Cron Job
-- 毎分実行 (*/1 * * * *) でrecurring_todosテーブルを監視し、該当時刻に達したらTODOを自動生成
SELECT cron.schedule(
  'execute-recurring-todos',
  '*/1 * * * *',
  $$
  SELECT net.http_post(
    url := '{{SUPABASE_PROJECT_URL}}/functions/v1/execute-recurring-todos',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer {{SERVICE_ROLE_KEY}}'
    )
  );
  $$
);

-- ===================================
-- マイグレーション完了通知
-- ===================================
DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Migration 010: Recurring TODO Cron Job Setup';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Cron Job Created:';
  RAISE NOTICE '  - Name: execute-recurring-todos';
  RAISE NOTICE '  - Schedule: */1 * * * * (毎分実行)';
  RAISE NOTICE '  - Function: execute-recurring-todos Edge Function';
  RAISE NOTICE '';
  RAISE NOTICE '注意:';
  RAISE NOTICE '  プレースホルダー ({{SUPABASE_PROJECT_URL}}, {{SERVICE_ROLE_KEY}}) を';
  RAISE NOTICE '  環境固有の値に置換したか確認してください。';
  RAISE NOTICE '========================================';
END $$;
