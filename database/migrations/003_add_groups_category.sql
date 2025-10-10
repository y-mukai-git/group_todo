-- Migration: Add category column to groups table
-- 実行日: 2025-10-06
-- 目的: グループにカテゴリ機能を追加

-- groupsテーブルにcategoryカラムを追加
ALTER TABLE groups
ADD COLUMN category TEXT;

-- カラム追加後のコメント
COMMENT ON COLUMN groups.category IS 'グループカテゴリ（shopping: 買い物, housework: 家事, work: 仕事, hobby: 趣味, other: その他, none: 未設定）';

-- カテゴリ用インデックス追加（検索パフォーマンス向上）
CREATE INDEX idx_groups_category ON groups(category) WHERE category IS NOT NULL;

-- 完了通知
DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Migration 003: Add category to groups - Completed';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Added column: groups.category (TEXT, nullable)';
  RAISE NOTICE 'Created index: idx_groups_category';
  RAISE NOTICE '========================================';
END $$;
