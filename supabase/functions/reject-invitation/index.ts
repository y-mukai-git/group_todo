// グループ招待却下 Edge Function
// 招待を却下する

import { serve } from "https://deno.land/std@0.192.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'
import { checkMaintenanceMode } from '../_shared/maintenance.ts'

declare var Deno: any;



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
    const checkResult = await checkMaintenanceMode()
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

    // 招待レコードを削除
    const { error: deleteError } = await supabaseClient
      .from('group_invitations')
      .delete()
      .eq('id', invitation_id)

    if (deleteError) {
      return new Response(
        JSON.stringify({ success: false, error: `Failed to delete invitation: ${deleteError.message}` }),
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
