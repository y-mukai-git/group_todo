// グループのTODO一覧取得 Edge Function
import { serve } from "https://deno.land/std@0.192.0/http/server.ts"

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

declare var Deno: any;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface GetGroupTodosRequest {
  group_id: string
  is_completed?: boolean // nullの場合は全て取得
}

interface TodoWithAssignees {
  id: string
  group_id: string
  title: string
  description: string | null
  deadline: string | null
  category: string
  is_completed: boolean
  created_by: string
  created_at: string
  assignees: {
    user_id: string
    display_name: string
    avatar_url: string | null
  }[]
}

interface GetGroupTodosResponse {
  success: boolean
  todos?: TodoWithAssignees[]
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

    const { group_id, is_completed }: GetGroupTodosRequest = await req.json()

    if (!group_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'group_id is required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // TODOを取得
    let query = supabaseClient
      .from('todos')
      .select('id, group_id, title, description, deadline, category, is_completed, created_by, created_at')
      .eq('group_id', group_id)

    // 完了状態フィルター
    if (is_completed !== undefined && is_completed !== null) {
      query = query.eq('is_completed', is_completed)
    }

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

    // 各TODOの担当者情報を取得
    const todosWithAssignees: TodoWithAssignees[] = []

    for (const todo of todos || []) {
      const { data: assignments } = await supabaseClient
        .from('todo_assignments')
        .select(`
          user_id,
          users:user_id (
            display_name,
            avatar_url
          )
        `)
        .eq('todo_id', todo.id)

      const assignees = (assignments || []).map((a: any) => ({
        user_id: a.user_id,
        display_name: a.users?.display_name || '',
        avatar_url: a.users?.avatar_url || null
      }))

      todosWithAssignees.push({
        id: todo.id,
        group_id: todo.group_id,
        title: todo.title,
        description: todo.description,
        deadline: todo.deadline,
        category: todo.category,
        is_completed: todo.is_completed,
        created_by: todo.created_by,
        created_at: todo.created_at,
        assignees: assignees
      })
    }

    const response: GetGroupTodosResponse = {
      success: true,
      todos: todosWithAssignees
    }

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Get group todos error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
