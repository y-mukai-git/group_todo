// ユーザープロフィール更新 Edge Function
import { serve } from "https://deno.land/std@0.192.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

declare var Deno: any;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface UpdateUserProfileRequest {
  user_id: string
  display_name?: string
  avatar_url?: string
  notification_deadline?: boolean
  notification_new_todo?: boolean
  notification_assigned?: boolean
}

interface UpdateUserProfileResponse {
  success: boolean
  user?: {
    id: string
    display_name: string
    avatar_url: string | null
    notification_deadline: boolean
    notification_new_todo: boolean
    notification_assigned: boolean
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

    const {
      user_id,
      display_name,
      avatar_url,
      notification_deadline,
      notification_new_todo,
      notification_assigned
    }: UpdateUserProfileRequest = await req.json()

    if (!user_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'user_id is required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 更新データ準備
    const updateData: any = { updated_at: new Date().toISOString() }
    if (display_name !== undefined) updateData.display_name = display_name
    if (avatar_url !== undefined) updateData.avatar_url = avatar_url
    if (notification_deadline !== undefined) updateData.notification_deadline = notification_deadline
    if (notification_new_todo !== undefined) updateData.notification_new_todo = notification_new_todo
    if (notification_assigned !== undefined) updateData.notification_assigned = notification_assigned

    // ユーザー更新
    const { data: updatedUser, error: updateError } = await supabaseClient
      .from('users')
      .update(updateData)
      .eq('id', user_id)
      .select('id, display_name, avatar_url, notification_deadline, notification_new_todo, notification_assigned')
      .single()

    if (updateError || !updatedUser) {
      return new Response(
        JSON.stringify({ success: false, error: `Failed to update user: ${updateError?.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const response: UpdateUserProfileResponse = {
      success: true,
      user: {
        id: updatedUser.id,
        display_name: updatedUser.display_name,
        avatar_url: updatedUser.avatar_url,
        notification_deadline: updatedUser.notification_deadline,
        notification_new_todo: updatedUser.notification_new_todo,
        notification_assigned: updatedUser.notification_assigned
      }
    }

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Update user profile error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
