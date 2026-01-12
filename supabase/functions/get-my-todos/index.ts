// 自分の担当TODO取得 Edge Function
// 期限フィルター対応（当日・3日以内・1週間以内）
// 担当者なし（全員に見える）TODOにも対応

import { serve } from "https://deno.land/std@0.192.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'
import { checkMaintenanceMode } from '../_shared/maintenance.ts'

declare var Deno: any;



interface GetMyTodosRequest {
  user_id: string
  deadline_filter?: 'today' | '3days' | '1week' // 期限フィルター
}

interface TodoItem {
  id: string
  group_id: string
  group_name: string
  title: string
  description: string | null
  deadline: string | null
  is_completed: boolean
  created_by: string
  created_at: string
}

interface GetMyTodosResponse {
  success: boolean
  todos?: TodoItem[]
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

    const { user_id, deadline_filter }: GetMyTodosRequest = await req.json()

    if (!user_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'user_id is required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 期限フィルターの計算
    const now = new Date()
    let deadlineEnd: Date | null = null

    if (deadline_filter === 'today') {
      deadlineEnd = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59)
    } else if (deadline_filter === '3days') {
      deadlineEnd = new Date(now.getTime() + 3 * 24 * 60 * 60 * 1000)
    } else if (deadline_filter === '1week') {
      deadlineEnd = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000)
    }

    // 1. 自分が担当のTODO IDを取得
    const { data: assignments, error: assignmentError } = await supabaseClient
      .from('todo_assignments')
      .select('todo_id')
      .eq('user_id', user_id)

    if (assignmentError) {
      return new Response(
        JSON.stringify({ success: false, error: `Failed to get assignments: ${assignmentError.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const assignedTodoIds = (assignments || []).map(a => a.todo_id)

    // 2. 自分が所属するグループIDを取得（担当者なしTODO用）
    const { data: memberships, error: membershipError } = await supabaseClient
      .from('group_members')
      .select('group_id')
      .eq('user_id', user_id)

    if (membershipError) {
      return new Response(
        JSON.stringify({ success: false, error: `Failed to get memberships: ${membershipError.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const memberGroupIds = (memberships || []).map(m => m.group_id)

    if (assignedTodoIds.length === 0 && memberGroupIds.length === 0) {
      return new Response(
        JSON.stringify({ success: true, todos: [] }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 3. 担当者なしのTODO IDを取得（自分が所属するグループから）
    // まず、担当者が1人以上いるTODO IDを取得
    const { data: todosWithAssignees, error: todosWithAssigneesError } = await supabaseClient
      .from('todo_assignments')
      .select('todo_id')

    if (todosWithAssigneesError) {
      return new Response(
        JSON.stringify({ success: false, error: `Failed to get todos with assignees: ${todosWithAssigneesError.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const todoIdsWithAssignees = new Set((todosWithAssignees || []).map(t => t.todo_id))

    // 自分が所属するグループの全TODO IDを取得
    let unassignedTodoIds: string[] = []
    if (memberGroupIds.length > 0) {
      const { data: groupTodos, error: groupTodosError } = await supabaseClient
        .from('todos')
        .select('id')
        .in('group_id', memberGroupIds)
        .eq('is_completed', false)

      if (groupTodosError) {
        return new Response(
          JSON.stringify({ success: false, error: `Failed to get group todos: ${groupTodosError.message}` }),
          {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        )
      }

      // 担当者がいないTODOのみ抽出
      unassignedTodoIds = (groupTodos || [])
        .filter(t => !todoIdsWithAssignees.has(t.id))
        .map(t => t.id)
    }

    // 4. 自分が担当 + 担当者なし のTODO IDを統合
    const allTodoIds = [...new Set([...assignedTodoIds, ...unassignedTodoIds])]

    if (allTodoIds.length === 0) {
      return new Response(
        JSON.stringify({ success: true, todos: [] }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 5. TODOを取得（グループ情報も含む）
    let query = supabaseClient
      .from('todos')
      .select(`
        id,
        group_id,
        groups:group_id (
          name
        ),
        title,
        description,
        deadline,
        is_completed,
        created_by,
        created_at
      `)
      .in('id', allTodoIds)
      .eq('is_completed', false)

    // 期限フィルター適用
    if (deadlineEnd) {
      query = query.lte('deadline', deadlineEnd.toISOString())
    }

    // 期限順にソート
    query = query.order('deadline', { ascending: true, nullsFirst: false })

    const { data: todos, error: todoError } = await query

    if (todoError) {
      return new Response(
        JSON.stringify({ success: false, error: `Failed to get todos: ${todoError.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const todoItems: TodoItem[] = (todos || []).map((todo: any) => ({
      id: todo.id,
      group_id: todo.group_id,
      group_name: todo.groups?.name || '',
      title: todo.title,
      description: todo.description,
      deadline: todo.deadline,
      is_completed: todo.is_completed,
      created_by: todo.created_by,
      created_at: todo.created_at
    }))

    const response: GetMyTodosResponse = {
      success: true,
      todos: todoItems
    }

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Get my todos error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
