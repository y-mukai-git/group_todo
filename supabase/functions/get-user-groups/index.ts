// ユーザーの所属グループ一覧取得 Edge Function
import { serve } from "https://deno.land/std@0.192.0/http/server.ts"
import { corsHeaders } from '../_shared/cors.ts'
import { checkMaintenanceMode } from '../_shared/maintenance.ts'

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

declare var Deno: any;



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
  display_order: number
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

    // メンテナンスモードチェック
    const checkResult = await checkMaintenanceMode(req)
    if (checkResult.status === 'error' || checkResult.status === 'maintenance') {
      return new Response(
        JSON.stringify(checkResult),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

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
        display_order,
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
      .order('display_order', { ascending: true })

    if (memberError) {
      return new Response(
        JSON.stringify({ success: false, error: `Failed to get groups: ${memberError.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // N+1問題を解決: 全グループIDを抽出
    const groupIds = (groupMembers || [])
      .map(member => (member.groups as any)?.id)
      .filter((id): id is string => id != null)

    // 全グループのメンバー数を一括取得
    const { data: memberCounts } = await supabaseClient
      .from('group_members')
      .select('group_id')
      .in('group_id', groupIds)

    // グループIDごとのメンバー数を集計
    const memberCountMap = new Map<string, number>()
    for (const member of memberCounts || []) {
      const count = memberCountMap.get(member.group_id) || 0
      memberCountMap.set(member.group_id, count + 1)
    }

    // 全グループの未完了TODO数を一括取得
    const { data: todoCounts } = await supabaseClient
      .from('todos')
      .select('group_id')
      .in('group_id', groupIds)
      .eq('is_completed', false)

    // グループIDごとのTODO数を集計
    const todoCountMap = new Map<string, number>()
    for (const todo of todoCounts || []) {
      const count = todoCountMap.get(todo.group_id) || 0
      todoCountMap.set(todo.group_id, count + 1)
    }

    // 各グループの情報を組み立て
    const groupsWithStats: GroupWithStats[] = []

    for (const member of groupMembers || []) {
      const group = member.groups as any

      if (!group) continue

      // Mapから統計情報を取得
      const memberCount = memberCountMap.get(group.id) || 0
      const todoCount = todoCountMap.get(group.id) || 0

      // 署名付きURL生成（icon_urlが存在する場合）
      let signedIconUrl: string | null = null
      if (group.icon_url) {
        const { data: signedUrlData, error: signedUrlError } = await supabaseClient
          .storage
          .from('group-icons')
          .createSignedUrl(group.icon_url, 3600) // 有効期限1時間

        if (signedUrlError) {
          throw new Error(`Failed to create signed URL: ${signedUrlError.message}`)
        }

        signedIconUrl = signedUrlData.signedUrl
      }

      groupsWithStats.push({
        id: group.id,
        name: group.name,
        description: group.description,
        category: group.category,
        icon_url: group.icon_url,
        signed_icon_url: signedIconUrl,
        owner_id: group.owner_id,
        member_count: memberCount,
        incomplete_todo_count: todoCount,
        role: member.role,
        joined_at: member.joined_at,
        display_order: member.display_order || 0
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
