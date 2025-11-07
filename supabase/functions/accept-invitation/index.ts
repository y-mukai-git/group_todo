// グループ招待承認 Edge Function
// 招待を承認してグループメンバーに追加

import { serve } from "https://deno.land/std@0.192.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

declare var Deno: any;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface AcceptInvitationRequest {
  invitation_id: string
  user_id: string // 承認するユーザーID（招待されたユーザー本人）
}

interface AcceptInvitationResponse {
  success: boolean
  member?: {
    id: string
    group_id: string
    user_id: string
    role: string
    joined_at: string
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

    const { invitation_id, user_id }: AcceptInvitationRequest = await req.json()

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
      .select('id, group_id, invited_user_id, invited_role, status')
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
        JSON.stringify({ success: false, error: 'Only invited user can accept invitation' }),
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

    // 既にグループメンバーかチェック（二重追加防止）
    const { data: existingMember } = await supabaseClient
      .from('group_members')
      .select('id')
      .eq('group_id', invitation.group_id)
      .eq('user_id', user_id)
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

    const now = new Date().toISOString()

    // ユーザーの最大display_orderを取得
    const { data: maxOrderData } = await supabaseClient
      .from('group_members')
      .select('display_order')
      .eq('user_id', user_id)
      .order('display_order', { ascending: false })
      .limit(1)
      .maybeSingle()

    const displayOrder = (maxOrderData?.display_order || 0) + 1

    // 1. グループメンバーに追加（招待時のロールを使用）
    const { data: newMember, error: memberError } = await supabaseClient
      .from('group_members')
      .insert({
        group_id: invitation.group_id,
        user_id: user_id,
        role: invitation.invited_role, // 招待時に指定されたロール
        joined_at: now,
        display_order: displayOrder
      })
      .select('id, group_id, user_id, role, joined_at')
      .single()

    if (memberError || !newMember) {
      return new Response(
        JSON.stringify({ success: false, error: `Failed to add member: ${memberError?.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 2. 招待ステータスを更新
    const { error: updateError } = await supabaseClient
      .from('group_invitations')
      .update({
        status: 'accepted',
        responded_at: now
      })
      .eq('id', invitation_id)

    if (updateError) {
      // メンバー追加は成功したが、招待ステータス更新に失敗
      // この場合でも成功として扱う（メンバー追加が主目的のため）
      console.error('Failed to update invitation status:', updateError)
    }

    const response: AcceptInvitationResponse = {
      success: true,
      member: {
        id: newMember.id,
        group_id: newMember.group_id,
        user_id: newMember.user_id,
        role: newMember.role,
        joined_at: newMember.joined_at
      }
    }

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Accept invitation error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
