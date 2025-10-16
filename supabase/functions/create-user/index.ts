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
    display_id: string // 8桁ユーザーID
    avatar_url: string | null
    notification_deadline: boolean
    notification_new_todo: boolean
    notification_assigned: boolean
    created_at: string
    updated_at: string
  }
  error?: string
}

// 8桁英数字ランダムID生成（display_id用）
function generateDisplayId(): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789' // 紛らわしい文字除外（I/O/0/1）
  let result = ''
  for (let i = 0; i < 8; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length))
  }
  return result
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
      .select('id, device_id, display_name, display_id, avatar_url, notification_deadline, notification_new_todo, notification_assigned, created_at, updated_at')
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
            display_id: existingUser.display_id,
            avatar_url: existingUser.avatar_url,
            notification_deadline: existingUser.notification_deadline,
            notification_new_todo: existingUser.notification_new_todo,
            notification_assigned: existingUser.notification_assigned,
            created_at: existingUser.created_at,
            updated_at: existingUser.updated_at
          }
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 8桁display_id生成（重複チェック付き）
    let displayId: string
    let attempts = 0
    const maxAttempts = 100

    do {
      displayId = generateDisplayId()

      const { data: duplicateIdCheck } = await supabaseClient
        .from('users')
        .select('id')
        .eq('display_id', displayId)
        .single()

      if (!duplicateIdCheck) break
      attempts++
    } while (attempts < maxAttempts)

    if (attempts >= maxAttempts) {
      return new Response(
        JSON.stringify({ success: false, error: 'Failed to generate unique display_id' }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 新規ユーザー作成（ユーザー名もdisplay_idを使用）
    const now = new Date().toISOString()
    const displayName = `ユーザー${displayId}`

    const { data: newUser, error: userError } = await supabaseClient
      .from('users')
      .insert({
        device_id: device_id,
        display_name: displayName,
        display_id: displayId,
        avatar_url: null,
        notification_deadline: true,
        notification_new_todo: true,
        notification_assigned: true,
        created_at: now,
        last_accessed_at: now,
        updated_at: now
      })
      .select('id, device_id, display_name, display_id, avatar_url, notification_deadline, notification_new_todo, notification_assigned, created_at, updated_at')
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
        display_id: newUser.display_id,
        avatar_url: newUser.avatar_url,
        notification_deadline: newUser.notification_deadline,
        notification_new_todo: newUser.notification_new_todo,
        notification_assigned: newUser.notification_assigned,
        created_at: newUser.created_at,
        updated_at: newUser.updated_at
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
