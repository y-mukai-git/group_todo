-- GroupTODO PostgreSQL Database Schema
-- Supabase PostgreSQL スキーマ
-- 作成日: 2025-10-01

-- 既存テーブル全削除（クリーンインストール用）
-- 動的にpublicスキーマの全テーブルを削除（authスキーマは除外）
DO $$
DECLARE
    table_name text;
BEGIN
    -- publicスキーマの全テーブル名を取得して削除
    FOR table_name IN
        SELECT t.table_name
        FROM information_schema.tables t
        WHERE t.table_schema = 'public'
        AND t.table_type = 'BASE TABLE'
        AND t.table_name NOT LIKE 'pg_%'  -- PostgreSQL システムテーブルを除外
    LOOP
        BEGIN
            EXECUTE 'DROP TABLE IF EXISTS public.' || quote_ident(table_name) || ' CASCADE';
            RAISE NOTICE 'Dropped table: %', table_name;
        EXCEPTION
            WHEN insufficient_privilege THEN
                RAISE NOTICE 'Skipped table (insufficient privilege): %', table_name;
            WHEN OTHERS THEN
                RAISE NOTICE 'Failed to drop table %: %', table_name, SQLERRM;
        END;
    END LOOP;

    RAISE NOTICE 'Table cleanup completed';
END $$;

