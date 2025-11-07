// グループ招待却下 Edge Function
// 招待を却下する

import { serve } from "https://deno.land/std@0.192.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

declare var Deno: any;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface RejectInvitationRequest {
  invitation_id: string
  user_id: string // 却下するユーザーID（招待されたユーザー本人）
}

interface RejectInvitationResponse {
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

    const { invitation_id, user_id }: RejectInvitationRequest = await req.json()

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
      .select('id, invited_user_id, status')
      .eq('id', invitation_id)
      .single()

    if (invitationError || !invitation) {
      return new Response(
        JSON.stringify({ success: false, error: 'Invitation not found' }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 本人確認
    if (invitation.invited_user_id !== user_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'Only invited user can reject invitation' }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // ステータス確認
    if (invitation.status !== 'pending') {
      return new Response(
        JSON.stringify({ success: false, error: 'Invitation is not pending' }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const now = new Date().toISOString()

    // 招待ステータスを更新
    const { error: updateError } = await supabaseClient
      .from('group_invitations')
      .update({
        status: 'rejected',
        responded_at: now
      })
      .eq('id', invitation_id)

    if (updateError) {
      return new Response(
        JSON.stringify({ success: false, error: `Failed to reject invitation: ${updateError.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const response: RejectInvitationResponse = {
      success: true
    }

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Reject invitation error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
