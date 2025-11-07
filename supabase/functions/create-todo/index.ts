// TODO作成 Edge Function
import { serve } from "https://deno.land/std@0.192.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'
import { checkMaintenanceMode } from '../_shared/maintenance.ts'

declare var Deno: any;



interface CreateTodoRequest {
  group_id: string
  title: string
  description?: string
  deadline?: string
  category: 'shopping' | 'housework' | 'other'
  assigned_user_ids: string[]
  created_by: string
}

interface CreateTodoResponse {
  success: boolean
  todo?: {
    id: string
    group_id: string
    title: string
    description: string | null
    deadline: string | null
    category: string
    is_completed: boolean
    created_by: string
    created_at: string
    assigned_users: string[]
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
    const checkResult = await checkMaintenanceMode()
    if (checkResult.status === 'error' || checkResult.status === 'maintenance') {
      return new Response(
        JSON.stringify(checkResult),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const { group_id, title, description, deadline, category, assigned_user_ids, created_by }: CreateTodoRequest = await req.json()

    if (!group_id || !title || !category || !assigned_user_ids || assigned_user_ids.length === 0 || !created_by) {
      return new Response(
        JSON.stringify({ success: false, error: 'group_id, title, category, assigned_user_ids, and created_by are required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const now = new Date().toISOString()

    // TODO作成
    const { data: newTodo, error: todoError } = await supabaseClient
      .from('todos')
      .insert({
        group_id: group_id,
        title: title,
        description: description || null,
        deadline: deadline || null,
        category: category,
        is_completed: false,
        created_by: created_by,
        created_at: now,
        updated_at: now
      })
      .select('id, group_id, title, description, deadline, category, is_completed, created_by, created_at')
      .single()

    if (todoError || !newTodo) {
      return new Response(
        JSON.stringify({ success: false, error: `TODO creation failed: ${todoError?.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 担当者を追加
    const assignmentInserts = assigned_user_ids.map(user_id => ({
      todo_id: newTodo.id,
      user_id: user_id,
      assigned_at: now
    }))

    const { error: assignmentError } = await supabaseClient
      .from('todo_assignments')
      .insert(assignmentInserts)

    if (assignmentError) {
      // TODO作成は成功したが、担当者追加に失敗した場合はロールバック
      await supabaseClient
        .from('todos')
        .delete()
        .eq('id', newTodo.id)

      return new Response(
        JSON.stringify({ success: false, error: `Assignment creation failed: ${assignmentError.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const response: CreateTodoResponse = {
      success: true,
      todo: {
        id: newTodo.id,
        group_id: newTodo.group_id,
        title: newTodo.title,
        description: newTodo.description,
        deadline: newTodo.deadline,
        category: newTodo.category,
        is_completed: newTodo.is_completed,
        created_by: newTodo.created_by,
        created_at: newTodo.created_at,
        assigned_users: assigned_user_ids
      }
    }

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Create todo error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
