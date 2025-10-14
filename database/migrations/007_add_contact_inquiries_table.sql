-- Migration: Add contact_inquiries table
-- Created: 2025-10-13
-- Description: お問い合わせ機能のためのcontact_inquiriesテーブルを追加

-- ===================================
-- Contact Inquiries (お問い合わせ)
-- ===================================
CREATE TABLE IF NOT EXISTS contact_inquiries (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  inquiry_type TEXT NOT NULL CHECK (inquiry_type IN ('bug_report', 'feature_request', 'other')),
  message TEXT NOT NULL CHECK (char_length(message) <= 1000),
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'resolved')),

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- インデックス作成
CREATE INDEX IF NOT EXISTS idx_contact_inquiries_user_id ON contact_inquiries(user_id);
CREATE INDEX IF NOT EXISTS idx_contact_inquiries_status ON contact_inquiries(status);
CREATE INDEX IF NOT EXISTS idx_contact_inquiries_created_at ON contact_inquiries(created_at DESC);

-- テーブルコメント
COMMENT ON TABLE contact_inquiries IS 'お問い合わせ情報テーブル（不具合報告・機能要望・その他）';
COMMENT ON COLUMN contact_inquiries.inquiry_type IS 'お問い合わせ種別（bug_report: 不具合報告, feature_request: 機能要望, other: その他）';
COMMENT ON COLUMN contact_inquiries.message IS 'お問い合わせ内容（1000文字以内）';
COMMENT ON COLUMN contact_inquiries.status IS '対応状況（open: 未対応, in_progress: 対応中, resolved: 解決済み）';

-- RLS有効化
ALTER TABLE contact_inquiries ENABLE ROW LEVEL SECURITY;

-- RLSポリシー作成
CREATE POLICY contact_inquiries_select_own ON contact_inquiries FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY contact_inquiries_insert_own ON contact_inquiries FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY contact_inquiries_update_own ON contact_inquiries FOR UPDATE
  USING (user_id = auth.uid());

-- updated_at自動更新トリガー
CREATE TRIGGER update_contact_inquiries_updated_at BEFORE UPDATE ON contact_inquiries
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
