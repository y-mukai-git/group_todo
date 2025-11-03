// グループ招待キャンセル Edge Function
// 招待者（オーナー）が招待をキャンセル

import { serve } from "https://deno.land/std@0.192.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

declare var Deno: any;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface CancelInvitationRequest {
  invitation_id: string
  user_id: string // キャンセルするユーザーID（招待者本人）
}

interface CancelInvitationResponse {
  success: boolean
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
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? ''
    const checkResponse = await fetch(`${supabaseUrl}/functions/v1/check-maintenance-mode`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${supabaseAnonKey}`,
      },
    })
    const checkResult = await checkResponse.json()
    if (checkResult.status === 'error' || checkResult.status === 'maintenance') {
      return new Response(
        JSON.stringify(checkResult),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const { invitation_id, user_id }: CancelInvitationRequest = await req.json()

    if (!invitation_id || !user_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'invitation_id and user_id are required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 招待情報を取得
    const { data: invitation, error: invitationError } = await supabaseClient
      .from('group_invitations')
      .select('id, group_id, inviter_id, status')
      .eq('id', invitation_id)
      .single()

    if (invitationError || !invitation) {
      return new Response(
        JSON.stringify({ success: false, error: 'Invitation not found' }),
        {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 本人確認（招待者のみキャンセル可能）
    if (invitation.inviter_id !== user_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'Only inviter can cancel invitation' }),
        {
          status: 403,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // ステータス確認（pending のみキャンセル可能）
    if (invitation.status !== 'pending') {
      return new Response(
        JSON.stringify({ success: false, error: 'Only pending invitation can be cancelled' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 招待削除
    const { error: deleteError } = await supabaseClient
      .from('group_invitations')
      .delete()
      .eq('id', invitation_id)

    if (deleteError) {
      return new Response(
        JSON.stringify({ success: false, error: `Failed to cancel invitation: ${deleteError.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const response: CancelInvitationResponse = {
      success: true
    }

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Cancel invitation error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
