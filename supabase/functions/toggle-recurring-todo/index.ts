// 定期TODO有効/無効切り替え Edge Function
import { serve } from "https://deno.land/std@0.192.0/http/server.ts"

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

declare var Deno: any;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface ToggleRecurringTodoRequest {
  recurring_todo_id: string
  user_id: string // 権限チェック用
}

interface ToggleRecurringTodoResponse {
  success: boolean
  recurring_todo?: {
    id: string
    is_active: boolean
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

    const { recurring_todo_id, user_id }: ToggleRecurringTodoRequest = await req.json()

    if (!recurring_todo_id || !user_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'recurring_todo_id and user_id are required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 1. 定期TODOを取得（権限チェック含む）
    const { data: recurringTodo, error: fetchError } = await supabaseClient
      .from('recurring_todos')
      .select('id, is_active, created_by, group_id')
      .eq('id', recurring_todo_id)
      .single()

    if (fetchError || !recurringTodo) {
      return new Response(
        JSON.stringify({ success: false, error: 'Recurring TODO not found' }),
        {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 2. 権限チェック：作成者またはグループオーナーのみ切り替え可能
    const { data: group, error: groupError } = await supabaseClient
      .from('groups')
      .select('owner_id')
      .eq('id', recurringTodo.group_id)
      .single()

    if (groupError || !group) {
      return new Response(
        JSON.stringify({ success: false, error: 'Group not found' }),
        {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const isCreator = recurringTodo.created_by === user_id
    const isOwner = group.owner_id === user_id

    if (!isCreator && !isOwner) {
      return new Response(
        JSON.stringify({ success: false, error: 'Permission denied: Only creator or group owner can toggle' }),
        {
          status: 403,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 3. is_activeを切り替え
    const newIsActive = !recurringTodo.is_active

    const { data: updatedTodo, error: updateError } = await supabaseClient
      .from('recurring_todos')
      .update({ is_active: newIsActive })
      .eq('id', recurring_todo_id)
      .select('*, recurring_todo_assignments(user_id)')
      .single()

    if (updateError || !updatedTodo) {
      return new Response(
        JSON.stringify({ success: false, error: `Toggle failed: ${updateError?.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const response: ToggleRecurringTodoResponse = {
      success: true,
      recurring_todo: {
        ...updatedTodo,
        assigned_user_ids: (updatedTodo.recurring_todo_assignments || []).map((a: any) => a.user_id)
      }
    }

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Toggle recurring todo error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
