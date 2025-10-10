-- Migration: Cleanup display_id SQL Functions and Triggers
-- 既に実行済みの001_add_display_id.sqlで作成されたFunction/Triggerを削除
-- 作成日: 2025-10-06
-- 理由: Edge Functionに処理を集約するため、SQL Function/Triggerは不要

-- ===================================
-- 1. Trigger削除
-- ===================================
DROP TRIGGER IF EXISTS trigger_set_display_id ON users;

-- ===================================
-- 2. Function削除
-- ===================================
DROP FUNCTION IF EXISTS set_display_id();
DROP FUNCTION IF EXISTS generate_display_id();

-- Migration完了
SELECT 'Migration 002_cleanup_display_id_functions.sql completed successfully' AS status;
