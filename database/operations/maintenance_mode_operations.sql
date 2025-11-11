-- =====================================================
-- メンテナンスモード設定・解除用DML
-- =====================================================
--
-- 使用方法:
-- 1. 下記のテンプレートから必要なSQLをコピー
-- 2. 値を実際の内容に置き換え
-- 3. Supabaseダッシュボードで実行
--
-- 注意:
-- - maintenance_mode テーブルは通常1レコードのみ存在
-- - 初回はINSERT、2回目以降はUPDATEを使用
--
-- =====================================================

-- -----------------------------------------------------
-- メンテナンスモード設定（開始）
-- -----------------------------------------------------

-- 既存レコードがある場合はUPDATEを使用
UPDATE maintenance_mode
SET
  is_maintenance = true,                             -- メンテナンス中フラグ: true
  maintenance_message = 'メンテナンス中です。完了までしばらくお待ちください。', -- メンテナンスメッセージ
  start_time = '2025-11-15 02:00:00+09',             -- メンテナンス開始時刻（JST）
  end_time = '2025-11-15 04:00:00+09',               -- メンテナンス終了予定時刻（JST）
  updated_at = NOW()                                 -- 更新日時
WHERE
  id = (SELECT id FROM maintenance_mode LIMIT 1);    -- 既存レコードのIDを取得

-- 実行例:
-- UPDATE maintenance_mode
-- SET is_maintenance = true, maintenance_message = 'システムメンテナンス中です。', start_time = '2025-11-15 02:00:00+09', end_time = '2025-11-15 04:00:00+09', updated_at = NOW()
-- WHERE id = (SELECT id FROM maintenance_mode LIMIT 1);


-- 初回のみ: レコードが存在しない場合はINSERTを使用
INSERT INTO maintenance_mode (
  is_maintenance,
  maintenance_message,
  start_time,
  end_time
) VALUES (
  true,                                              -- メンテナンス中フラグ: true
  'メンテナンス中です。完了までしばらくお待ちください。', -- メンテナンスメッセージ
  '2025-11-15 02:00:00+09',                          -- メンテナンス開始時刻（JST）
  '2025-11-15 04:00:00+09'                           -- メンテナンス終了予定時刻（JST）
);


-- -----------------------------------------------------
-- メンテナンスモード解除（終了）
-- -----------------------------------------------------

UPDATE maintenance_mode
SET
  is_maintenance = false,                            -- メンテナンス中フラグ: false
  maintenance_message = NULL,                        -- メッセージをクリア
  end_time = NOW(),                                  -- 実際の終了時刻を記録
  updated_at = NOW()                                 -- 更新日時
WHERE
  id = (SELECT id FROM maintenance_mode LIMIT 1);    -- 既存レコードのIDを取得

-- 実行例:
-- UPDATE maintenance_mode
-- SET is_maintenance = false, maintenance_message = NULL, end_time = NOW(), updated_at = NOW()
-- WHERE id = (SELECT id FROM maintenance_mode LIMIT 1);


-- -----------------------------------------------------
-- 確認用クエリ
-- -----------------------------------------------------

-- 現在のメンテナンス状態を表示
SELECT
  id,
  is_maintenance,
  maintenance_message,
  start_time,
  end_time,
  created_at,
  updated_at
FROM maintenance_mode
LIMIT 1;

-- メンテナンス中かどうかを確認（true/falseのみ表示）
SELECT is_maintenance
FROM maintenance_mode
LIMIT 1;
