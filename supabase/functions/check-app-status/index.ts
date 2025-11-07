import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
}

interface CheckAppStatusRequest {
  current_version: string
  platform: 'ios' | 'android'
}

interface CheckAppStatusResponse {
  maintenance: {
    is_maintenance: boolean
    message?: string
  }
  force_update: {
    required: boolean
    message?: string
    store_url?: string
  }
  version_info: {
    current_version: string
    latest_version?: string
    has_new_version: boolean
    new_version_info?: {
      version: string
      release_notes: string
      release_date: string
    }
  }
}

serve(async (req) => {
  // CORS対応
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: req.headers.get('Authorization')! },
        },
      }
    )

    const { current_version, platform } = (await req.json()) as CheckAppStatusRequest

    // 1. メンテナンスモードチェック
    const { data: maintenanceData, error: maintenanceError } = await supabaseClient
      .from('maintenance_mode')
      .select('is_maintenance, maintenance_message')
      .single()

    if (maintenanceError) {
      throw new Error(`メンテナンスモード取得エラー: ${maintenanceError.message}`)
    }

    // 2. アプリバージョン情報取得
    const { data: versionsData, error: versionsError } = await supabaseClient
      .from('app_versions')
      .select('*')
      .order('release_date', { ascending: false })

    if (versionsError) {
      throw new Error(`バージョン情報取得エラー: ${versionsError.message}`)
    }

    // バージョン比較関数
    const compareVersions = (v1: string, v2: string): number => {
      const parts1 = v1.split('.').map(Number)
      const parts2 = v2.split('.').map(Number)

      for (let i = 0; i < Math.max(parts1.length, parts2.length); i++) {
        const part1 = parts1[i] || 0
        const part2 = parts2[i] || 0
        if (part1 > part2) return 1
        if (part1 < part2) return -1
      }
      return 0
    }

    // 3. 強制アップデートチェック
    let forceUpdateRequired = false
    let forceUpdateMessage: string | undefined
    let storeUrl: string | undefined

    for (const version of versionsData) {
      // 現在バージョンより新しいバージョンをチェック
      if (compareVersions(version.version, current_version) > 0) {
        if (version.force_update_required) {
          forceUpdateRequired = true
          forceUpdateMessage = version.force_update_message || '新しいバージョンへのアップデートが必要です。'
          storeUrl = platform === 'ios' ? version.store_url_ios : version.store_url_android
          break
        }
      }
    }

    // 4. 最新バージョン情報
    const latestVersion = versionsData[0] // release_dateでソート済みなので最初が最新
    const hasNewVersion = latestVersion && compareVersions(latestVersion.version, current_version) > 0

    const response: CheckAppStatusResponse = {
      maintenance: {
        is_maintenance: maintenanceData.is_maintenance,
        message: maintenanceData.is_maintenance ? maintenanceData.maintenance_message : undefined,
      },
      force_update: {
        required: forceUpdateRequired,
        message: forceUpdateMessage,
        store_url: storeUrl,
      },
      version_info: {
        current_version,
        latest_version: latestVersion?.version,
        has_new_version: hasNewVersion || false,
        new_version_info: hasNewVersion ? {
          version: latestVersion.version,
          release_notes: latestVersion.release_notes || '',
          release_date: latestVersion.release_date,
        } : undefined,
      },
    }

    return new Response(JSON.stringify(response), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})