-- 拡張機能の有効化
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ===================================
-- 1. Users (ユーザー情報)
-- ===================================
CREATE TABLE users (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  device_id TEXT UNIQUE NOT NULL,
  display_name TEXT NOT NULL,
  display_id TEXT UNIQUE NOT NULL, -- 8桁英数字ランダムID（表示・引き継ぎ用）
  avatar_url TEXT,

  -- データ引き継ぎ用（ユーザーID + パスワード方式）
  transfer_password_hash TEXT, -- パスワードハッシュ（bcrypt）

  -- 通知設定
  notification_deadline BOOLEAN NOT NULL DEFAULT true, -- 期限通知
  notification_new_todo BOOLEAN NOT NULL DEFAULT true, -- 新規TODO通知
  notification_assigned BOOLEAN NOT NULL DEFAULT true, -- 担当TODO通知

  -- 日時情報
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_accessed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ユーザーテーブルのインデックス
CREATE INDEX idx_users_device_id ON users(device_id);
CREATE INDEX idx_users_display_id ON users(display_id);

COMMENT ON TABLE users IS 'ユーザー情報テーブル（デバイスベース認証）';
COMMENT ON COLUMN users.device_id IS 'デバイス固有ID（iOS/Android/Web）';
COMMENT ON COLUMN users.display_name IS 'ユーザー名（自動生成: ユーザー12345678）';
COMMENT ON COLUMN users.display_id IS '8桁英数字ランダムID（表示・データ引き継ぎ・ユーザー招待用）';
COMMENT ON COLUMN users.transfer_password_hash IS 'データ引き継ぎ用パスワードハッシュ（bcrypt・display_id + パスワード認証）';

-- ===================================
-- 2. Groups (グループ情報)
-- ===================================
CREATE TABLE groups (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL CHECK (char_length(name) <= 50),
  description TEXT CHECK (char_length(description) <= 200),
  icon_url TEXT, -- グループアイコン画像URL（Supabase Storage）
  category TEXT, -- カテゴリ（shopping: 買い物, housework: 家事, work: 仕事, hobby: 趣味, other: その他, none: 未設定）
  owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- グループテーブルのインデックス
CREATE INDEX idx_groups_owner_id ON groups(owner_id);

COMMENT ON TABLE groups IS 'グループ情報テーブル';
COMMENT ON COLUMN groups.icon_url IS 'グループアイコン画像URL（Supabase Storageのパス）';
COMMENT ON COLUMN groups.owner_id IS 'グループオーナーのユーザーID';

-- ===================================
-- 3. Group Members (グループメンバー)
-- ===================================
CREATE TABLE group_members (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('owner', 'member')),

  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE(group_id, user_id)
);

-- グループメンバーテーブルのインデックス
CREATE INDEX idx_group_members_group_id ON group_members(group_id);
CREATE INDEX idx_group_members_user_id ON group_members(user_id);
CREATE INDEX idx_group_members_role ON group_members(role);

COMMENT ON TABLE group_members IS 'グループメンバー管理テーブル';
COMMENT ON COLUMN group_members.role IS 'メンバーのロール（owner: オーナー, member: メンバー）';

-- ===================================
-- 4. Todos (TODO情報 - 個人TODO・グループTODO統合管理)
-- ===================================
CREATE TABLE todos (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  group_id UUID REFERENCES groups(id) ON DELETE CASCADE, -- NULL = 個人TODO
  title TEXT NOT NULL CHECK (char_length(title) <= 100),
  description TEXT CHECK (char_length(description) <= 500),
  deadline TIMESTAMPTZ, -- 期限（nullable）
  category TEXT NOT NULL CHECK (category IN ('shopping', 'housework', 'other')),
  is_completed BOOLEAN NOT NULL DEFAULT false,
  completed_at TIMESTAMPTZ,

  created_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- TODOテーブルのインデックス
CREATE INDEX idx_todos_group_id ON todos(group_id);
CREATE INDEX idx_todos_personal ON todos(created_by) WHERE group_id IS NULL; -- 個人TODO用インデックス
CREATE INDEX idx_todos_deadline ON todos(deadline) WHERE deadline IS NOT NULL;
CREATE INDEX idx_todos_is_completed ON todos(is_completed);
CREATE INDEX idx_todos_created_by ON todos(created_by);
CREATE INDEX idx_todos_created_at ON todos(created_at DESC);

COMMENT ON TABLE todos IS 'TODO情報テーブル（個人TODO・グループTODO統合管理）';
COMMENT ON COLUMN todos.group_id IS 'グループID（NULL = 個人TODO、値あり = グループTODO）';
COMMENT ON COLUMN todos.category IS 'TODOカテゴリ（shopping: 買い物, housework: 家事, other: その他）';
COMMENT ON COLUMN todos.is_completed IS '完了状態（false: 未完了, true: 完了）';

-- ===================================
-- 5. Todo Assignments (TODO担当者)
-- ===================================
CREATE TABLE todo_assignments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  todo_id UUID NOT NULL REFERENCES todos(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE(todo_id, user_id)
);

-- TODO担当者テーブルのインデックス
CREATE INDEX idx_todo_assignments_todo_id ON todo_assignments(todo_id);
CREATE INDEX idx_todo_assignments_user_id ON todo_assignments(user_id);

COMMENT ON TABLE todo_assignments IS 'TODO担当者管理テーブル';

-- ===================================
-- 6. Todo Comments (TODOコメント)
-- ===================================
CREATE TABLE todo_comments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  todo_id UUID NOT NULL REFERENCES todos(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  content TEXT NOT NULL CHECK (char_length(content) <= 500),

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- TODOコメントテーブルのインデックス
CREATE INDEX idx_todo_comments_todo_id ON todo_comments(todo_id);
CREATE INDEX idx_todo_comments_user_id ON todo_comments(user_id);
CREATE INDEX idx_todo_comments_created_at ON todo_comments(created_at DESC);

COMMENT ON TABLE todo_comments IS 'TODOコメントテーブル';
COMMENT ON COLUMN todo_comments.content IS 'コメント内容（URL・外部リンク禁止）';

-- ===================================
-- 7. Recurring Todos (定期TODO)
-- ===================================
CREATE TABLE recurring_todos (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  title TEXT NOT NULL CHECK (char_length(title) <= 100),
  description TEXT CHECK (char_length(description) <= 500),
  category TEXT NOT NULL CHECK (category IN ('shopping', 'housework', 'other')),

  -- 繰り返し設定
  recurrence_pattern TEXT NOT NULL CHECK (recurrence_pattern IN ('daily', 'weekly', 'monthly')),
  recurrence_days INTEGER[], -- 曜日指定（0=日曜, 6=土曜）または日付指定（1-31, -1=月末）
  generation_time TIME NOT NULL DEFAULT '09:00:00', -- 生成時刻
  next_generation_at TIMESTAMPTZ NOT NULL, -- 次回生成日時

  is_active BOOLEAN NOT NULL DEFAULT true, -- 有効/一時停止

  created_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 定期TODOテーブルのインデックス
CREATE INDEX idx_recurring_todos_group_id ON recurring_todos(group_id);
CREATE INDEX idx_recurring_todos_next_generation_at ON recurring_todos(next_generation_at) WHERE is_active = true;
CREATE INDEX idx_recurring_todos_is_active ON recurring_todos(is_active);

COMMENT ON TABLE recurring_todos IS '定期TODO設定テーブル';
COMMENT ON COLUMN recurring_todos.recurrence_pattern IS '繰り返しパターン（daily: 毎日, weekly: 毎週, monthly: 毎月）';
COMMENT ON COLUMN recurring_todos.recurrence_days IS '繰り返し曜日または日付（weekly: 0-6, monthly: 1-31/-1）';
COMMENT ON COLUMN recurring_todos.next_generation_at IS '次回TODO自動生成日時';

-- ===================================
-- 8. Recurring Todo Assignments (定期TODO担当者)
-- ===================================
CREATE TABLE recurring_todo_assignments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  recurring_todo_id UUID NOT NULL REFERENCES recurring_todos(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE(recurring_todo_id, user_id)
);

-- 定期TODO担当者テーブルのインデックス
CREATE INDEX idx_recurring_todo_assignments_recurring_todo_id ON recurring_todo_assignments(recurring_todo_id);
CREATE INDEX idx_recurring_todo_assignments_user_id ON recurring_todo_assignments(user_id);

COMMENT ON TABLE recurring_todo_assignments IS '定期TODO担当者管理テーブル';

-- ===================================
-- Row Level Security (RLS) ポリシー
-- ===================================

-- RLS有効化
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE todos ENABLE ROW LEVEL SECURITY;
ALTER TABLE todo_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE todo_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE recurring_todos ENABLE ROW LEVEL SECURITY;
ALTER TABLE recurring_todo_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE contact_inquiries ENABLE ROW LEVEL SECURITY;

-- Users: 本人のみアクセス可能
CREATE POLICY users_select_own ON users FOR SELECT USING (id = auth.uid());
CREATE POLICY users_update_own ON users FOR UPDATE USING (id = auth.uid());

-- Groups: 所属メンバーのみアクセス可能
CREATE POLICY groups_select_member ON groups FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM group_members
    WHERE group_members.group_id = groups.id
    AND group_members.user_id = auth.uid()
  ));

CREATE POLICY groups_insert_own ON groups FOR INSERT
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY groups_update_owner ON groups FOR UPDATE
  USING (owner_id = auth.uid());

CREATE POLICY groups_delete_owner ON groups FOR DELETE
  USING (owner_id = auth.uid());

-- Group Members: 所属グループメンバーのみ閲覧、オーナーのみ追加・削除
CREATE POLICY group_members_select_member ON group_members FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM group_members gm
    WHERE gm.group_id = group_members.group_id
    AND gm.user_id = auth.uid()
  ));

