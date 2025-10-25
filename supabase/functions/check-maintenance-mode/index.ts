// メンテナンスモードチェック Edge Function
import { serve } from "https://deno.land/std@0.192.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

declare var Deno: any;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface CheckMaintenanceModeResponse {
  status: 'ok' | 'maintenance' | 'error'
  message?: string
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

    const { data: maintenanceData, error: maintenanceError } = await supabaseClient
      .from('maintenance_mode')
      .select('is_maintenance, maintenance_message')
      .single()

    if (maintenanceError) {
      console.error('[CheckMaintenanceMode] ❌ メンテナンスモード取得エラー:', maintenanceError)
      const response: CheckMaintenanceModeResponse = {
        status: 'error',
        message: 'システムエラーが発生しました。しばらくお待ちください',
      }
      return new Response(
        JSON.stringify(response),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    if (maintenanceData.is_maintenance) {
      const response: CheckMaintenanceModeResponse = {
        status: 'maintenance',
        message: maintenanceData.maintenance_message || 'システムメンテナンス中です',
      }
      return new Response(
        JSON.stringify(response),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const response: CheckMaintenanceModeResponse = {
      status: 'ok',
    }
    return new Response(
      JSON.stringify(response),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )

  } catch (error) {
    console.error('[CheckMaintenanceMode] ❌ メンテナンスチェック例外:', error)
    const response: CheckMaintenanceModeResponse = {
      status: 'error',
      message: 'システムエラーが発生しました。しばらくお待ちください',
    }
    return new Response(
      JSON.stringify(response),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
