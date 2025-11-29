// 管理者・メンテナンスチェック Edge Function
// アプリ起動時に最初に呼ばれ、管理者フラグとメンテナンス状態を返す
import { serve } from "https://deno.land/std@0.192.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

declare var Deno: any;

interface CheckAdminAndMaintenanceRequest {
  device_id: string
}

interface CheckAdminAndMaintenanceResponse {
  success: boolean
  is_admin: boolean
  is_maintenance: boolean
  maintenance_end_time?: string // メンテナンス終了予定時刻（ISO 8601形式）
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

    const { device_id }: CheckAdminAndMaintenanceRequest = await req.json()

    if (!device_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'device_id is required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // ユーザー情報取得（is_admin）
    const { data: userData, error: userError } = await supabaseClient
      .from('users')
      .select('is_admin')
      .eq('device_id', device_id)
      .maybeSingle()

    // ユーザーが存在しない場合はis_admin=falseとして扱う（新規ユーザー）
    const isAdmin = userData?.is_admin ?? false

    // メンテナンスモード取得
    const { data: maintenanceData, error: maintenanceError } = await supabaseClient
      .from('maintenance_mode')
      .select('is_maintenance, end_time')
      .single()

    if (maintenanceError) {
      console.error('[CheckAdminAndMaintenance] ❌ メンテナンスモード取得エラー:', maintenanceError)
      return new Response(
        JSON.stringify({
          success: false,
          error: 'システムエラーが発生しました。しばらくお待ちください'
        }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const response: CheckAdminAndMaintenanceResponse = {
      success: true,
      is_admin: isAdmin,
      is_maintenance: maintenanceData.is_maintenance,
      maintenance_end_time: maintenanceData.end_time || undefined
    }

    return new Response(
      JSON.stringify(response),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )

  } catch (error) {
    console.error('[CheckAdminAndMaintenance] ❌ 例外:', error)
    return new Response(
      JSON.stringify({
        success: false,
        error: 'システムエラーが発生しました。しばらくお待ちください'
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
