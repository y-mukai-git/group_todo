// ユーザー作成処理 Edge Function
// デバイスIDベースでユーザーを自動作成
import { serve } from "https://deno.land/std@0.192.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

declare var Deno: any;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface CreateUserRequest {
  device_id: string
}

interface CreateUserResponse {
  success: boolean
  user?: {
    id: string
    device_id: string
    display_name: string
    avatar_url: string | null
    created_at: string
  }
  error?: string
}

// 8桁の数字生成（ユーザー名用）
function generateUserNumber(): string {
  return Math.floor(10000000 + Math.random() * 90000000).toString()
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

    const { device_id }: CreateUserRequest = await req.json()

    if (!device_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'device_id is required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 既存ユーザーチェック
    const { data: existingUser } = await supabaseClient
      .from('users')
      .select('id, device_id, display_name, avatar_url, created_at')
      .eq('device_id', device_id)
      .single()

    if (existingUser) {
      return new Response(
        JSON.stringify({
          success: true,
          user: {
            id: existingUser.id,
            device_id: existingUser.device_id,
            display_name: existingUser.display_name,
            avatar_url: existingUser.avatar_url,
            created_at: existingUser.created_at
          }
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 新規ユーザー名生成（重複チェック付き）
    let displayName: string
    let attempts = 0
    const maxAttempts = 100

    do {
      const userNumber = generateUserNumber()
      displayName = `ユーザー${userNumber}`

      const { data: duplicateCheck } = await supabaseClient
        .from('users')
        .select('id')
        .eq('display_name', displayName)
        .single()

      if (!duplicateCheck) break
      attempts++
    } while (attempts < maxAttempts)

    if (attempts >= maxAttempts) {
      return new Response(
        JSON.stringify({ success: false, error: 'Failed to generate unique display name' }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 新規ユーザー作成
    const now = new Date().toISOString()

    const { data: newUser, error: userError } = await supabaseClient
      .from('users')
      .insert({
        device_id: device_id,
        display_name: displayName,
        avatar_url: null,
        notification_deadline: true,
        notification_new_todo: true,
        notification_assigned: true,
        created_at: now,
        last_accessed_at: now,
        updated_at: now
      })
      .select('id, device_id, display_name, avatar_url, created_at')
      .single()

    if (userError || !newUser) {
      return new Response(
        JSON.stringify({ success: false, error: `User creation failed: ${userError?.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const response: CreateUserResponse = {
      success: true,
      user: {
        id: newUser.id,
        device_id: newUser.device_id,
        display_name: newUser.display_name,
        avatar_url: newUser.avatar_url,
        created_at: newUser.created_at
      }
    }

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Create user error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
