-- ===================================
-- マイグレーション: スキーマ差分修正
-- ===================================
-- 実行日: 2025-10-26
-- 対象環境: DEV
-- 目的: DEV環境をDDLファイルの仕様に合わせる
--
-- 修正内容:
-- 1. usersテーブル: UNIQUE INDEXをUNIQUE制約に変更
-- 2. groupsテーブル: 不要なcategoryインデックスを削除
-- 3. error_logsテーブル: 既存ポリシーを削除して正しいポリシーを再作成
-- ===================================

-- 1. usersテーブル: UNIQUE INDEXをUNIQUE制約に変更
DROP INDEX IF EXISTS idx_users_display_id;
ALTER TABLE users ADD CONSTRAINT users_display_id_key UNIQUE (display_id);
CREATE INDEX idx_users_display_id ON users(display_id);

-- 2. groupsテーブル: 不要なcategoryインデックスを削除
DROP INDEX IF EXISTS idx_groups_category;

-- 3. error_logsテーブル: 既存ポリシーを削除して正しいポリシーを再作成
DROP POLICY IF EXISTS error_logs_select_own ON error_logs;

CREATE POLICY error_logs_select_own ON error_logs FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY error_logs_insert_all ON error_logs FOR INSERT
  WITH CHECK (true);
