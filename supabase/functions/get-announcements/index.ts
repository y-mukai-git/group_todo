// お知らせ一覧取得 Edge Function
import { serve } from "https://deno.land/std@0.192.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'
import { checkMaintenanceMode } from '../_shared/maintenance.ts'

declare var Deno: any;



interface GetAnnouncementsResponse {
  success: boolean
  announcements?: {
    id: string
    version: string
    title: string
    content: string
    published_at: string
    created_at: string
  }[]
  error?: string
}

serve(async (req) => {
  // CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // メンテナンスモードチェック
    const checkResult = await checkMaintenanceMode(req)
    if (checkResult.status === 'error' || checkResult.status === 'maintenance') {
      return new Response(
        JSON.stringify(checkResult),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // お知らせ一覧取得（公開日時が現在より前のもののみ、公開日時の降順）
    const { data: announcements, error: announcementsError } = await supabaseClient
      .from('announcements')
      .select('id, version, title, content, published_at, created_at')
      .lte('published_at', new Date().toISOString())
      .order('published_at', { ascending: false })

    // エラーの場合は詳細をログに記録
    if (announcementsError) {
      console.error('[get-announcements] Database error:', announcementsError)
      return new Response(
        JSON.stringify({
          success: false,
          error: 'お知らせの取得に失敗しました。しばらくしてから再度お試しください'
        }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // データが0件の場合は正常終了
    const response: GetAnnouncementsResponse = {
      success: true,
      announcements: announcements || []
    }

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Get announcements error:', error)
    return new Response(
      JSON.stringify({ success: false, error: (error as Error).message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
