// グループメンバーロール変更 Edge Function
import { serve } from "https://deno.land/std@0.192.0/http/server.ts"
import { corsHeaders } from '../_shared/cors.ts'
import { checkMaintenanceMode } from '../_shared/maintenance.ts'
import { checkGroupMembership } from '../_shared/permission.ts'

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

declare var Deno: any;



interface ChangeMemberRoleRequest {
  group_id: string
  target_user_id: string // ロール変更対象のユーザーID
  new_role: string // 新しいロール（'owner' or 'member'）
  requester_id: string // ロール変更実行者のユーザーID
}

interface GroupMember {
  id: string
  display_name: string
  display_id: string
  role: string
}

interface ChangeMemberRoleResponse {
  success: boolean
  members?: GroupMember[]
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

    const { group_id, target_user_id, new_role, requester_id }: ChangeMemberRoleRequest = await req.json()

    // パラメータチェック
    if (!group_id || !target_user_id || !new_role || !requester_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'group_id, target_user_id, new_role, and requester_id are required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // ロール値チェック
    if (new_role !== 'owner' && new_role !== 'member') {
      return new Response(
        JSON.stringify({ success: false, error: 'new_role must be either "owner" or "member"' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // メンバーシップチェック
    const membershipCheck = await checkGroupMembership(supabaseClient, group_id, requester_id)
    if (!membershipCheck.success) {
      return new Response(
        JSON.stringify({ success: false, error: membershipCheck.error }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // グループ取得
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

    // 権限チェック：オーナーのみロール変更可能
    if (group.owner_id !== requester_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'Only group owner can change member roles' }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 自分自身のロールは変更不可
    if (target_user_id === requester_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'Cannot change your own role' }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // ロール変更
    const { error: updateError } = await supabaseClient
      .from('group_members')
      .update({ role: new_role })
      .eq('group_id', group_id)
      .eq('user_id', target_user_id)

    if (updateError) {
      return new Response(
        JSON.stringify({ success: false, error: `Failed to change member role: ${updateError.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 更新後のメンバー一覧を取得
    const { data: membersData, error: membersError } = await supabaseClient
      .from('group_members')
      .select(`
        user_id,
        role,
        users (
          id,
          display_name,
          display_id
        )
      `)
      .eq('group_id', group_id)

    if (membersError || !membersData) {
      return new Response(
        JSON.stringify({ success: false, error: `Failed to fetch updated members: ${membersError?.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // メンバー一覧を整形
    const members: GroupMember[] = membersData.map((m: any) => ({
      id: m.users.id,
      display_name: m.users.display_name,
      display_id: m.users.display_id,
      role: m.role
    }))

    const response: ChangeMemberRoleResponse = {
      success: true,
      members: members
    }

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Change member role error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
