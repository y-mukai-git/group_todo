-- app_versions と maintenance_mode にRLSを追加
-- 既存環境への適用用migration

-- RLS有効化
ALTER TABLE app_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE maintenance_mode ENABLE ROW LEVEL SECURITY;

-- App Versions: 全ユーザーが読み取り可能（アプリ起動時のバージョンチェック用）
CREATE POLICY app_versions_select_all ON app_versions FOR SELECT
  USING (true);

-- Maintenance Mode: 全ユーザーが読み取り可能（メンテナンスモードチェック用）
CREATE POLICY maintenance_mode_select_all ON maintenance_mode FOR SELECT
  USING (true);

-- INSERT/UPDATE/DELETEは管理者のみ（Supabaseコンソール/Edge Functionから実行）
-- RLSポリシーでは制限せず、運用で制御
