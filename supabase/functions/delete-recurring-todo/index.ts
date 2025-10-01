// 定期TODO削除 Edge Function
import { serve } from "https://deno.land/std@0.192.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

declare var Deno: any;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface DeleteRecurringTodoRequest {
  recurring_todo_id: string
  user_id: string
}

interface DeleteRecurringTodoResponse {
  success: boolean
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

    const { recurring_todo_id, user_id }: DeleteRecurringTodoRequest = await req.json()

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
        JSON.stringify({ success: false, error: 'Only creator or group owner can delete recurring TODO' }),
        {
          status: 403,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 削除（CASCADE設定により担当者も自動削除）
    const { error: deleteError } = await supabaseClient
      .from('recurring_todos')
      .delete()
      .eq('id', recurring_todo_id)

    if (deleteError) {
      return new Response(
        JSON.stringify({ success: false, error: `Failed to delete: ${deleteError.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const response: DeleteRecurringTodoResponse = {
      success: true
    }

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Delete recurring todo error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