CREATE POLICY group_members_insert_owner ON group_members FOR INSERT
  WITH CHECK (EXISTS (
    SELECT 1 FROM groups
    WHERE groups.id = group_members.group_id
    AND groups.owner_id = auth.uid()
  ));

CREATE POLICY group_members_delete_owner ON group_members FOR DELETE
  USING (EXISTS (
    SELECT 1 FROM groups
    WHERE groups.id = group_members.group_id
    AND groups.owner_id = auth.uid()
  ));

-- Todos: 所属グループメンバーのみアクセス
CREATE POLICY todos_select_member ON todos FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM group_members
    WHERE group_members.group_id = todos.group_id
    AND group_members.user_id = auth.uid()
  ));

CREATE POLICY todos_insert_member ON todos FOR INSERT
  WITH CHECK (EXISTS (
    SELECT 1 FROM group_members
    WHERE group_members.group_id = todos.group_id
    AND group_members.user_id = auth.uid()
  ));

CREATE POLICY todos_update_member ON todos FOR UPDATE
  USING (EXISTS (
    SELECT 1 FROM group_members
    WHERE group_members.group_id = todos.group_id
    AND group_members.user_id = auth.uid()
  ));

CREATE POLICY todos_delete_creator_or_owner ON todos FOR DELETE
  USING (
    created_by = auth.uid()
    OR EXISTS (
      SELECT 1 FROM groups
      WHERE groups.id = todos.group_id
      AND groups.owner_id = auth.uid()
    )
  );

