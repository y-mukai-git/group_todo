/**
 * CORS設定
 * 全Edge Functionで共通使用
 */
export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-admin-skip-maintenance',
}
