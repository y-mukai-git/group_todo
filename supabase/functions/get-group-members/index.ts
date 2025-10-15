// グループメンバー一覧取得 Edge Function
import { serve } from "https://deno.land/std@0.192.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

declare var Deno: any;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface GetGroupMembersRequest {
  group_id: string
  requester_id: string // リクエスト者のユーザーID（権限チェック用）
}

interface GetGroupMembersResponse {
  success: boolean
  members?: Array<{
    id: string
    display_name: string
    display_id: string
    avatar_url: string | null
    role: string
    joined_at: string
  }>
  owner_id?: string
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

    const { group_id, requester_id }: GetGroupMembersRequest = await req.json()

    if (!group_id || !requester_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'group_id and requester_id are required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // リクエスト者がグループのメンバーかチェック
    const { data: membership, error: membershipError } = await supabaseClient
      .from('group_members')
      .select('id')
      .eq('group_id', group_id)
      .eq('user_id', requester_id)
      .single()

    if (membershipError || !membership) {
      return new Response(
        JSON.stringify({ success: false, error: 'Not a member of this group' }),
        {
          status: 403,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // グループオーナーID取得
    const { data: group, error: groupError } = await supabaseClient
      .from('groups')
      .select('owner_id')
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

    // グループメンバー一覧取得（usersテーブルとJOIN）
    const { data: members, error: membersError } = await supabaseClient
      .from('group_members')
      .select(`
        role,
        joined_at,
        users (
          id,
          display_name,
          display_id,
          avatar_url
        )
      `)
      .eq('group_id', group_id)

    if (membersError) {
      return new Response(
        JSON.stringify({ success: false, error: `Failed to fetch members: ${membersError.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // レスポンス構築
    const membersList = (members || []).map((member: any) => ({
      id: member.users.id,
      display_name: member.users.display_name,
      display_id: member.users.display_id,
      avatar_url: member.users.avatar_url,
      role: member.role,
      joined_at: member.joined_at
    }))

    const response: GetGroupMembersResponse = {
      success: true,
      members: membersList,
      owner_id: group.owner_id
    }

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Get group members error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
