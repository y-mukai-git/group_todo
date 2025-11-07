// TODO完了/未完了切り替え Edge Function
import { serve } from "https://deno.land/std@0.192.0/http/server.ts"
import { corsHeaders } from '../_shared/cors.ts'
import { checkMaintenanceMode } from '../_shared/maintenance.ts'

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

declare var Deno: any;



interface ToggleTodoRequest {
  todo_id: string
  user_id: string // 操作者のユーザーID（担当者チェック用）
}

interface ToggleTodoResponse {
  success: boolean
  todo?: {
    id: string
    group_id: string
    title: string
    description: string | null
    deadline: string | null
    category: string
    is_completed: boolean
    completed_at: string | null
    created_by: string
    created_at: string
    updated_at: string
    assigned_user_ids: string[]
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

    const { todo_id, user_id }: ToggleTodoRequest = await req.json()

    if (!todo_id || !user_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'todo_id and user_id are required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // ユーザーがこのTODOの担当者かチェック
    const { data: assignment, error: assignmentError } = await supabaseClient
      .from('todo_assignments')
      .select('id')
      .eq('todo_id', todo_id)
      .eq('user_id', user_id)
      .single()

    if (assignmentError || !assignment) {
      return new Response(
        JSON.stringify({ success: false, error: 'User is not assigned to this TODO' }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 現在の完了状態を取得
    const { data: currentTodo, error: getTodoError } = await supabaseClient
      .from('todos')
      .select('is_completed')
      .eq('id', todo_id)
      .single()

    if (getTodoError || !currentTodo) {
      return new Response(
        JSON.stringify({ success: false, error: 'TODO not found' }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 完了状態を反転
    const newCompletedState = !currentTodo.is_completed
    const now = new Date().toISOString()

    const { data: updatedTodo, error: updateError } = await supabaseClient
      .from('todos')
      .update({
        is_completed: newCompletedState,
        completed_at: newCompletedState ? now : null,
        updated_at: now
      })
      .eq('id', todo_id)
      .select('id, group_id, title, description, deadline, category, is_completed, completed_at, created_by, created_at, updated_at')
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

    // 担当者ID一覧を取得
    const { data: assignments } = await supabaseClient
      .from('todo_assignments')
      .select('user_id')
      .eq('todo_id', todo_id)

    const assignedUserIds = assignments?.map((a: { user_id: string }) => a.user_id) ?? []

    const response: ToggleTodoResponse = {
      success: true,
      todo: {
        id: updatedTodo.id,
        group_id: updatedTodo.group_id,
        title: updatedTodo.title,
        description: updatedTodo.description,
        deadline: updatedTodo.deadline,
        category: updatedTodo.category,
        is_completed: updatedTodo.is_completed,
        completed_at: updatedTodo.completed_at,
        created_by: updatedTodo.created_by,
        created_at: updatedTodo.created_at,
        updated_at: updatedTodo.updated_at,
        assigned_user_ids: assignedUserIds
      }
    }

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error: unknown) {
    console.error('Toggle todo completion error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error instanceof Error ? error.message : 'Unknown error' }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
