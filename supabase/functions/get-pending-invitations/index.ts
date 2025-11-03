// 承認待ち招待一覧取得 Edge Function
// 自分宛の承認待ち招待一覧を取得

import { serve } from "https://deno.land/std@0.192.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

declare var Deno: any;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface GetPendingInvitationsRequest {
  user_id: string // 招待を確認するユーザーID
}

interface GetPendingInvitationsResponse {
  success: boolean
  invitations?: Array<{
    id: string
    group_id: string
    group_name: string
    group_icon_url: string | null
    inviter_id: string
    inviter_name: string
    inviter_icon_url: string | null
    invited_role: string
    invited_at: string
  }>
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

    const { user_id }: GetPendingInvitationsRequest = await req.json()

    if (!user_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'user_id is required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 承認待ち招待一覧を取得（グループ情報・招待者情報をJOIN）
    const { data: invitations, error: invitationsError } = await supabaseClient
      .from('group_invitations')
      .select(`
        id,
        group_id,
        inviter_id,
        invited_role,
        invited_at,
        groups:group_id (
          name,
          icon_url
        ),
        inviters:inviter_id (
          display_name,
          avatar_url
        )
      `)
      .eq('invited_user_id', user_id)
      .eq('status', 'pending')
      .order('invited_at', { ascending: false })

    if (invitationsError) {
      return new Response(
        JSON.stringify({ success: false, error: `Failed to get invitations: ${invitationsError.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // レスポンス整形
    const formattedInvitations = (invitations || []).map((inv: any) => ({
      id: inv.id,
      group_id: inv.group_id,
      group_name: inv.groups?.name || '不明なグループ',
      group_icon_url: inv.groups?.icon_url || null,
      inviter_id: inv.inviter_id,
      inviter_name: inv.inviters?.display_name || '不明',
      inviter_icon_url: inv.inviters?.avatar_url || null,
      invited_role: inv.invited_role,
      invited_at: inv.invited_at,
    }))

    const response: GetPendingInvitationsResponse = {
      success: true,
      invitations: formattedInvitations
    }

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Get pending invitations error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
