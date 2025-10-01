// TODO更新 Edge Function
import { serve } from "https://deno.land/std@0.192.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

declare var Deno: any;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface UpdateTodoRequest {
  todo_id: string
  user_id: string // 操作者（作成者・オーナーチェック用）
  title?: string
  description?: string
  deadline?: string | null
  category?: 'shopping' | 'housework' | 'other'
  assigned_user_ids?: string[]
}

interface UpdateTodoResponse {
  success: boolean
  todo?: {
    id: string
    title: string
    description: string | null
    deadline: string | null
    category: string
    updated_at: string
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

    const { todo_id, user_id, title, description, deadline, category, assigned_user_ids }: UpdateTodoRequest = await req.json()

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
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
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
          status: 403,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // TODO更新
    const updateData: any = { updated_at: new Date().toISOString() }
    if (title !== undefined) updateData.title = title
    if (description !== undefined) updateData.description = description
    if (deadline !== undefined) updateData.deadline = deadline
    if (category !== undefined) updateData.category = category

    const { data: updatedTodo, error: updateError } = await supabaseClient
      .from('todos')
      .update(updateData)
      .eq('id', todo_id)
      .select('id, title, description, deadline, category, updated_at')
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

    // 担当者更新
    if (assigned_user_ids && assigned_user_ids.length > 0) {
      // 既存の担当者を削除
      await supabaseClient
        .from('todo_assignments')
        .delete()
        .eq('todo_id', todo_id)

      // 新しい担当者を追加
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

    const response: UpdateTodoResponse = {
      success: true,
      todo: {
        id: updatedTodo.id,
        title: updatedTodo.title,
        description: updatedTodo.description,
        deadline: updatedTodo.deadline,
        category: updatedTodo.category,
        updated_at: updatedTodo.updated_at
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
