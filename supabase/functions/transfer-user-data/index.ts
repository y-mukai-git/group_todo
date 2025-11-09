// データ引き継ぎ実行 Edge Function
import { serve } from "https://deno.land/std@0.192.0/http/server.ts"
import { corsHeaders } from '../_shared/cors.ts'
import { checkMaintenanceMode } from '../_shared/maintenance.ts'

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

declare var Deno: any;



interface TransferUserDataRequest {
  display_id: string // 8桁ユーザーID
  password: string
  new_device_id: string
}

interface TransferUserDataResponse {
  success: boolean
  user?: {
    id: string
    device_id: string
    display_name: string
    display_id: string
  }
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

    const { display_id, password, new_device_id }: TransferUserDataRequest = await req.json()

    if (!display_id || !password || !new_device_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'display_id, password, and new_device_id are required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // ユーザー取得（8桁IDで検索）
    const { data: user, error: userError } = await supabaseClient
      .from('users')
      .select('id, device_id, display_name, display_id, transfer_password_hash')
      .eq('display_id', display_id)
      .single()

    if (userError || !user) {
      return new Response(
        JSON.stringify({ success: false, error: 'ユーザーIDまたはパスワードが正しくありません' }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // パスワード未設定チェック
    if (!user.transfer_password_hash) {
      return new Response(
        JSON.stringify({ success: false, error: 'Transfer password not set. Please set password first.' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // パスワード検証（bcrypt）
    const bcrypt = await import('https://deno.land/x/bcrypt@v0.2.4/mod.ts')
    const isPasswordValid = await bcrypt.compare(password, user.transfer_password_hash)

    if (!isPasswordValid) {
      return new Response(
        JSON.stringify({ success: false, error: 'Invalid password' }),
        {
          status: 401,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 新しいデバイスIDに紐付け（デバイスIDを書き換え）
    const { data: updatedUser, error: updateError } = await supabaseClient
      .from('users')
      .update({
        device_id: new_device_id,
        updated_at: new Date().toISOString()
      })
      .eq('id', user.id)
      .select('id, device_id, display_name, display_id')
      .single()

    if (updateError || !updatedUser) {
      return new Response(
        JSON.stringify({ success: false, error: `Failed to transfer data: ${updateError?.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const response: TransferUserDataResponse = {
      success: true,
      user: {
        id: updatedUser.id,
        device_id: updatedUser.device_id,
        display_name: updatedUser.display_name,
        display_id: updatedUser.display_id
      }
    }

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Transfer user data error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
