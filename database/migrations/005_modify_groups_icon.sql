-- ===================================
-- Migration: Modify groups icon_color to icon_url
-- 作成日: 2025-10-12
-- 説明: グループアイコンをカラーコード（icon_color）から画像URL（icon_url）に変更
-- ===================================

-- icon_colorカラムを削除し、icon_urlカラムを追加
ALTER TABLE groups
  DROP COLUMN IF EXISTS icon_color,
  ADD COLUMN IF NOT EXISTS icon_url TEXT;

-- カラムコメント追加
COMMENT ON COLUMN groups.icon_url IS 'グループアイコン画像URL（Supabase Storageのパス）';

-- ===================================
-- 完了通知
-- ===================================
DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Migration 005: groups icon modified';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Changed: icon_color (TEXT NOT NULL) -> icon_url (TEXT NULL)';
  RAISE NOTICE 'Groups can now have image icons instead of color codes';
  RAISE NOTICE '========================================';
END $$;
