// クイックアクション削除 Edge Function
import { serve } from "https://deno.land/std@0.192.0/http/server.ts"
import { corsHeaders } from '../_shared/cors.ts'
import { checkMaintenanceMode } from '../_shared/maintenance.ts'
import { checkGroupMembership } from '../_shared/permission.ts'

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

declare var Deno: any;

interface DeleteQuickActionRequest {
  quick_action_id: string
  user_id: string
}

interface DeleteQuickActionResponse {
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

    // メンテナンスモードチェック
    const checkResult = await checkMaintenanceMode()
    if (checkResult.status === 'error' || checkResult.status === 'maintenance') {
      return new Response(
        JSON.stringify(checkResult),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const { quick_action_id, user_id }: DeleteQuickActionRequest = await req.json()

    if (!quick_action_id || !user_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'quick_action_id and user_id are required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // クイックアクション取得と権限チェック
    const { data: quickAction } = await supabaseClient
      .from('quick_actions')
      .select('created_by, group_id')
      .eq('id', quick_action_id)
      .single()

    if (!quickAction) {
      return new Response(
        JSON.stringify({ success: false, error: 'Quick action not found' }),
        {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // メンバーシップチェック
    const membershipCheck = await checkGroupMembership(supabaseClient, quickAction.group_id, user_id)
    if (!membershipCheck.success) {
      return new Response(
        JSON.stringify({ success: false, error: membershipCheck.error }),
        {
          status: 403,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // グループオーナー確認
    const { data: group } = await supabaseClient
      .from('groups')
      .select('owner_id')
      .eq('id', quickAction.group_id)
      .single()

    const isCreator = quickAction.created_by === user_id
    const isOwner = group?.owner_id === user_id

    if (!isCreator && !isOwner) {
      return new Response(
        JSON.stringify({ success: false, error: 'Only creator or group owner can delete quick action' }),
        {
          status: 403,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 削除（CASCADE設定によりテンプレートも自動削除）
    const { error: deleteError } = await supabaseClient
      .from('quick_actions')
      .delete()
      .eq('id', quick_action_id)

    if (deleteError) {
      return new Response(
        JSON.stringify({ success: false, error: `Failed to delete quick action: ${deleteError.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const response: DeleteQuickActionResponse = {
      success: true
    }

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Delete quick action error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
