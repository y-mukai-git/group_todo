-- ===================================
-- Migration: Add announcements table
-- 作成日: 2025-10-12
-- 説明: お知らせ機能用テーブルの追加
-- ===================================

-- ===================================
-- Announcements (お知らせ)
-- ===================================
CREATE TABLE IF NOT EXISTS announcements (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  version TEXT NOT NULL CHECK (char_length(version) <= 20), -- バージョン番号（例: "1.0.0", "1.2.3"）
  title TEXT NOT NULL CHECK (char_length(title) <= 100), -- お知らせタイトル
  content TEXT NOT NULL CHECK (char_length(content) <= 1000), -- お知らせ内容
  published_at TIMESTAMPTZ NOT NULL, -- 公開日時（この日時以降に表示される）
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW() -- 作成日時
);

-- お知らせテーブルのインデックス
CREATE INDEX idx_announcements_published_at ON announcements(published_at DESC);
CREATE INDEX idx_announcements_version ON announcements(version);

-- テーブルコメント
COMMENT ON TABLE announcements IS 'お知らせ情報テーブル（アプリバージョン更新情報・重要なお知らせ）';
COMMENT ON COLUMN announcements.version IS 'バージョン番号（例: "1.0.0"）';
COMMENT ON COLUMN announcements.title IS 'お知らせタイトル（100文字以内）';
COMMENT ON COLUMN announcements.content IS 'お知らせ内容（1000文字以内、改行可能）';
COMMENT ON COLUMN announcements.published_at IS '公開日時（この日時以降にアプリに表示される）';

-- ===================================
-- Row Level Security (RLS) ポリシー
-- ===================================

-- RLS有効化
ALTER TABLE announcements ENABLE ROW LEVEL SECURITY;

-- すべてのユーザーが閲覧可能（SELECT権限）
-- 公開日時が現在より前のお知らせのみ表示
CREATE POLICY announcements_select_all ON announcements FOR SELECT
  USING (published_at <= NOW());

-- INSERT/UPDATE/DELETEは管理者のみ（Supabaseコンソールから実行）
-- アプリユーザーには権限を付与しない

-- ===================================
-- 完了通知
-- ===================================
DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Migration 004: announcements table created';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Table: announcements';
  RAISE NOTICE 'Indexes: published_at, version';
  RAISE NOTICE 'RLS Policy: SELECT only (published_at <= NOW())';
  RAISE NOTICE '========================================';
END $$;
