// データ引き継ぎ実行 Edge Function
import { serve } from "https://deno.land/std@0.192.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

declare var Deno: any;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface TransferUserDataRequest {
  source_user_id: string
  transfer_code: string
  new_device_id: string
}

interface TransferUserDataResponse {
  success: boolean
  user?: {
    id: string
    device_id: string
    display_name: string
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

    const { source_user_id, transfer_code, new_device_id }: TransferUserDataRequest = await req.json()

    if (!source_user_id || !transfer_code || !new_device_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'source_user_id, transfer_code, and new_device_id are required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // ユーザー取得と引き継ぎコード検証
    const { data: user, error: userError } = await supabaseClient
      .from('users')
      .select('id, device_id, display_name, transfer_code, transfer_code_expires_at')
      .eq('id', source_user_id)
      .single()

    if (userError || !user) {
      return new Response(
        JSON.stringify({ success: false, error: 'User not found' }),
        {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 引き継ぎコード検証
    if (user.transfer_code !== transfer_code) {
      return new Response(
        JSON.stringify({ success: false, error: 'Invalid transfer code' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 有効期限チェック
    if (user.transfer_code_expires_at) {
      const expiresAt = new Date(user.transfer_code_expires_at)
      if (expiresAt < new Date()) {
        return new Response(
          JSON.stringify({ success: false, error: 'Transfer code has expired' }),
          {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        )
      }
    }

    // 新しいデバイスIDに紐付け
    const { data: updatedUser, error: updateError } = await supabaseClient
      .from('users')
      .update({
        device_id: new_device_id,
        transfer_code: null,
        transfer_code_expires_at: null,
        updated_at: new Date().toISOString()
      })
      .eq('id', source_user_id)
      .select('id, device_id, display_name')
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
        display_name: updatedUser.display_name
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
