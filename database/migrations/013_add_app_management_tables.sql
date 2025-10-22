-- メンテナンスモード管理テーブル
CREATE TABLE IF NOT EXISTS maintenance_mode (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  is_maintenance BOOLEAN NOT NULL DEFAULT false,
  maintenance_message TEXT,
  start_time TIMESTAMP WITH TIME ZONE,
  end_time TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 初期データ挿入（メンテナンスOFF）
INSERT INTO maintenance_mode (is_maintenance, maintenance_message)
VALUES (false, 'システムメンテナンス中です。しばらくお待ちください。')
ON CONFLICT DO NOTHING;

COMMENT ON TABLE maintenance_mode IS 'メンテナンスモード管理';
COMMENT ON COLUMN maintenance_mode.is_maintenance IS 'メンテナンス中フラグ';
COMMENT ON COLUMN maintenance_mode.maintenance_message IS 'メンテナンス画面に表示するメッセージ';
COMMENT ON COLUMN maintenance_mode.start_time IS 'メンテナンス開始時刻';
COMMENT ON COLUMN maintenance_mode.end_time IS 'メンテナンス終了予定時刻';

-- アプリバージョン管理テーブル
CREATE TABLE IF NOT EXISTS app_versions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  version VARCHAR(20) UNIQUE NOT NULL,
  force_update_required BOOLEAN NOT NULL DEFAULT false,
  release_date TIMESTAMP WITH TIME ZONE,
  release_notes TEXT,
  force_update_message TEXT,
  store_url_ios TEXT,
  store_url_android TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 初期データ挿入（現在のバージョン）
INSERT INTO app_versions (
  version,
  force_update_required,
  release_date,
  release_notes,
  force_update_message,
  store_url_ios,
  store_url_android
)
VALUES (
  '1.0.0',
  false,
  NOW(),
  '初回リリース',
  NULL,
  NULL,
  NULL
)
ON CONFLICT (version) DO NOTHING;

COMMENT ON TABLE app_versions IS 'アプリバージョン管理';
COMMENT ON COLUMN app_versions.version IS 'バージョン番号 (例: 1.0.0)';
COMMENT ON COLUMN app_versions.force_update_required IS '強制アップデート必須フラグ';
COMMENT ON COLUMN app_versions.release_date IS 'リリース日';
COMMENT ON COLUMN app_versions.release_notes IS 'リリースノート';
COMMENT ON COLUMN app_versions.force_update_message IS '強制アップデート時に表示するメッセージ';
COMMENT ON COLUMN app_versions.store_url_ios IS 'App StoreのURL';
COMMENT ON COLUMN app_versions.store_url_android IS 'Google PlayのURL';
