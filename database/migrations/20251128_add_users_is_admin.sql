-- 管理者フラグ追加マイグレーション
-- 作成日: 2025-11-28
-- 目的: メンテナンスモード中でも管理者がアプリを利用できるようにするため

-- usersテーブルに管理者フラグを追加
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_admin BOOLEAN NOT NULL DEFAULT false;

-- コメント追加
COMMENT ON COLUMN users.is_admin IS '管理者フラグ（true: 管理者、false: 一般ユーザー）。管理者はメンテナンスモード中でもアプリを利用可能';

-- インデックス追加（管理者の検索用）
CREATE INDEX IF NOT EXISTS idx_users_is_admin ON users(is_admin) WHERE is_admin = true;
