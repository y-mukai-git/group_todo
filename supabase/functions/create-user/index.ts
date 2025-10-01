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
    notification_deadline: boolean
    notification_new_todo: boolean
    notification_assigned: boolean
    created_at: string
    updated_at: string
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
      .select('id, device_id, display_name, avatar_url, notification_deadline, notification_new_todo, notification_assigned, created_at, updated_at')
      .eq('device_id', device_id)
      .single()

    if (existingUser) {
      // 既存ユーザーの個人グループ存在チェック（データ整合性検証）
      const { data: personalGroup, error: groupCheckError } = await supabaseClient
        .from('groups')
        .select('id')
        .eq('owner_id', existingUser.id)
        .eq('name', '個人TODO')
        .maybeSingle()

      if (groupCheckError) {
        console.error('Personal group check failed:', groupCheckError.message)
        return new Response(
          JSON.stringify({
            success: false,
            error: `個人グループチェックエラー: ${groupCheckError.message}`
          }),
          {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        )
      }

      // データ不整合検知：既存ユーザーに個人グループが存在しない
      if (!personalGroup) {
        console.error('Data inconsistency detected: User exists but personal group does not exist', {
          user_id: existingUser.id,
          device_id: existingUser.device_id
        })
        return new Response(
          JSON.stringify({
            success: false,
            error: 'データ不整合: ユーザーは存在しますが個人TODOグループが見つかりません。データメンテナンスが必要です。'
          }),
          {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        )
      }

      return new Response(
        JSON.stringify({
          success: true,
          user: {
            id: existingUser.id,
            device_id: existingUser.device_id,
            display_name: existingUser.display_name,
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
      .select('id, device_id, display_name, avatar_url, notification_deadline, notification_new_todo, notification_assigned, created_at, updated_at')
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

    // 個人用グループ自動作成
    const { data: personalGroup, error: groupError } = await supabaseClient
      .from('groups')
      .insert({
        name: '個人TODO',
        description: '個人用のTODOグループ',
        icon_color: '#5A6978',
        owner_id: newUser.id,
        created_at: now,
        updated_at: now
      })
      .select('id')
      .single()

    if (groupError || !personalGroup) {
      console.error('Personal group creation failed:', groupError?.message)
      // グループ作成失敗してもユーザー作成は成功として返す
    } else {
      // グループメンバーに自分を追加
      const { error: memberError } = await supabaseClient
        .from('group_members')
        .insert({
          group_id: personalGroup.id,
          user_id: newUser.id,
          role: 'owner',
          joined_at: now
        })

      if (memberError) {
        console.error('Personal group member creation failed:', memberError?.message)
      }
    }

    const response: CreateUserResponse = {
      success: true,
      user: {
        id: newUser.id,
        device_id: newUser.device_id,
        display_name: newUser.display_name,
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
