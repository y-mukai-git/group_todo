-- ===================================
-- グループ招待承認フロー - DDL
-- ===================================
-- 作成日: 2025-11-01
-- 目的: STG/PROD環境への反映用DDL
--       グループ招待時の承認フロー実装

-- ===================================
-- 1. グループ招待テーブル作成
-- ===================================
CREATE TABLE IF NOT EXISTS group_invitations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  inviter_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  invited_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  invited_role TEXT NOT NULL CHECK (invited_role IN ('owner', 'member')),
  status TEXT NOT NULL CHECK (status IN ('pending', 'accepted', 'rejected')),
  invited_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  responded_at TIMESTAMPTZ,

  -- 同じグループへの重複招待防止（同一ユーザーへのpending招待は1つまで）
  UNIQUE(group_id, invited_user_id)
);

-- ===================================
-- 2. インデックス作成
-- ===================================
CREATE INDEX IF NOT EXISTS idx_group_invitations_group_id ON group_invitations(group_id);
CREATE INDEX IF NOT EXISTS idx_group_invitations_invited_user_id ON group_invitations(invited_user_id);
CREATE INDEX IF NOT EXISTS idx_group_invitations_status ON group_invitations(status);
CREATE INDEX IF NOT EXISTS idx_group_invitations_inviter_id ON group_invitations(inviter_id);

-- ===================================
-- 3. コメント追加
-- ===================================
COMMENT ON TABLE group_invitations IS 'グループ招待管理テーブル - 承認フロー対応';
COMMENT ON COLUMN group_invitations.group_id IS '招待先のグループID';
COMMENT ON COLUMN group_invitations.inviter_id IS '招待したユーザーID（オーナー）';
COMMENT ON COLUMN group_invitations.invited_user_id IS '招待されたユーザーID';
COMMENT ON COLUMN group_invitations.invited_role IS '招待時に指定したロール（owner: オーナー, member: メンバー）';
COMMENT ON COLUMN group_invitations.status IS '招待ステータス（pending: 保留中, accepted: 承認済み, rejected: 却下済み）';
COMMENT ON COLUMN group_invitations.invited_at IS '招待日時';
COMMENT ON COLUMN group_invitations.responded_at IS '承認/却下日時';

-- ===================================
-- 4. Row Level Security (RLS) ポリシー
-- ===================================

-- RLS有効化
ALTER TABLE group_invitations ENABLE ROW LEVEL SECURITY;

-- 招待一覧閲覧: 招待者（オーナー）または招待されたユーザー本人のみ
DROP POLICY IF EXISTS group_invitations_select_related_users ON group_invitations;
CREATE POLICY group_invitations_select_related_users ON group_invitations FOR SELECT
  USING (
    inviter_id = auth.uid()
    OR invited_user_id = auth.uid()
  );

-- 招待作成: グループオーナーのみ
DROP POLICY IF EXISTS group_invitations_insert_owner ON group_invitations;
CREATE POLICY group_invitations_insert_owner ON group_invitations FOR INSERT
  WITH CHECK (
    inviter_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM group_members
      WHERE group_members.group_id = group_invitations.group_id
      AND group_members.user_id = auth.uid()
      AND group_members.role = 'owner'
    )
  );

-- 招待更新（承認/却下）: 招待されたユーザー本人のみ
DROP POLICY IF EXISTS group_invitations_update_invited_user ON group_invitations;
CREATE POLICY group_invitations_update_invited_user ON group_invitations FOR UPDATE
  USING (invited_user_id = auth.uid());

-- 招待削除（キャンセル）: 招待者（オーナー）のみ
DROP POLICY IF EXISTS group_invitations_delete_inviter ON group_invitations;
CREATE POLICY group_invitations_delete_inviter ON group_invitations FOR DELETE
  USING (inviter_id = auth.uid());

-- ===================================
-- 5. 完了通知
-- ===================================
DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Group Invitations DDL Applied';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Table: group_invitations';
  RAISE NOTICE 'Indexes: 4 indexes';
  RAISE NOTICE 'RLS Policies: 4 policies';
  RAISE NOTICE '========================================';
END $$;
