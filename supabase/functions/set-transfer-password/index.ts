// 引き継ぎ用パスワード設定 Edge Function
import { serve } from "https://deno.land/std@0.192.0/http/server.ts"
import { corsHeaders } from '../_shared/cors.ts'
import { checkMaintenanceMode } from '../_shared/maintenance.ts'

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

declare var Deno: any;



interface SetTransferPasswordRequest {
  user_id: string // UUID
  password: string
}

interface SetTransferPasswordResponse {
  success: boolean
  display_id?: string // 8桁ユーザーID
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
    const checkResult = await checkMaintenanceMode()
    if (checkResult.status === 'error' || checkResult.status === 'maintenance') {
      return new Response(
        JSON.stringify(checkResult),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const { user_id, password }: SetTransferPasswordRequest = await req.json()

    if (!user_id || !password) {
      return new Response(
        JSON.stringify({ success: false, error: 'user_id and password are required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // パスワードバリデーション（最低6文字）
    if (password.length < 6) {
      return new Response(
        JSON.stringify({ success: false, error: 'Password must be at least 6 characters' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // ユーザー存在確認
    const { data: user, error: userError } = await supabaseClient
      .from('users')
      .select('id, display_id')
      .eq('id', user_id)
      .single()

    if (userError || !user) {
      return new Response(
        JSON.stringify({ success: false, error: 'User not found' }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // パスワードハッシュ化（bcrypt）
    const bcrypt = await import('https://deno.land/x/bcrypt@v0.4.1/mod.ts')
    const passwordHash = await bcrypt.hash(password)

    // パスワードハッシュをDBに保存
    const { error: updateError } = await supabaseClient
      .from('users')
      .update({
        transfer_password_hash: passwordHash,
        updated_at: new Date().toISOString()
      })
      .eq('id', user_id)

    if (updateError) {
      return new Response(
        JSON.stringify({ success: false, error: `Failed to set password: ${updateError.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const response: SetTransferPasswordResponse = {
      success: true,
      display_id: user.display_id
    }

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Set transfer password error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
