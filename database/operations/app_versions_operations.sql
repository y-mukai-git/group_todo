-- =====================================================
-- アプリバージョン管理テーブル用DML
-- =====================================================
--
-- 使用方法:
-- 1. 下記のテンプレートから必要なSQLをコピー
-- 2. 値を実際の内容に置き換え
-- 3. Supabaseダッシュボードで実行
--
-- =====================================================

-- -----------------------------------------------------
-- 新規バージョン登録 (INSERT)
-- -----------------------------------------------------

INSERT INTO app_versions (
  version,
  force_update_required,
  force_update_message,
  release_notes,
  release_date,
  store_url_ios,
  store_url_android
) VALUES (
  '1.0.0',                                           -- version: アプリバージョン（例: 1.0.0）
  false,                                             -- force_update_required: 強制アップデート必須（true/false）
  NULL,                                              -- force_update_message: 強制アップデート時のメッセージ（NULLまたは文字列）
  'リリースノート:
  - 新機能1
  - 新機能2
  - バグ修正',                                        -- release_notes: リリースノート（改行可）
  '2025-11-15 10:00:00+09',                          -- release_date: リリース日時（JST）
  'https://apps.apple.com/jp/app/xxxxx',             -- store_url_ios: App Store URL
  'https://play.google.com/store/apps/details?id=xxxxx' -- store_url_android: Google Play URL
);

-- 実行例（通常リリース）:
-- INSERT INTO app_versions (version, force_update_required, force_update_message, release_notes, release_date, store_url_ios, store_url_android)
-- VALUES ('1.1.0', false, NULL, '新機能を追加しました。', '2025-11-15 10:00:00+09', 'https://apps.apple.com/jp/app/xxxxx', 'https://play.google.com/store/apps/details?id=xxxxx');

-- 実行例（強制アップデート必須）:
-- INSERT INTO app_versions (version, force_update_required, force_update_message, release_notes, release_date, store_url_ios, store_url_android)
-- VALUES ('2.0.0', true, '重要な更新があります。アプリをアップデートしてください。', 'セキュリティ修正を含む重要なアップデート', '2025-12-01 10:00:00+09', 'https://apps.apple.com/jp/app/xxxxx', 'https://play.google.com/store/apps/details?id=xxxxx');


-- -----------------------------------------------------
-- 既存バージョン情報更新 (UPDATE)
-- -----------------------------------------------------

-- バージョン番号で特定して更新
UPDATE app_versions
SET
  force_update_required = true,                      -- force_update_required: 強制アップデート必須に変更
  force_update_message = '重要な更新があります。アプリをアップデートしてください。', -- force_update_message: メッセージ設定
  release_notes = '更新後のリリースノート',          -- release_notes: 更新後のリリースノート
  release_date = '2025-11-15 10:00:00+09',           -- release_date: 更新後のリリース日時
  store_url_ios = 'https://apps.apple.com/jp/app/xxxxx',       -- store_url_ios: 更新後のApp Store URL
  store_url_android = 'https://play.google.com/store/apps/details?id=xxxxx' -- store_url_android: 更新後のGoogle Play URL
WHERE
  version = '1.0.0';                                 -- version: 更新対象のバージョン番号

-- 実行例:
-- UPDATE app_versions
-- SET force_update_required = true, force_update_message = 'セキュリティ更新が必要です。'
-- WHERE version = '1.0.0';


-- IDで特定して更新
UPDATE app_versions
SET
  force_update_required = true,                      -- force_update_required: 強制アップデート必須に変更
  force_update_message = '重要な更新があります。アプリをアップデートしてください。' -- force_update_message: メッセージ設定
WHERE
  id = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx';       -- id: 更新対象のバージョンID（UUIDで指定）


-- -----------------------------------------------------
-- バージョン削除 (DELETE)
-- -----------------------------------------------------

-- バージョン番号で特定して削除
DELETE FROM app_versions
WHERE
  version = '1.0.0';                                 -- version: 削除対象のバージョン番号

-- IDで特定して削除
DELETE FROM app_versions
WHERE
  id = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx';       -- id: 削除対象のバージョンID（UUIDで指定）


-- -----------------------------------------------------
-- 確認用クエリ
-- -----------------------------------------------------

-- 全バージョン一覧を表示（新しい順）
SELECT
  id,
  version,
  force_update_required,
  force_update_message,
  release_notes,
  release_date,
  store_url_ios,
  store_url_android,
  created_at
FROM app_versions
ORDER BY release_date DESC;

-- 最新バージョンを表示
SELECT
  id,
  version,
  force_update_required,
  force_update_message,
  release_notes,
  release_date,
  store_url_ios,
  store_url_android,
  created_at
FROM app_versions
ORDER BY release_date DESC
LIMIT 1;

-- 強制アップデート必須のバージョンを表示
SELECT
  id,
  version,
  force_update_required,
  force_update_message,
  release_date
FROM app_versions
WHERE force_update_required = true
ORDER BY release_date DESC;

-- 特定バージョンを表示
SELECT
  id,
  version,
  force_update_required,
  force_update_message,
  release_notes,
  release_date,
  store_url_ios,
  store_url_android,
  created_at
FROM app_versions
WHERE version = '1.0.0';
