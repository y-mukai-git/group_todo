// デバイスIDでユーザー取得 Edge Function
import { serve } from "https://deno.land/std@0.192.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

declare var Deno: any;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

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
    notification_deadline: boolean
    notification_new_todo: boolean
    notification_assigned: boolean
    created_at: string
    last_accessed_at: string
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
      .select('id, device_id, display_name, display_id, avatar_url, notification_deadline, notification_new_todo, notification_assigned, created_at, last_accessed_at')
      .eq('device_id', device_id)
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

    // 最終アクセス日時更新
    await supabaseClient
      .from('users')
      .update({ last_accessed_at: new Date().toISOString() })
      .eq('id', user.id)

    const response: GetUserResponse = {
      success: true,
      user: {
        id: user.id,
        device_id: user.device_id,
        display_name: user.display_name,
        display_id: user.display_id,
        avatar_url: user.avatar_url,
        notification_deadline: user.notification_deadline,
        notification_new_todo: user.notification_new_todo,
        notification_assigned: user.notification_assigned,
        created_at: user.created_at,
        last_accessed_at: user.last_accessed_at
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
