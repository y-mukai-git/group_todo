-- クイックアクション機能追加
-- quick_actions と quick_action_templates テーブルを作成

-- ===================================
-- Quick Actions (クイックアクション)
-- ===================================
CREATE TABLE quick_actions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  name VARCHAR(100) NOT NULL,
  description TEXT,
  created_by UUID NOT NULL REFERENCES users(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE,
  display_order INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX idx_quick_actions_group_id ON quick_actions(group_id);
CREATE INDEX idx_quick_actions_display_order ON quick_actions(group_id, display_order);

COMMENT ON TABLE quick_actions IS 'クイックアクション管理テーブル';
COMMENT ON COLUMN quick_actions.group_id IS '所属グループID';
COMMENT ON COLUMN quick_actions.name IS 'クイックアクション名（例: カレー）';
COMMENT ON COLUMN quick_actions.description IS '説明';
COMMENT ON COLUMN quick_actions.created_by IS '作成者';
COMMENT ON COLUMN quick_actions.display_order IS '表示順序';

-- ===================================
-- Quick Action Templates (クイックアクションテンプレート)
-- ===================================
CREATE TABLE quick_action_templates (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  quick_action_id UUID NOT NULL REFERENCES quick_actions(id) ON DELETE CASCADE,
  title VARCHAR(200) NOT NULL,
  description TEXT,
  deadline_days_after INTEGER,
  assigned_user_ids UUID[],
  display_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_quick_action_templates_quick_action_id ON quick_action_templates(quick_action_id);
CREATE INDEX idx_quick_action_templates_display_order ON quick_action_templates(quick_action_id, display_order);

COMMENT ON TABLE quick_action_templates IS 'クイックアクションテンプレート（TODO生成用）';
COMMENT ON COLUMN quick_action_templates.quick_action_id IS '所属するクイックアクションID';
COMMENT ON COLUMN quick_action_templates.title IS 'TODO名（例: 玉ねぎを買う）';
COMMENT ON COLUMN quick_action_templates.description IS '説明';
COMMENT ON COLUMN quick_action_templates.deadline_days_after IS '生成から何日後に期限設定（NULL=期限なし）';
COMMENT ON COLUMN quick_action_templates.assigned_user_ids IS '担当者UUID配列';
COMMENT ON COLUMN quick_action_templates.display_order IS 'テンプレート内の表示順序';

-- ===================================
-- RLSポリシー
-- ===================================

-- RLS有効化
ALTER TABLE quick_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE quick_action_templates ENABLE ROW LEVEL SECURITY;

-- Quick Actions: 所属グループメンバーのみアクセス
CREATE POLICY quick_actions_select_member ON quick_actions FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM group_members
    WHERE group_members.group_id = quick_actions.group_id
    AND group_members.user_id = auth.uid()
  ));

CREATE POLICY quick_actions_insert_member ON quick_actions FOR INSERT
  WITH CHECK (
    created_by = auth.uid()
    AND EXISTS (
      SELECT 1 FROM group_members
      WHERE group_members.group_id = quick_actions.group_id
      AND group_members.user_id = auth.uid()
    )
  );

CREATE POLICY quick_actions_update_creator_or_owner ON quick_actions FOR UPDATE
  USING (
    created_by = auth.uid()
    OR EXISTS (
      SELECT 1 FROM groups
      WHERE groups.id = quick_actions.group_id
      AND groups.owner_id = auth.uid()
    )
  );

CREATE POLICY quick_actions_delete_creator_or_owner ON quick_actions FOR DELETE
  USING (
    created_by = auth.uid()
    OR EXISTS (
      SELECT 1 FROM groups
      WHERE groups.id = quick_actions.group_id
      AND groups.owner_id = auth.uid()
    )
  );

-- Quick Action Templates: 所属グループメンバーのみアクセス
CREATE POLICY quick_action_templates_select_member ON quick_action_templates FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM quick_actions
    JOIN group_members ON group_members.group_id = quick_actions.group_id
    WHERE quick_actions.id = quick_action_templates.quick_action_id
    AND group_members.user_id = auth.uid()
  ));

CREATE POLICY quick_action_templates_insert_member ON quick_action_templates FOR INSERT
  WITH CHECK (EXISTS (
    SELECT 1 FROM quick_actions
    JOIN group_members ON group_members.group_id = quick_actions.group_id
    WHERE quick_actions.id = quick_action_templates.quick_action_id
    AND group_members.user_id = auth.uid()
  ));

CREATE POLICY quick_action_templates_update_member ON quick_action_templates FOR UPDATE
  USING (EXISTS (
    SELECT 1 FROM quick_actions
    JOIN group_members ON group_members.group_id = quick_actions.group_id
    WHERE quick_actions.id = quick_action_templates.quick_action_id
    AND group_members.user_id = auth.uid()
  ));

CREATE POLICY quick_action_templates_delete_member ON quick_action_templates FOR DELETE
  USING (EXISTS (
    SELECT 1 FROM quick_actions
    JOIN group_members ON group_members.group_id = quick_actions.group_id
    WHERE quick_actions.id = quick_action_templates.quick_action_id
    AND group_members.user_id = auth.uid()
  ));
