// グループメンバー追加 Edge Function
// ユーザーIDで直接メンバーを追加

import { serve } from "https://deno.land/std@0.192.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'
import { checkMaintenanceMode } from '../_shared/maintenance.ts'
import { checkGroupMembership } from '../_shared/permission.ts'

declare var Deno: any;



interface AddGroupMemberRequest {
  group_id: string
  display_id: string // 招待するユーザーの display_id（8桁英数字）
  inviter_id: string // 招待者のユーザーID（権限チェック用）
}

interface AddGroupMemberResponse {
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
    const checkResult = await checkMaintenanceMode(req)
    if (checkResult.status === 'error' || checkResult.status === 'maintenance') {
      return new Response(
        JSON.stringify(checkResult),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const { group_id, display_id, inviter_id }: AddGroupMemberRequest = await req.json()

    if (!group_id || !display_id || !inviter_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'group_id, display_id, and inviter_id are required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // メンバーシップチェック
    const membershipCheck = await checkGroupMembership(supabaseClient, group_id, inviter_id)
    if (!membershipCheck.success) {
      return new Response(
        JSON.stringify({ success: false, error: membershipCheck.error }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 招待者がグループのオーナーかチェック
    const { data: group, error: groupError } = await supabaseClient
      .from('groups')
      .select('owner_id')
      .eq('id', group_id)
      .single()

    if (groupError || !group) {
      return new Response(
        JSON.stringify({ success: false, error: 'Group not found' }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    if (group.owner_id !== inviter_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'Only group owner can add members' }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 追加するユーザーが存在するかチェック（display_id で検索）
    const { data: targetUser, error: userError } = await supabaseClient
      .from('users')
      .select('id')
      .eq('display_id', display_id)
      .single()

    if (userError || !targetUser) {
      return new Response(
        JSON.stringify({ success: false, error: 'User not found' }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // display_id から取得した user_id (UUID) を使用
    const user_id = targetUser.id

    // 既にメンバーかチェック
    const { data: existingMember } = await supabaseClient
      .from('group_members')
      .select('id')
      .eq('group_id', group_id)
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

    // ユーザーの最大display_orderを取得
    const { data: maxOrderData } = await supabaseClient
      .from('group_members')
      .select('display_order')
      .eq('user_id', user_id)
      .order('display_order', { ascending: false })
      .limit(1)
      .maybeSingle()

    const displayOrder = (maxOrderData?.display_order || 0) + 1

    // グループメンバーに追加
    const now = new Date().toISOString()

    const { data: newMember, error: memberError } = await supabaseClient
      .from('group_members')
      .insert({
        group_id: group_id,
        user_id: user_id,
        role: 'member',
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

    const response: AddGroupMemberResponse = {
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
    console.error('Add group member error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
