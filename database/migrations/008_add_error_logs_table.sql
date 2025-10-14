-- Migration: Add error_logs table
-- Created: 2025-10-14
-- Description: システムエラーログ機能のためのerror_logsテーブルを追加

-- ===================================
-- Error Logs (エラーログ)
-- ===================================
CREATE TABLE IF NOT EXISTS error_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  error_type TEXT NOT NULL,
  error_message TEXT NOT NULL,
  stack_trace TEXT,
  screen_name TEXT,
  device_info JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- インデックス作成
CREATE INDEX IF NOT EXISTS idx_error_logs_user_id ON error_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_error_logs_created_at ON error_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_error_logs_error_type ON error_logs(error_type);

-- テーブルコメント
COMMENT ON TABLE error_logs IS 'システムエラーログテーブル';
COMMENT ON COLUMN error_logs.id IS 'エラーログID（UUID）';
COMMENT ON COLUMN error_logs.user_id IS 'ユーザーID（外部キー）';
COMMENT ON COLUMN error_logs.error_type IS 'エラー種別';
COMMENT ON COLUMN error_logs.error_message IS 'エラーメッセージ';
COMMENT ON COLUMN error_logs.stack_trace IS 'スタックトレース';
COMMENT ON COLUMN error_logs.screen_name IS 'エラー発生画面名';
COMMENT ON COLUMN error_logs.device_info IS 'デバイス情報（JSON）';
COMMENT ON COLUMN error_logs.created_at IS 'エラー発生日時';

-- RLS有効化
ALTER TABLE error_logs ENABLE ROW LEVEL SECURITY;

-- RLSポリシー作成
-- ユーザーは自分のエラーログのみ参照可能
CREATE POLICY error_logs_select_own ON error_logs FOR SELECT
  USING (user_id = auth.uid());
