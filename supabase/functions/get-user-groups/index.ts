// ユーザーの所属グループ一覧取得 Edge Function
import { serve } from "https://deno.land/std@0.192.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

declare var Deno: any;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface GetUserGroupsRequest {
  user_id: string
}

interface GroupWithStats {
  id: string
  name: string
  description: string | null
  category: string | null
  icon_url: string | null
  signed_icon_url: string | null
  owner_id: string
  member_count: number
  incomplete_todo_count: number
  role: string
  joined_at: string
}

interface GetUserGroupsResponse {
  success: boolean
  groups?: GroupWithStats[]
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

    const { user_id }: GetUserGroupsRequest = await req.json()

    if (!user_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'user_id is required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // ユーザーが所属するグループ一覧取得
    const { data: groupMembers, error: memberError } = await supabaseClient
      .from('group_members')
      .select(`
        role,
        joined_at,
        groups:group_id (
          id,
          name,
          description,
          category,
          icon_url,
          owner_id
        )
      `)
      .eq('user_id', user_id)

    if (memberError) {
      return new Response(
        JSON.stringify({ success: false, error: `Failed to get groups: ${memberError.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 各グループの統計情報を取得
    const groupsWithStats: GroupWithStats[] = []

    for (const member of groupMembers || []) {
      const group = member.groups as any

      if (!group) continue

      // メンバー数取得
      const { count: memberCount } = await supabaseClient
        .from('group_members')
        .select('*', { count: 'exact', head: true })
        .eq('group_id', group.id)

      // 未完了TODO数取得
      const { count: todoCount } = await supabaseClient
        .from('todos')
        .select('*', { count: 'exact', head: true })
        .eq('group_id', group.id)
        .eq('is_completed', false)

      // 署名付きURL生成（icon_urlが存在する場合）
      let signedIconUrl: string | null = null
      if (group.icon_url) {
        try {
          const { data: signedUrlData, error: signedUrlError } = await supabaseClient
            .storage
            .from('group-icons')
            .createSignedUrl(group.icon_url, 3600) // 有効期限1時間

          if (!signedUrlError && signedUrlData?.signedUrl) {
            signedIconUrl = signedUrlData.signedUrl
          }
        } catch (error) {
          console.error('Failed to create signed URL:', error)
          // 署名付きURL生成失敗時もエラーにせず、nullのまま返す
        }
      }

      groupsWithStats.push({
        id: group.id,
        name: group.name,
        description: group.description,
        category: group.category,
        icon_url: group.icon_url,
        signed_icon_url: signedIconUrl,
        owner_id: group.owner_id,
        member_count: memberCount || 0,
        incomplete_todo_count: todoCount || 0,
        role: member.role,
        joined_at: member.joined_at
      })
    }

    const response: GetUserGroupsResponse = {
      success: true,
      groups: groupsWithStats
    }

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Get user groups error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
