// クイックアクション一覧取得 Edge Function
import { serve } from "https://deno.land/std@0.192.0/http/server.ts"
import { corsHeaders } from '../_shared/cors.ts'
import { checkMaintenanceMode } from '../_shared/maintenance.ts'
import { checkGroupMembership } from '../_shared/permission.ts'

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

declare var Deno: any;

interface GetQuickActionsRequest {
  group_id: string
  user_id: string
}

interface GetQuickActionsResponse {
  success: boolean
  quick_actions?: any[]
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

    const { group_id, user_id }: GetQuickActionsRequest = await req.json()

    if (!group_id || !user_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'group_id and user_id are required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // メンバーシップチェック
    const membershipCheck = await checkGroupMembership(supabaseClient, group_id, user_id)
    if (!membershipCheck.success) {
      return new Response(
        JSON.stringify({ success: false, error: membershipCheck.error }),
        {
          status: 403,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // クイックアクション取得
    const { data: quickActions, error: quickActionError } = await supabaseClient
      .from('quick_actions')
      .select('*')
      .eq('group_id', group_id)
      .order('display_order', { ascending: true })

    if (quickActionError) {
      return new Response(
        JSON.stringify({ success: false, error: `Failed to get quick actions: ${quickActionError.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 各クイックアクションのテンプレート取得
    const actionsWithTemplates = []

    for (const action of quickActions || []) {
      const { data: templates } = await supabaseClient
        .from('quick_action_templates')
        .select('*')
        .eq('quick_action_id', action.id)
        .order('display_order', { ascending: true })

      actionsWithTemplates.push({
        ...action,
        templates: templates || []
      })
    }

    const response: GetQuickActionsResponse = {
      success: true,
      quick_actions: actionsWithTemplates
    }

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Get quick actions error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