-- Todo Assignments: 所属グループメンバーのみアクセス
CREATE POLICY todo_assignments_select_member ON todo_assignments FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM todos
    JOIN group_members ON group_members.group_id = todos.group_id
    WHERE todos.id = todo_assignments.todo_id
    AND group_members.user_id = auth.uid()
  ));

CREATE POLICY todo_assignments_insert_member ON todo_assignments FOR INSERT
  WITH CHECK (EXISTS (
    SELECT 1 FROM todos
    JOIN group_members ON group_members.group_id = todos.group_id
    WHERE todos.id = todo_assignments.todo_id
    AND group_members.user_id = auth.uid()
  ));

CREATE POLICY todo_assignments_delete_member ON todo_assignments FOR DELETE
  USING (EXISTS (
    SELECT 1 FROM todos
    JOIN group_members ON group_members.group_id = todos.group_id
    WHERE todos.id = todo_assignments.todo_id
    AND group_members.user_id = auth.uid()
  ));

-- Todo Comments: 所属グループメンバーのみアクセス
CREATE POLICY todo_comments_select_member ON todo_comments FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM todos
    JOIN group_members ON group_members.group_id = todos.group_id
    WHERE todos.id = todo_comments.todo_id
    AND group_members.user_id = auth.uid()
  ));

CREATE POLICY todo_comments_insert_member ON todo_comments FOR INSERT
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM todos
      JOIN group_members ON group_members.group_id = todos.group_id
      WHERE todos.id = todo_comments.todo_id
      AND group_members.user_id = auth.uid()
    )
  );

CREATE POLICY todo_comments_update_own ON todo_comments FOR UPDATE
  USING (user_id = auth.uid());

CREATE POLICY todo_comments_delete_own ON todo_comments FOR DELETE
  USING (user_id = auth.uid());

-- Recurring Todos: 所属グループメンバーのみアクセス
CREATE POLICY recurring_todos_select_member ON recurring_todos FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM group_members
    WHERE group_members.group_id = recurring_todos.group_id
    AND group_members.user_id = auth.uid()
  ));

CREATE POLICY recurring_todos_insert_member ON recurring_todos FOR INSERT
  WITH CHECK (
    created_by = auth.uid()
    AND EXISTS (
      SELECT 1 FROM group_members
      WHERE group_members.group_id = recurring_todos.group_id
      AND group_members.user_id = auth.uid()
    )
  );

CREATE POLICY recurring_todos_update_creator_or_owner ON recurring_todos FOR UPDATE
  USING (
    created_by = auth.uid()
    OR EXISTS (
      SELECT 1 FROM groups
      WHERE groups.id = recurring_todos.group_id
      AND groups.owner_id = auth.uid()
    )
  );

CREATE POLICY recurring_todos_delete_creator_or_owner ON recurring_todos FOR DELETE
  USING (
    created_by = auth.uid()
    OR EXISTS (
      SELECT 1 FROM groups
      WHERE groups.id = recurring_todos.group_id
      AND groups.owner_id = auth.uid()
    )
  );

-- Recurring Todo Assignments: 所属グループメンバーのみアクセス
CREATE POLICY recurring_todo_assignments_select_member ON recurring_todo_assignments FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM recurring_todos
    JOIN group_members ON group_members.group_id = recurring_todos.group_id
    WHERE recurring_todos.id = recurring_todo_assignments.recurring_todo_id
    AND group_members.user_id = auth.uid()
  ));

