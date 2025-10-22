-- グループ並び替え機能：group_membersテーブルにdisplay_orderカラム追加
-- 作成日: 2025-10-21

-- 1. display_orderカラム追加
ALTER TABLE group_members ADD COLUMN display_order INTEGER;

-- 2. 既存データに対してdisplay_orderを自動設定
-- ユーザーごとに、joined_at順で番号を振る
WITH numbered_members AS (
  SELECT
    id,
    ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY joined_at ASC) AS row_num
  FROM group_members
)
UPDATE group_members
SET display_order = numbered_members.row_num
FROM numbered_members
WHERE group_members.id = numbered_members.id;

-- 3. display_orderにNOT NULL制約を追加（既存データに値が入った後）
ALTER TABLE group_members ALTER COLUMN display_order SET NOT NULL;

-- 4. インデックス追加（ソート用）
CREATE INDEX idx_group_members_display_order ON group_members(user_id, display_order);

-- テーブルコメント
COMMENT ON COLUMN group_members.display_order IS 'ユーザーごとのグループ表示順序（昇順）';
