// グループ招待実行 Edge Function
// ユーザーを指定ロール（owner/member）でグループに招待

import { serve } from "https://deno.land/std@0.192.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'
import { checkMaintenanceMode } from '../_shared/maintenance.ts'

declare var Deno: any;



interface InviteUserRequest {
  group_id: string
  invited_user_id: string // 招待するユーザーのUUID
  invited_role: 'owner' | 'member' // 招待時のロール
  inviter_id: string // 招待者のユーザーID（権限チェック用）
}

interface InviteUserResponse {
  success: boolean
  invitation?: {
    id: string
    group_id: string
    invited_user_id: string
    invited_role: string
    status: string
    invited_at: string
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

    const { group_id, invited_user_id, invited_role, inviter_id }: InviteUserRequest = await req.json()

    if (!group_id || !invited_user_id || !invited_role || !inviter_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'group_id, invited_user_id, invited_role, and inviter_id are required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // ロール検証
    if (invited_role !== 'owner' && invited_role !== 'member') {
      return new Response(
        JSON.stringify({ success: false, error: 'invited_role must be owner or member' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 招待者がグループのオーナーかチェック
    const { data: memberCheck, error: memberError } = await supabaseClient
      .from('group_members')
      .select('role')
      .eq('group_id', group_id)
      .eq('user_id', inviter_id)
      .single()

    if (memberError || !memberCheck) {
      return new Response(
        JSON.stringify({ success: false, error: 'Inviter is not a member of this group' }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    if (memberCheck.role !== 'owner') {
      return new Response(
        JSON.stringify({ success: false, error: 'Only group owner can invite members' }),
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
      .eq('user_id', invited_user_id)
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
      .eq('invited_user_id', invited_user_id)
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

    // 招待を作成
    const now = new Date().toISOString()

    const { data: newInvitation, error: invitationError } = await supabaseClient
      .from('group_invitations')
      .insert({
        group_id: group_id,
        inviter_id: inviter_id,
        invited_user_id: invited_user_id,
        invited_role: invited_role,
        status: 'pending',
        invited_at: now
      })
      .select('id, group_id, invited_user_id, invited_role, status, invited_at')
      .single()

    if (invitationError || !newInvitation) {
      return new Response(
        JSON.stringify({ success: false, error: `Failed to create invitation: ${invitationError?.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const response: InviteUserResponse = {
      success: true,
      invitation: {
        id: newInvitation.id,
        group_id: newInvitation.group_id,
        invited_user_id: newInvitation.invited_user_id,
        invited_role: newInvitation.invited_role,
        status: newInvitation.status,
        invited_at: newInvitation.invited_at
      }
    }

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Invite user error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
