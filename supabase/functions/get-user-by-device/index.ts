// デバイスIDでユーザー取得 Edge Function
import { serve } from "https://deno.land/std@0.192.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'
import { checkMaintenanceMode } from '../_shared/maintenance.ts'

declare var Deno: any;



interface GetUserRequest {
  device_id: string
}

interface GetUserResponse {
  success: boolean
  user?: {
    id: string
    device_id: string
    display_name: string
    display_id: string // 8桁ユーザーID
    avatar_url: string | null
    signed_avatar_url?: string // 署名付きURL（有効期限1時間）
    notification_deadline: boolean
    notification_new_todo: boolean
    notification_assigned: boolean
    created_at: string
    last_accessed_at: string
    updated_at: string
  }
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
    const checkResult = await checkMaintenanceMode()
    if (checkResult.status === 'error' || checkResult.status === 'maintenance') {
      return new Response(
        JSON.stringify(checkResult),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const { device_id }: GetUserRequest = await req.json()

    if (!device_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'device_id is required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // ユーザー取得
    const { data: user, error: userError } = await supabaseClient
      .from('users')
      .select('id, device_id, display_name, display_id, avatar_url, notification_deadline, notification_new_todo, notification_assigned, created_at, last_accessed_at, updated_at')
      .eq('device_id', device_id)
      .single()

    if (userError) {
      // DBエラー - システムエラーとして返す
      return new Response(
        JSON.stringify({ success: false, error: userError.message }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    if (!user) {
      // ユーザー未検出 - 正常なレスポンス（データが存在しないことを示す）
      return new Response(
        JSON.stringify({ success: true, user: null }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 最終アクセス日時更新
    await supabaseClient
      .from('users')
      .update({ last_accessed_at: new Date().toISOString() })
      .eq('id', user.id)

    // 署名付きURL生成（avatar_urlが存在する場合）
    let signedAvatarUrl: string | null = null
    if (user.avatar_url) {
      const { data: signedUrlData, error: signedUrlError } = await supabaseClient
        .storage
        .from('user-avatars')
        .createSignedUrl(user.avatar_url, 3600) // 有効期限1時間

      if (signedUrlError) {
        throw new Error(`Failed to create signed URL: ${signedUrlError.message}`)
      }

      signedAvatarUrl = signedUrlData.signedUrl
    }

    const response: GetUserResponse = {
      success: true,
      user: {
        id: user.id,
        device_id: user.device_id,
        display_name: user.display_name,
        display_id: user.display_id,
        avatar_url: user.avatar_url,
        signed_avatar_url: signedAvatarUrl,
        notification_deadline: user.notification_deadline,
        notification_new_todo: user.notification_new_todo,
        notification_assigned: user.notification_assigned,
        created_at: user.created_at,
        last_accessed_at: user.last_accessed_at,
        updated_at: user.updated_at
      }
    }

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Get user error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
