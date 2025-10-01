// グループ詳細取得 Edge Function
import { serve } from "https://deno.land/std@0.192.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

declare var Deno: any;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface GetGroupDetailRequest {
  group_id: string
}

interface GroupMember {
  user_id: string
  display_name: string
  avatar_url: string | null
  role: string
  joined_at: string
}

interface GroupDetail {
  id: string
  name: string
  description: string | null
  icon_color: string
  owner_id: string
  owner_name: string
  created_at: string
  members: GroupMember[]
  member_count: number
}

interface GetGroupDetailResponse {
  success: boolean
  group?: GroupDetail
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

    const { group_id }: GetGroupDetailRequest = await req.json()

    if (!group_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'group_id is required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // グループ情報取得
    const { data: group, error: groupError } = await supabaseClient
      .from('groups')
      .select(`
        id,
        name,
        description,
        icon_color,
        owner_id,
        owner:owner_id (
          display_name
        ),
        created_at
      `)
      .eq('id', group_id)
      .single()

    if (groupError || !group) {
      return new Response(
        JSON.stringify({ success: false, error: 'Group not found' }),
        {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // メンバー一覧取得
    const { data: members, error: memberError } = await supabaseClient
      .from('group_members')
      .select(`
        user_id,
        role,
        joined_at,
        users:user_id (
          display_name,
          avatar_url
        )
      `)
      .eq('group_id', group_id)
      .order('joined_at', { ascending: true })

    if (memberError) {
      return new Response(
        JSON.stringify({ success: false, error: `Failed to get members: ${memberError.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const groupMembers: GroupMember[] = (members || []).map((m: any) => ({
      user_id: m.user_id,
      display_name: m.users?.display_name || '',
      avatar_url: m.users?.avatar_url || null,
      role: m.role,
      joined_at: m.joined_at
    }))

    const groupDetail: GroupDetail = {
      id: group.id,
      name: group.name,
      description: group.description,
      icon_color: group.icon_color,
      owner_id: group.owner_id,
      owner_name: (group.owner as any)?.display_name || '',
      created_at: group.created_at,
      members: groupMembers,
      member_count: groupMembers.length
    }

    const response: GetGroupDetailResponse = {
      success: true,
      group: groupDetail
    }

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Get group detail error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
