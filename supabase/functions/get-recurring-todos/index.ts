// 定期TODO一覧取得 Edge Function
import { serve } from "https://deno.land/std@0.192.0/http/server.ts"
import { corsHeaders } from '../_shared/cors.ts'
import { checkMaintenanceMode } from '../_shared/maintenance.ts'
import { checkGroupMembership } from '../_shared/permission.ts'

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

declare var Deno: any;



interface GetRecurringTodosRequest {
  group_id: string
  user_id: string // メンバーシップチェック用
}

interface RecurringTodoWithAssignees {
  id: string
  title: string
  description: string | null
  recurrence_pattern: string
  recurrence_days: number[] | null
  generation_time: string
  next_generation_at: string
  is_active: boolean
  assignees: {
    user_id: string
    display_name: string
  }[]
}

interface GetRecurringTodosResponse {
  success: boolean
  recurring_todos?: RecurringTodoWithAssignees[]
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

    const { group_id, user_id }: GetRecurringTodosRequest = await req.json()

    if (!group_id || !user_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'group_id and user_id are required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // メンバーシップチェック
    const membershipCheck = await checkGroupMembership(supabaseClient, group_id, user_id)
    if (!membershipCheck.success) {
      return new Response(
        JSON.stringify({ success: false, error: membershipCheck.error }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 定期TODO取得
    const { data: recurringTodos, error: recurringError } = await supabaseClient
      .from('recurring_todos')
      .select('*')
      .eq('group_id', group_id)
      .order('next_generation_at', { ascending: true })

    if (recurringError) {
      return new Response(
        JSON.stringify({ success: false, error: `Failed to get recurring todos: ${recurringError.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // N+1問題を解決: 全定期TODO IDを抽出
    const todoIds = (recurringTodos || []).map(t => t.id)

    // 全担当者を一括取得
    const { data: allAssignments } = await supabaseClient
      .from('recurring_todo_assignments')
      .select(`
        recurring_todo_id,
        user_id,
        users:user_id (
          display_name
        )
      `)
      .in('recurring_todo_id', todoIds)

    // Mapで集計
    const assignmentMap = new Map<string, any[]>()
    for (const assignment of allAssignments || []) {
      if (!assignmentMap.has(assignment.recurring_todo_id)) {
        assignmentMap.set(assignment.recurring_todo_id, [])
      }
      assignmentMap.get(assignment.recurring_todo_id)!.push({
        user_id: assignment.user_id,
        display_name: (assignment.users as any)?.display_name || ''
      })
    }

    // 各定期TODOに担当者を割り当て
    const todosWithAssignees: RecurringTodoWithAssignees[] = (recurringTodos || []).map(todo => ({
      ...todo,
      assignees: assignmentMap.get(todo.id) || []
    }))

    const response: GetRecurringTodosResponse = {
      success: true,
      recurring_todos: todosWithAssignees
    }

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Get recurring todos error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
