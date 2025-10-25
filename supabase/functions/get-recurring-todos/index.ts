// 定期TODO一覧取得 Edge Function
import { serve } from "https://deno.land/std@0.192.0/http/server.ts"

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

declare var Deno: any;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface GetRecurringTodosRequest {
  group_id: string
}

interface RecurringTodoWithAssignees {
  id: string
  title: string
  description: string | null
  category: string
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

    const { group_id }: GetRecurringTodosRequest = await req.json()

    if (!group_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'group_id is required' }),
        {
          status: 400,
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

    // 各定期TODOの担当者取得
    const todosWithAssignees: RecurringTodoWithAssignees[] = []

    for (const todo of recurringTodos || []) {
      const { data: assignments } = await supabaseClient
        .from('recurring_todo_assignments')
        .select(`
          user_id,
          users:user_id (
            display_name
          )
        `)
        .eq('recurring_todo_id', todo.id)

      const assignees = (assignments || []).map((a: any) => ({
        user_id: a.user_id,
        display_name: a.users?.display_name || ''
      }))

      todosWithAssignees.push({
        ...todo,
        assignees: assignees
      })
    }

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
