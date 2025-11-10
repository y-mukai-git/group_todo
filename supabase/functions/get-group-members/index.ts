// グループメンバー一覧取得 Edge Function
import { serve } from "https://deno.land/std@0.192.0/http/server.ts"
import { corsHeaders } from '../_shared/cors.ts'
import { checkMaintenanceMode } from '../_shared/maintenance.ts'

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

declare var Deno: any;



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
    signed_avatar_url?: string | null // 署名付きURL（有効期限1時間）
    role: string | null
    joined_at: string
    is_pending: boolean
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

    // メンテナンスモードチェック
    const checkResult = await checkMaintenanceMode()
    if (checkResult.status === 'error' || checkResult.status === 'maintenance') {
      return new Response(
        JSON.stringify(checkResult),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

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
          status: 200,
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
          status: 200,
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
          device_id,
          display_name,
          display_id,
          avatar_url,
          notification_deadline,
          notification_new_todo,
          notification_assigned,
          created_at,
          updated_at
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

    // 承諾待ち招待一覧取得（usersテーブルとJOIN）
    const { data: pendingInvitations, error: invitationsError} = await supabaseClient
      .from('group_invitations')
      .select(`
        invited_role,
        invited_at,
        users!group_invitations_invited_user_id_fkey (
          id,
          device_id,
          display_name,
          display_id,
          avatar_url,
          notification_deadline,
          notification_new_todo,
          notification_assigned,
          created_at,
          updated_at
        )
      `)
      .eq('group_id', group_id)
      .eq('status', 'pending')

    if (invitationsError) {
      console.error(`[ERROR] Failed to fetch invitations: ${invitationsError.message}`, invitationsError)
      return new Response(
        JSON.stringify({ success: false, error: `Failed to fetch invitations: ${invitationsError.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // レスポンス構築（各メンバーのSigned URL生成）
    const membersList = await Promise.all((members || []).map(async (member: any) => {
      // 署名付きURL生成（avatar_urlが存在する場合）
      let signedAvatarUrl: string | null = null
      if (member.users.avatar_url) {
        const { data: signedUrlData, error: signedUrlError } = await supabaseClient
          .storage
          .from('user-avatars')
          .createSignedUrl(member.users.avatar_url, 3600) // 有効期限1時間

        if (signedUrlError) {
          throw new Error(`Failed to create signed URL for user ${member.users.id}: ${signedUrlError.message}`)
        }

        signedAvatarUrl = signedUrlData.signedUrl
      }

      return {
        id: member.users.id,
        device_id: member.users.device_id,
        display_name: member.users.display_name,
        display_id: member.users.display_id,
        avatar_url: member.users.avatar_url,
        signed_avatar_url: signedAvatarUrl,
        role: member.role,
        joined_at: member.joined_at,
        is_pending: false,
        notification_deadline: member.users.notification_deadline,
        notification_new_todo: member.users.notification_new_todo,
        notification_assigned: member.users.notification_assigned,
        created_at: member.users.created_at,
        updated_at: member.users.updated_at
      }
    }))

    // 承諾待ちユーザーのリスト構築
    const pendingList = await Promise.all((pendingInvitations || []).map(async (invitation: any) => {
      // 署名付きURL生成（avatar_urlが存在する場合）
      let signedAvatarUrl: string | null = null
      if (invitation.users.avatar_url) {
        const { data: signedUrlData, error: signedUrlError } = await supabaseClient
          .storage
          .from('user-avatars')
          .createSignedUrl(invitation.users.avatar_url, 3600) // 有効期限1時間

        if (signedUrlError) {
          throw new Error(`Failed to create signed URL for user ${invitation.users.id}: ${signedUrlError.message}`)
        }

        signedAvatarUrl = signedUrlData.signedUrl
      }

      return {
        id: invitation.users.id,
        device_id: invitation.users.device_id,
        display_name: invitation.users.display_name,
        display_id: invitation.users.display_id,
        avatar_url: invitation.users.avatar_url,
        signed_avatar_url: signedAvatarUrl,
        role: null,
        joined_at: invitation.invited_at,
        is_pending: true,
        notification_deadline: invitation.users.notification_deadline,
        notification_new_todo: invitation.users.notification_new_todo,
        notification_assigned: invitation.users.notification_assigned,
        created_at: invitation.users.created_at,
        updated_at: invitation.users.updated_at
      }
    }))

    // メンバーと承諾待ちユーザーを結合してソート
    // 順序: owner → member → pending
    const allMembers = [...membersList, ...pendingList].sort((a, b) => {
      // roleの優先順位を数値化
      const getRolePriority = (member: any) => {
        if (member.role === 'owner') return 1
        if (member.role === 'member') return 2
        if (member.is_pending) return 3
        return 4
      }

      return getRolePriority(a) - getRolePriority(b)
    })

    const response: GetGroupMembersResponse = {
      success: true,
      members: allMembers,
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