CREATE POLICY recurring_todo_assignments_insert_member ON recurring_todo_assignments FOR INSERT
  WITH CHECK (EXISTS (
    SELECT 1 FROM recurring_todos
    JOIN group_members ON group_members.group_id = recurring_todos.group_id
    WHERE recurring_todos.id = recurring_todo_assignments.recurring_todo_id
    AND group_members.user_id = auth.uid()
  ));

CREATE POLICY recurring_todo_assignments_delete_member ON recurring_todo_assignments FOR DELETE
  USING (EXISTS (
    SELECT 1 FROM recurring_todos
    JOIN group_members ON group_members.group_id = recurring_todos.group_id
    WHERE recurring_todos.id = recurring_todo_assignments.recurring_todo_id
    AND group_members.user_id = auth.uid()
  ));

-- Announcements: すべてのユーザーが閲覧可能
CREATE POLICY announcements_select_all ON announcements FOR SELECT
  USING (published_at <= NOW());

-- Contact Inquiries: 本人のみアクセス可能
CREATE POLICY contact_inquiries_select_own ON contact_inquiries FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY contact_inquiries_insert_own ON contact_inquiries FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY contact_inquiries_update_own ON contact_inquiries FOR UPDATE
  USING (user_id = auth.uid());

-- ===================================
-- 自動更新トリガー
-- ===================================

-- updated_at自動更新関数
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 各テーブルにupdated_at自動更新トリガーを設定
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_groups_updated_at BEFORE UPDATE ON groups
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_todos_updated_at BEFORE UPDATE ON todos
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_todo_comments_updated_at BEFORE UPDATE ON todo_comments
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_recurring_todos_updated_at BEFORE UPDATE ON recurring_todos
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_contact_inquiries_updated_at BEFORE UPDATE ON contact_inquiries
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ===================================
-- 9. Announcements (お知らせ)
-- ===================================
CREATE TABLE announcements (
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
-- 10. Contact Inquiries (お問い合わせ)
-- ===================================
CREATE TABLE contact_inquiries (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  inquiry_type TEXT NOT NULL CHECK (inquiry_type IN ('bug_report', 'feature_request', 'other')),
  message TEXT NOT NULL CHECK (char_length(message) <= 1000),
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'resolved')),

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- お問い合わせテーブルのインデックス
CREATE INDEX idx_contact_inquiries_user_id ON contact_inquiries(user_id);
CREATE INDEX idx_contact_inquiries_status ON contact_inquiries(status);
CREATE INDEX idx_contact_inquiries_created_at ON contact_inquiries(created_at DESC);

-- テーブルコメント
COMMENT ON TABLE contact_inquiries IS 'お問い合わせ情報テーブル（不具合報告・機能要望・その他）';
COMMENT ON COLUMN contact_inquiries.inquiry_type IS 'お問い合わせ種別（bug_report: 不具合報告, feature_request: 機能要望, other: その他）';
COMMENT ON COLUMN contact_inquiries.message IS 'お問い合わせ内容（1000文字以内）';
COMMENT ON COLUMN contact_inquiries.status IS '対応状況（open: 未対応, in_progress: 対応中, resolved: 解決済み）';

-- ===================================
-- 初期データ投入完了通知
-- ===================================
DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'GroupTODO Database Schema Created Successfully';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Tables Created: 10';
  RAISE NOTICE '  - users';
  RAISE NOTICE '  - groups';
  RAISE NOTICE '  - group_members';
  RAISE NOTICE '  - todos';
  RAISE NOTICE '  - todo_assignments';
  RAISE NOTICE '  - todo_comments';
  RAISE NOTICE '  - recurring_todos';
  RAISE NOTICE '  - recurring_todo_assignments';
  RAISE NOTICE '  - announcements';
  RAISE NOTICE '  - contact_inquiries';
  RAISE NOTICE 'RLS Policies: Enabled for all tables';
  RAISE NOTICE 'Indexes: Created for performance optimization';
  RAISE NOTICE '========================================';
END $$;
