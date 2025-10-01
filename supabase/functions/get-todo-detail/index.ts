// TODO詳細取得 Edge Function
import { serve } from "https://deno.land/std@0.192.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

declare var Deno: any;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface GetTodoDetailRequest {
  todo_id: string
}

interface TodoDetail {
  id: string
  group_id: string
  group_name: string
  title: string
  description: string | null
  deadline: string | null
  category: string
  is_completed: boolean
  completed_at: string | null
  created_by: string
  created_by_name: string
  created_at: string
  assignees: {
    user_id: string
    display_name: string
    avatar_url: string | null
  }[]
}

interface GetTodoDetailResponse {
  success: boolean
  todo?: TodoDetail
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

    const { todo_id }: GetTodoDetailRequest = await req.json()

    if (!todo_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'todo_id is required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // TODO詳細取得
    const { data: todo, error: todoError } = await supabaseClient
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
        category,
        is_completed,
        completed_at,
        created_by,
        creator:created_by (
          display_name
        ),
        created_at
      `)
      .eq('id', todo_id)
      .single()

    if (todoError || !todo) {
      return new Response(
        JSON.stringify({ success: false, error: 'TODO not found' }),
        {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 担当者情報取得
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

    const todoDetail: TodoDetail = {
      id: todo.id,
      group_id: todo.group_id,
      group_name: (todo.groups as any)?.name || '',
      title: todo.title,
      description: todo.description,
      deadline: todo.deadline,
      category: todo.category,
      is_completed: todo.is_completed,
      completed_at: todo.completed_at,
      created_by: todo.created_by,
      created_by_name: (todo.creator as any)?.display_name || '',
      created_at: todo.created_at,
      assignees: assignees
    }

    const response: GetTodoDetailResponse = {
      success: true,
      todo: todoDetail
    }

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Get todo detail error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
