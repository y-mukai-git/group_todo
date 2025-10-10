-- Migration: Add display_id to users table
-- 8桁英数字ランダムIDを追加（表示・データ引き継ぎ・ユーザー招待用）
-- 作成日: 2025-10-06
-- 注意: display_id生成はEdge Function (create-user) で実施

-- ===================================
-- 1. display_id カラム追加（既存ユーザー用にNULL許可）
-- ===================================
ALTER TABLE users ADD COLUMN IF NOT EXISTS display_id TEXT;

-- ===================================
-- 2. ユニーク制約とインデックス追加
-- ===================================
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_display_id ON users(display_id) WHERE display_id IS NOT NULL;

-- ===================================
-- 3. テーブルコメント更新
-- ===================================
COMMENT ON COLUMN users.display_id IS '8桁英数字ランダムID（表示・データ引き継ぎ・ユーザー招待用）Edge Functionで生成';

-- Migration完了
SELECT 'Migration 001_add_display_id.sql completed successfully' AS status;
