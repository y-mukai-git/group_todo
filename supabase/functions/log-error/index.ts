// エラーログDB格納 Edge Function
// アプリから送信されたエラーログをerror_logsテーブルに保存

import { serve } from "https://deno.land/std@0.192.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'
import { checkMaintenanceMode } from '../_shared/maintenance.ts'

declare var Deno: any;



interface ErrorLogRequest {
  id: string
  user_id?: string | null
  error_type: string
  error_message: string
  stack_trace?: string | null
  screen_name?: string | null
  device_info?: Record<string, any> | null
  created_at: string
}

interface ErrorLogResponse {
  success: boolean
  error_log_id?: string
  error?: string
}

serve(async (req) => {
  // CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // メンテナンスモードチェック
    const checkResult = await checkMaintenanceMode(req)
    if (checkResult.status === 'error' || checkResult.status === 'maintenance') {
      return new Response(
        JSON.stringify(checkResult),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const errorLog: ErrorLogRequest = await req.json()

    // 必須フィールドのバリデーション
    if (!errorLog.id || !errorLog.error_type || !errorLog.error_message || !errorLog.created_at) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Required fields missing: id, error_type, error_message, created_at'
        }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // error_logsテーブルに挿入
    const { data, error: insertError } = await supabaseClient
      .from('error_logs')
      .insert({
        id: errorLog.id,
        user_id: errorLog.user_id || null,
        error_type: errorLog.error_type,
        error_message: errorLog.error_message,
        stack_trace: errorLog.stack_trace || null,
        screen_name: errorLog.screen_name || null,
        device_info: errorLog.device_info || null,
        created_at: errorLog.created_at
      })
      .select('id')
      .single()

    if (insertError) {
      console.error('Error log insertion failed:', insertError.message)
      return new Response(
        JSON.stringify({
          success: false,
          error: `Database insertion failed: ${insertError.message}`
        }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const response: ErrorLogResponse = {
      success: true,
      error_log_id: data.id
    }

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Log error function error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
