-- =====================================================
-- Migration: 広告スキップフラグ追加
-- Date: 2025-12-10
-- Description: usersテーブルに広告スキップフラグを追加
--              管理者などが広告なしでアプリを利用可能にする
-- =====================================================

-- is_ad_free カラム追加
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_ad_free BOOLEAN NOT NULL DEFAULT false;

-- コメント追加
COMMENT ON COLUMN users.is_ad_free IS '広告スキップフラグ（true: バナー広告非表示＋動画広告スキップ）';

-- インデックス追加（広告スキップユーザーを効率的に検索）
CREATE INDEX IF NOT EXISTS idx_users_is_ad_free ON users(is_ad_free) WHERE is_ad_free = true;
