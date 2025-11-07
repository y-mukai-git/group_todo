// ユーザー情報取得（招待確認用） Edge Function
// display_idからユーザー情報を取得し、招待確認ダイアログで表示

import { serve } from "https://deno.land/std@0.192.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'
import { checkMaintenanceMode } from '../_shared/maintenance.ts'

declare var Deno: any;



interface ValidateUserRequest {
  display_id: string // 招待するユーザーのdisplay_id（8桁英数字）
  group_id: string // 招待先のグループID（既存メンバーチェック用）
}

interface ValidateUserResponse {
  success: boolean
  user?: {
    id: string
    display_id: string
    display_name: string
    avatar_url: string | null
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

    const { display_id, group_id }: ValidateUserRequest = await req.json()

    if (!display_id || !group_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'display_id and group_id are required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // ユーザー情報を取得
    const { data: user, error: userError } = await supabaseClient
      .from('users')
      .select('id, display_id, display_name, avatar_url')
      .eq('display_id', display_id)
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

    // 既にグループメンバーかチェック
    const { data: existingMember } = await supabaseClient
      .from('group_members')
      .select('id')
      .eq('group_id', group_id)
      .eq('user_id', user.id)
      .single()

    if (existingMember) {
      return new Response(
        JSON.stringify({ success: false, error: 'User is already a member of this group' }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 既に招待中（pending）かチェック
    const { data: existingInvitation } = await supabaseClient
      .from('group_invitations')
      .select('id')
      .eq('group_id', group_id)
      .eq('invited_user_id', user.id)
      .eq('status', 'pending')
      .single()

    if (existingInvitation) {
      return new Response(
        JSON.stringify({ success: false, error: 'User is already invited to this group' }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const response: ValidateUserResponse = {
      success: true,
      user: {
        id: user.id,
        display_id: user.display_id,
        display_name: user.display_name,
        avatar_url: user.avatar_url
      }
    }

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Validate user for invitation error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
