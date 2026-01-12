// TODO更新 Edge Function
import { serve } from "https://deno.land/std@0.192.0/http/server.ts"
import { corsHeaders } from '../_shared/cors.ts'
import { checkMaintenanceMode } from '../_shared/maintenance.ts'
import { checkGroupMembership, checkAssigneesAreMembers } from '../_shared/permission.ts'

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

declare var Deno: any;



interface UpdateTodoRequest {
  todo_id: string
  user_id: string // 操作者（作成者・オーナーチェック用）
  title?: string
  description?: string
  deadline?: string | null
  assigned_user_ids?: string[]
}

interface UpdateTodoResponse {
  success: boolean
  todo?: {
    id: string
    group_id: string
    title: string
    description: string | null
    deadline: string | null
    is_completed: boolean
    created_by: string
    created_at: string
    updated_at: string
    assignees: {
      user_id: string
      display_name: string
      avatar_url: string | null
    }[]
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

    const { todo_id, user_id, title, description, deadline, assigned_user_ids }: UpdateTodoRequest = await req.json()

    if (!todo_id || !user_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'todo_id and user_id are required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // TODO取得して権限チェック
    const { data: todo, error: getTodoError } = await supabaseClient
      .from('todos')
      .select('created_by, group_id')
      .eq('id', todo_id)
      .single()

    if (getTodoError || !todo) {
      return new Response(
        JSON.stringify({ success: false, error: 'TODO not found' }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // メンバーシップチェック
    const membershipCheck = await checkGroupMembership(supabaseClient, todo.group_id, user_id)
    if (!membershipCheck.success) {
      return new Response(
        JSON.stringify({ success: false, error: membershipCheck.error }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 担当者メンバーチェック（assigned_user_idsが指定されている場合）
    if (assigned_user_ids && assigned_user_ids.length > 0) {
      const assigneeCheck = await checkAssigneesAreMembers(supabaseClient, todo.group_id, assigned_user_ids)
      if (!assigneeCheck.success) {
        return new Response(
          JSON.stringify({ success: false, error: assigneeCheck.error }),
          {
            status: 200,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        )
      }
    }

    // グループオーナーチェック
    const { data: group } = await supabaseClient
      .from('groups')
      .select('owner_id')
      .eq('id', todo.group_id)
      .single()

    const isCreator = todo.created_by === user_id
    const isOwner = group?.owner_id === user_id

    if (!isCreator && !isOwner) {
      return new Response(
        JSON.stringify({ success: false, error: 'Only creator or group owner can update TODO' }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // TODO更新
    const updateData: any = { updated_at: new Date().toISOString() }
    if (title !== undefined) updateData.title = title
    if (description !== undefined) updateData.description = description
    if (deadline !== undefined) updateData.deadline = deadline

    const { data: updatedTodo, error: updateError } = await supabaseClient
      .from('todos')
      .update(updateData)
      .eq('id', todo_id)
      .select('id, group_id, title, description, deadline, is_completed, created_by, created_at, updated_at')
      .single()

    if (updateError || !updatedTodo) {
      return new Response(
        JSON.stringify({ success: false, error: `Failed to update TODO: ${updateError?.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 担当者更新（assigned_user_idsが指定された場合のみ更新）
    if (assigned_user_ids !== undefined) {
      // 既存の担当者を削除
      await supabaseClient
        .from('todo_assignments')
        .delete()
        .eq('todo_id', todo_id)

      // 新しい担当者を追加（空配列の場合は全員に見える状態）
      if (assigned_user_ids.length > 0) {
        const now = new Date().toISOString()
        const assignmentInserts = assigned_user_ids.map(uid => ({
          todo_id: todo_id,
          user_id: uid,
          assigned_at: now
        }))

        await supabaseClient
          .from('todo_assignments')
          .insert(assignmentInserts)
      }
    }

    // 担当者情報を取得
    const { data: assignments } = await supabaseClient
      .from('todo_assignments')
      .select(`
        user_id,
        users:user_id (
          display_name,
          avatar_url
        )
      `)
      .eq('todo_id', todo_id)

    const assignees = (assignments || []).map((a: any) => ({
      user_id: a.user_id,
      display_name: a.users?.display_name || '',
      avatar_url: a.users?.avatar_url || null
    }))

    const response: UpdateTodoResponse = {
      success: true,
      todo: {
        id: updatedTodo.id,
        group_id: updatedTodo.group_id,
        title: updatedTodo.title,
        description: updatedTodo.description,
        deadline: updatedTodo.deadline,
        is_completed: updatedTodo.is_completed,
        created_by: updatedTodo.created_by,
        created_at: updatedTodo.created_at,
        updated_at: updatedTodo.updated_at,
        assignees: assignees
      }
    }

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Update todo error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
