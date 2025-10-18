-- ===================================
-- Announcements Initial Data (お知らせ初期データ)
-- 作成日: 2025-10-16
-- 説明: 正式リリース(v1.0.0)のお知らせデータ投入
-- ===================================

-- バージョン 1.0.0 正式リリースのお知らせ
INSERT INTO announcements (
  version,
  title,
  content,
  published_at
) VALUES (
  '1.0.0',
  'グループTODO v1.0.0 正式リリース🎉',
  E'グループTODOアプリの正式版をリリースしました！\n\n【主な機能】\n・グループでのTODO管理\n・メンバー招待機能\n・リアルタイム同期\n・プロフィール設定\n・データ引き継ぎ機能\n\n今後も定期的にアップデートを行い、より使いやすいアプリを目指してまいります。\n\nご利用いただき、ありがとうございます！',
  NOW() - INTERVAL '1 hour'
);

-- ===================================
-- データ投入完了通知
-- ===================================
DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Announcements Initial Data Inserted';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Version: 1.0.0 (正式リリース)';
  RAISE NOTICE 'Records: 1';
  RAISE NOTICE 'Published: NOW() - 1 hour (即時表示)';
  RAISE NOTICE '========================================';
END $$;