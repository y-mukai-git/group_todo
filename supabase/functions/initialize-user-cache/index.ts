// ユーザーキャッシュ初期化用 Edge Function
// 全データ（タスク・グループ・メンバー）を一括取得

import { serve } from "https://deno.land/std@0.192.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'
import { checkMaintenanceMode } from '../_shared/maintenance.ts'

declare var Deno: any;



interface InitializeUserCacheRequest {
  user_id: string
}

interface TodoItem {
  id: string
  group_id: string
  group_name: string
  title: string
  description: string | null
  deadline: string | null
  is_completed: boolean
  created_by: string
  created_at: string
  assignees: {
    user_id: string
    display_name: string
    avatar_url: string | null
  }[]
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

interface GroupMembersData {
  success: boolean
  members: Array<{
    id: string
    device_id: string
    display_name: string
    display_id: string
    avatar_url: string | null
    signed_avatar_url: string | null
    role: string
    joined_at: string
    notification_deadline: boolean
    notification_new_todo: boolean
    notification_assigned: boolean
    created_at: string
    updated_at: string
  }>
  owner_id: string
}

interface InitializeUserCacheResponse {
  success: boolean
  todos?: TodoItem[]
  groups?: GroupWithStats[]
  group_members?: { [groupId: string]: GroupMembersData }
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

    const { user_id }: InitializeUserCacheRequest = await req.json()

    if (!user_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'user_id is required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // ========================================
    // 1. ユーザーの所属グループ一覧取得
    // ========================================
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

    const groupsWithStats: GroupWithStats[] = []
    const groupIds: string[] = []

    // グループ情報を整形
    for (const member of groupMembers || []) {
      const group = member.groups as any

      if (!group) continue

      groupIds.push(group.id)

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
            .createSignedUrl(group.icon_url, 3600)

          if (!signedUrlError && signedUrlData?.signedUrl) {
            signedIconUrl = signedUrlData.signedUrl
          }
        } catch (error) {
          console.error('Failed to create signed URL:', error)
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
        joined_at: member.joined_at,
        display_order: member.display_order || 0
      })
    }

    // ========================================
    // 2. 全タスク取得（個人 + 全グループ）
    // ========================================

    // 自分が担当のTODO IDを取得
    const { data: assignments, error: assignmentError } = await supabaseClient
      .from('todo_assignments')
      .select('todo_id')
      .eq('user_id', user_id)

    if (assignmentError) {
      return new Response(
        JSON.stringify({ success: false, error: `Failed to get assignments: ${assignmentError.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const myTodoIds = (assignments || []).map(a => a.todo_id)

    // 全グループのTODOを一括取得（IN句使用）
    let allTodos: any[] = []

    if (groupIds.length > 0) {
      const { data: groupTodos, error: groupTodosError } = await supabaseClient
        .from('todos')
        .select('id, group_id, title, description, deadline, is_completed, created_by, created_at')
        .in('group_id', groupIds)
        .order('deadline', { ascending: true, nullsFirst: false })

      if (groupTodosError) {
        return new Response(
          JSON.stringify({ success: false, error: `Failed to get group todos: ${groupTodosError.message}` }),
          {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        )
      }

      allTodos = groupTodos || []
    }

    // 各TODOに担当者情報とグループ名を追加
    const todoItems: TodoItem[] = []
    for (const todo of allTodos) {
      // 担当者情報取得
      const { data: todoAssignments } = await supabaseClient
        .from('todo_assignments')
        .select(`
          user_id,
          users:user_id (
            display_name,
            avatar_url
          )
        `)
        .eq('todo_id', todo.id)

      const assignees = (todoAssignments || []).map((a: any) => ({
        user_id: a.user_id,
        display_name: a.users?.display_name || '',
        avatar_url: a.users?.avatar_url || null
      }))

      // グループ名を取得
      const groupInfo = groupsWithStats.find(g => g.id === todo.group_id)

      todoItems.push({
        id: todo.id,
        group_id: todo.group_id,
        group_name: groupInfo?.name || '',
        title: todo.title,
        description: todo.description,
        deadline: todo.deadline,
        is_completed: todo.is_completed,
        created_by: todo.created_by,
        created_at: todo.created_at,
        assignees: assignees
      })
    }

    // ========================================
    // 3. 全グループのメンバー情報を一括取得
    // ========================================
    const groupMembersData: { [groupId: string]: GroupMembersData } = {}

    for (const groupId of groupIds) {
      // グループメンバー一覧取得
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
        .eq('group_id', groupId)

      if (membersError) {
        console.error(`Failed to fetch members for group ${groupId}:`, membersError)
        continue
      }

      // グループオーナーID取得
      const groupInfo = groupsWithStats.find(g => g.id === groupId)
      const ownerId = groupInfo?.owner_id || ''

      // 各メンバーの署名付きURL生成
      const membersList = await Promise.all((members || []).map(async (member: any) => {
        let signedAvatarUrl: string | null = null
        if (member.users.avatar_url) {
          try {
            const { data: signedUrlData, error: signedUrlError } = await supabaseClient
              .storage
              .from('user-avatars')
              .createSignedUrl(member.users.avatar_url, 3600)

            if (!signedUrlError && signedUrlData?.signedUrl) {
              signedAvatarUrl = signedUrlData.signedUrl
            }
          } catch (error) {
            console.error('Failed to create signed URL for user:', member.users.id, error)
          }
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
          notification_deadline: member.users.notification_deadline,
          notification_new_todo: member.users.notification_new_todo,
          notification_assigned: member.users.notification_assigned,
          created_at: member.users.created_at,
          updated_at: member.users.updated_at
        }
      }))

      groupMembersData[groupId] = {
        success: true,
        members: membersList,
        owner_id: ownerId
      }
    }

    // ========================================
    // レスポンス返却
    // ========================================
    const response: InitializeUserCacheResponse = {
      success: true,
      todos: todoItems,
      groups: groupsWithStats,
      group_members: groupMembersData
    }

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Initialize user cache error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
