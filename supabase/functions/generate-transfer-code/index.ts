// データ引き継ぎコード生成 Edge Function
import { serve } from "https://deno.land/std@0.192.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

declare var Deno: any;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface GenerateTransferCodeRequest {
  user_id: string
}

interface GenerateTransferCodeResponse {
  success: boolean
  transfer_code?: string
  expires_at?: string
  error?: string
}

// 8桁英数字の引き継ぎコード生成
function generateTransferCode(): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789' // 紛らわしい文字を除外
  let code = ''
  for (let i = 0; i < 8; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length))
  }
  return code
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

    const { user_id }: GenerateTransferCodeRequest = await req.json()

    if (!user_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'user_id is required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 引き継ぎコード生成（重複チェック）
    let transferCode: string
    let attempts = 0
    const maxAttempts = 10

    do {
      transferCode = generateTransferCode()
      const { data: duplicateCheck } = await supabaseClient
        .from('users')
        .select('id')
        .eq('transfer_code', transferCode)
        .single()

      if (!duplicateCheck) break
      attempts++
    } while (attempts < maxAttempts)

    if (attempts >= maxAttempts) {
      return new Response(
        JSON.stringify({ success: false, error: 'Failed to generate unique transfer code' }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 有効期限：24時間後
    const expiresAt = new Date()
    expiresAt.setHours(expiresAt.getHours() + 24)

    // 引き継ぎコードを保存
    const { error: updateError } = await supabaseClient
      .from('users')
      .update({
        transfer_code: transferCode,
        transfer_code_expires_at: expiresAt.toISOString(),
        updated_at: new Date().toISOString()
      })
      .eq('id', user_id)

    if (updateError) {
      return new Response(
        JSON.stringify({ success: false, error: `Failed to save transfer code: ${updateError.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const response: GenerateTransferCodeResponse = {
      success: true,
      transfer_code: transferCode,
      expires_at: expiresAt.toISOString()
    }

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Generate transfer code error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
