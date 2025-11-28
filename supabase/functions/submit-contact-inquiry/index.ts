// お問い合わせ送信 Edge Function
import { serve } from "https://deno.land/std@0.192.0/http/server.ts"
import { corsHeaders } from '../_shared/cors.ts'
import { checkMaintenanceMode } from '../_shared/maintenance.ts'

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

declare var Deno: any;



interface SubmitContactInquiryRequest {
  user_id: string
  inquiry_type: string  // 'bug_report' | 'feature_request' | 'other'
  message: string
}

interface SubmitContactInquiryResponse {
  success: boolean
  inquiry_id?: string
  error?: string
}

serve(async (req) => {
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

    const { user_id, inquiry_type, message }: SubmitContactInquiryRequest = await req.json()

    // バリデーション
    if (!user_id || !inquiry_type || !message) {
      return new Response(
        JSON.stringify({ success: false, error: 'user_id, inquiry_type, message are required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // inquiry_type の値チェック
    const validTypes = ['bug_report', 'feature_request', 'other']
    if (!validTypes.includes(inquiry_type)) {
      return new Response(
        JSON.stringify({ success: false, error: 'Invalid inquiry_type' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // contact_inquiries テーブルに挿入
    const { data: inquiry, error: insertError } = await supabaseClient
      .from('contact_inquiries')
      .insert({
        user_id,
        inquiry_type,
        message,
        status: 'open',
      })
      .select('id')
      .single()

    if (insertError || !inquiry) {
      console.error('Insert error:', insertError)
      return new Response(
        JSON.stringify({ success: false, error: `Failed to submit inquiry: ${insertError?.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const response: SubmitContactInquiryResponse = {
      success: true,
      inquiry_id: inquiry.id
    }

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Submit contact inquiry error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
