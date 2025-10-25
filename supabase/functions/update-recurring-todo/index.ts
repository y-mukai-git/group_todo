// 定期TODO更新 Edge Function
import { serve } from "https://deno.land/std@0.192.0/http/server.ts"

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

declare var Deno: any;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface UpdateRecurringTodoRequest {
  recurring_todo_id: string
  user_id: string
  is_active?: boolean
  title?: string
  description?: string
  category?: 'shopping' | 'housework' | 'other'
  recurrence_pattern?: 'daily' | 'weekly' | 'monthly'
  recurrence_days?: number[]
  generation_time?: string
  assigned_user_ids?: string[]
}

interface UpdateRecurringTodoResponse {
  success: boolean
  recurring_todo?: {
    id: string
    is_active: boolean
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

    const {
      recurring_todo_id,
      user_id,
      is_active,
      title,
      description,
      category,
      recurrence_pattern,
      recurrence_days,
      generation_time,
      assigned_user_ids
    }: UpdateRecurringTodoRequest = await req.json()

    if (!recurring_todo_id || !user_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'recurring_todo_id and user_id are required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 権限チェック
    const { data: recurringTodo } = await supabaseClient
      .from('recurring_todos')
      .select('created_by, group_id')
      .eq('id', recurring_todo_id)
      .single()

    if (!recurringTodo) {
      return new Response(
        JSON.stringify({ success: false, error: 'Recurring TODO not found' }),
        {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const { data: group } = await supabaseClient
      .from('groups')
      .select('owner_id')
      .eq('id', recurringTodo.group_id)
      .single()

    const isCreator = recurringTodo.created_by === user_id
    const isOwner = group?.owner_id === user_id

    if (!isCreator && !isOwner) {
      return new Response(
        JSON.stringify({ success: false, error: 'Only creator or group owner can update recurring TODO' }),
        {
          status: 403,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 更新データ準備
    const updateData: any = { updated_at: new Date().toISOString() }
    if (is_active !== undefined) updateData.is_active = is_active
    if (title !== undefined) updateData.title = title
    if (description !== undefined) updateData.description = description
    if (category !== undefined) updateData.category = category
    if (recurrence_pattern !== undefined) updateData.recurrence_pattern = recurrence_pattern
    if (recurrence_days !== undefined) updateData.recurrence_days = recurrence_days
    if (generation_time !== undefined) updateData.generation_time = generation_time

    const { data: updated, error: updateError } = await supabaseClient
      .from('recurring_todos')
      .update(updateData)
      .eq('id', recurring_todo_id)
      .select('*, recurring_todo_assignments(user_id)')
      .single()

    if (updateError || !updated) {
      return new Response(
        JSON.stringify({ success: false, error: `Failed to update: ${updateError?.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 担当者更新
    if (assigned_user_ids && assigned_user_ids.length > 0) {
      await supabaseClient
        .from('recurring_todo_assignments')
        .delete()
        .eq('recurring_todo_id', recurring_todo_id)

      const now = new Date().toISOString()
      const assignmentInserts = assigned_user_ids.map(uid => ({
        recurring_todo_id: recurring_todo_id,
        user_id: uid,
        assigned_at: now
      }))

      await supabaseClient
        .from('recurring_todo_assignments')
        .insert(assignmentInserts)
    }

    const response: UpdateRecurringTodoResponse = {
      success: true,
      recurring_todo: {
        ...updated,
        assigned_user_ids: (updated.recurring_todo_assignments || []).map((a: any) => a.user_id)
      }
    }

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Update recurring todo error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
