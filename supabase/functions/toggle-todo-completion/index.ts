// TODO完了/未完了切り替え Edge Function
import { serve } from "https://deno.land/std@0.192.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

declare var Deno: any;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface ToggleTodoRequest {
  todo_id: string
  user_id: string // 操作者のユーザーID（担当者チェック用）
}

interface ToggleTodoResponse {
  success: boolean
  todo?: {
    id: string
    is_completed: boolean
    completed_at: string | null
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
          status: 403,
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
          status: 404,
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
      .select('id, is_completed, completed_at')
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

    const response: ToggleTodoResponse = {
      success: true,
      todo: {
        id: updatedTodo.id,
        is_completed: updatedTodo.is_completed,
        completed_at: updatedTodo.completed_at
      }
    }

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Toggle todo completion error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
