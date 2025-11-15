// グループメンバー削除 Edge Function
import { serve } from "https://deno.land/std@0.192.0/http/server.ts"
import { corsHeaders } from '../_shared/cors.ts'
import { checkMaintenanceMode } from '../_shared/maintenance.ts'
import { checkGroupMembership } from '../_shared/permission.ts'

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

declare var Deno: any;



interface RemoveGroupMemberRequest {
  group_id: string
  target_user_id: string // 削除対象のユーザーID
  requester_id: string // 削除実行者のユーザーID
}

interface RemoveGroupMemberResponse {
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

    const { group_id, target_user_id, requester_id }: RemoveGroupMemberRequest = await req.json()

    if (!group_id || !target_user_id || !requester_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'group_id, target_user_id, and requester_id are required' }),
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

    // 削除対象がオーナーの場合は削除不可
    if (group.owner_id === target_user_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'Cannot remove group owner' }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 権限チェック：オーナーまたは本人のみ削除可能
    const isOwner = group.owner_id === requester_id
    const isSelf = target_user_id === requester_id

    if (!isOwner && !isSelf) {
      return new Response(
        JSON.stringify({ success: false, error: 'Only group owner or the member themselves can remove member' }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // タスク再割り当て処理（メンバー削除前に実行）
    // 1. 削除対象メンバーの担当タスクを取得
    const { data: assignments } = await supabaseClient
      .from('todo_assignments')
      .select('todo_id')
      .eq('user_id', target_user_id)

    if (assignments && assignments.length > 0) {
      // 2. 残りのグループメンバーを取得（削除対象を除く）
      const { data: remainingMembers } = await supabaseClient
        .from('group_members')
        .select(`
          user_id,
          users:user_id (
            id,
            role,
            created_at
          )
        `)
        .eq('group_id', group_id)
        .neq('user_id', target_user_id)

      if (remainingMembers && remainingMembers.length > 0) {
        // 3. メンバーを優先度順にソート
        const sortedMembers = remainingMembers
          .map((m: any) => ({
            user_id: m.user_id,
            role: m.users?.role,
            created_at: m.users?.created_at
          }))
          .sort((a: any, b: any) => {
            // 優先度計算関数
            const getPriority = (member: any) => {
              const isGroupOwner = member.user_id === group.owner_id
              const isOwnerRole = member.role === 'owner'

              if (isGroupOwner && isOwnerRole) return 1 // 管理者(オーナー)
              if (!isGroupOwner && isOwnerRole) return 2 // オーナー
              if (isGroupOwner && !isOwnerRole) return 3 // 管理者(メンバー)
              return 4 // メンバー
            }

            const priorityA = getPriority(a)
            const priorityB = getPriority(b)

            // 優先度で比較
            if (priorityA !== priorityB) return priorityA - priorityB

            // 同優先度の場合は加入日時で比較（古い順）
            return new Date(a.created_at).getTime() - new Date(b.created_at).getTime()
          })

        // 4. 最優先メンバーにタスクを再割り当て
        const newAssigneeId = sortedMembers[0].user_id
        const todoIds = assignments.map((a: any) => a.todo_id)

        await supabaseClient
          .from('todo_assignments')
          .update({ user_id: newAssigneeId })
          .in('todo_id', todoIds)
          .eq('user_id', target_user_id)
      }
      // 残りメンバーが0人の場合は再割り当てせず、タスクの担当者は削除される
    }

    // メンバー削除
    const { error: deleteError } = await supabaseClient
      .from('group_members')
      .delete()
      .eq('group_id', group_id)
      .eq('user_id', target_user_id)

    if (deleteError) {
      return new Response(
        JSON.stringify({ success: false, error: `Failed to remove member: ${deleteError.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const response: RemoveGroupMemberResponse = {
      success: true
    }

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Remove group member error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
