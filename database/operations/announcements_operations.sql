-- =====================================================
-- お知らせ登録・更新用DML
-- =====================================================
--
-- 使用方法:
-- 1. 下記のテンプレートから必要なSQLをコピー
-- 2. 値を実際の内容に置き換え
-- 3. Supabaseダッシュボードで実行
--
-- =====================================================

-- -----------------------------------------------------
-- 新規お知らせ登録 (INSERT)
-- -----------------------------------------------------

INSERT INTO announcements (
  title,
  content,
  version,
  published_at
) VALUES (
  'タイトルをここに記載',                    -- title: お知らせタイトル
  'お知らせの本文をここに記載',              -- content: お知らせ本文（改行は実際に入れてOK）
  '1.0.0',                                  -- version: 対象アプリバージョン（例: 1.0.0, 1.0.0以降, 全バージョン）
  '2025-11-11 10:00:00+09'                  -- published_at: 公開日時（JST）
);

-- 実行例:
-- INSERT INTO announcements (title, content, version, published_at)
-- VALUES ('メンテナンスのお知らせ', '11月15日 2:00-4:00にメンテナンスを実施します。', '全バージョン', '2025-11-11 10:00:00+09');


-- -----------------------------------------------------
-- 既存お知らせ内容更新 (UPDATE)
-- -----------------------------------------------------

-- お知らせIDで特定して更新
UPDATE announcements
SET
  title = '更新後のタイトル',                 -- title: 更新後のタイトル
  content = '更新後の本文',                   -- content: 更新後の本文
  version = '1.0.0',                         -- version: 更新後の対象バージョン
  published_at = '2025-11-11 10:00:00+09'    -- published_at: 更新後の公開日時
WHERE
  id = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'; -- id: 更新対象のお知らせID（UUIDで指定）

-- 実行例:
-- UPDATE announcements
-- SET title = 'メンテナンス完了のお知らせ', content = 'メンテナンスが完了しました。', published_at = '2025-11-15 05:00:00+09'
-- WHERE id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';


-- -----------------------------------------------------
-- 既存お知らせ削除 (DELETE)
-- -----------------------------------------------------

-- お知らせIDで特定して削除
DELETE FROM announcements
WHERE
  id = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'; -- id: 削除対象のお知らせID（UUIDで指定）

-- 実行例:
-- DELETE FROM announcements WHERE id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';


-- -----------------------------------------------------
-- 確認用クエリ
-- -----------------------------------------------------

-- 全お知らせ一覧を表示（最新順）
SELECT
  id,
  title,
  content,
  version,
  published_at,
  created_at
FROM announcements
ORDER BY published_at DESC;

-- 特定のお知らせを表示
SELECT
  id,
  title,
  content,
  version,
  published_at,
  created_at
FROM announcements
WHERE id = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx';
