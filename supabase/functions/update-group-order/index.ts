// グループ並び順更新 Edge Function
import { serve } from "https://deno.land/std@0.192.0/http/server.ts"
import { corsHeaders } from '../_shared/cors.ts'
import { checkMaintenanceMode } from '../_shared/maintenance.ts'

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

declare var Deno: any;



interface UpdateGroupOrderRequest {
  user_id: string
  group_orders: Array<{
    group_id: string
    display_order: number
  }>
}

interface UpdateGroupOrderResponse {
  success: boolean
  updated_count?: number
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

    const { user_id, group_orders }: UpdateGroupOrderRequest = await req.json()

    if (!user_id || !group_orders || !Array.isArray(group_orders)) {
      return new Response(
        JSON.stringify({ success: false, error: 'user_id and group_orders are required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 各グループの並び順を更新
    let updatedCount = 0

    for (const order of group_orders) {
      const { group_id, display_order } = order

      // group_membersテーブルのdisplay_orderを更新
      const { error: updateError } = await supabaseClient
        .from('group_members')
        .update({ display_order })
        .eq('user_id', user_id)
        .eq('group_id', group_id)

      if (updateError) {
        console.error(`Failed to update display_order for group ${group_id}:`, updateError)
        return new Response(
          JSON.stringify({
            success: false,
            error: `Failed to update display_order: ${updateError.message}`
          }),
          {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        )
      }

      updatedCount++
    }

    const response: UpdateGroupOrderResponse = {
      success: true,
      updated_count: updatedCount
    }

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Update group order error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
