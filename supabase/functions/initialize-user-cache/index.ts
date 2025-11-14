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
    role: string | null
    joined_at: string
    is_pending: boolean
    notification_deadline: boolean
    notification_new_todo: boolean
    notification_assigned: boolean
    created_at: string
    updated_at: string
  }>
  owner_id: string
}

interface RecurringTodoItem {
  id: string
  group_id: string
  title: string
  description: string | null
  recurrence_pattern: string
  recurrence_days: number[] | null
  generation_time: string
  next_generation_at: string
  deadline_days_after: number | null
  is_active: boolean
  created_by: string
  created_at: string
  assignees: {
    user_id: string
    display_name: string
    avatar_url: string | null
  }[]
}

interface QuickActionItem {
  id: string
  group_id: string
  name: string
  description: string | null
  templates: Array<{
    id: string
    title: string
    description: string | null
    deadline_days_after: number | null
    assigned_user_id: string | null
    display_order: number
  }>
  created_by: string
  created_at: string
}

interface InitializeUserCacheResponse {
  success: boolean
  todos?: TodoItem[]
  groups?: GroupWithStats[]
  group_members?: { [groupId: string]: GroupMembersData }
  recurring_todos?: RecurringTodoItem[]
  quick_actions?: QuickActionItem[]
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

    // N+1問題を解決: 全TODO IDを抽出して担当者情報を一括取得
    const todoIds = allTodos.map(todo => todo.id)

    // 全TODOの担当者情報を一括取得
    const { data: allAssignments } = await supabaseClient
      .from('todo_assignments')
      .select(`
        todo_id,
        user_id,
        users:user_id (
          display_name,
          avatar_url
        )
      `)
      .in('todo_id', todoIds)

    // TODO IDごとに担当者情報をグループ化
    const assignmentsMap = new Map<string, any[]>()
    for (const assignment of allAssignments || []) {
      const existing = assignmentsMap.get(assignment.todo_id) || []
      existing.push({
        user_id: assignment.user_id,
        display_name: assignment.users?.display_name || '',
        avatar_url: assignment.users?.avatar_url || null
      })
      assignmentsMap.set(assignment.todo_id, existing)
    }

    // 各TODOに担当者情報とグループ名を追加
    const todoItems: TodoItem[] = []
    for (const todo of allTodos) {
      // Mapから担当者情報を取得
      const assignees = assignmentsMap.get(todo.id) || []

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
    // 3. 全グループのメンバー情報を一括取得（N+1問題を解決）
    // ========================================

    // 全グループのメンバー情報を一括取得
    const { data: allMembers, error: allMembersError } = await supabaseClient
      .from('group_members')
      .select(`
        group_id,
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
      .in('group_id', groupIds)

    if (allMembersError) {
      return new Response(
        JSON.stringify({ success: false, error: `Failed to get members: ${allMembersError.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 全グループの承諾待ち招待を一括取得
    const { data: allInvitations, error: allInvitationsError } = await supabaseClient
      .from('group_invitations')
      .select(`
        group_id,
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
      .in('group_id', groupIds)
      .eq('status', 'pending')

    if (allInvitationsError) {
      console.error('Failed to fetch invitations:', allInvitationsError)
    }

    // グループIDごとにメンバーをグループ化
    const membersMap = new Map<string, any[]>()
    for (const member of allMembers || []) {
      const existing = membersMap.get(member.group_id) || []
      existing.push(member)
      membersMap.set(member.group_id, existing)
    }

    // グループIDごとに招待をグループ化
    const invitationsMap = new Map<string, any[]>()
    for (const invitation of allInvitations || []) {
      const existing = invitationsMap.get(invitation.group_id) || []
      existing.push(invitation)
      invitationsMap.set(invitation.group_id, existing)
    }

    // 各グループのメンバー情報を組み立て
    const groupMembersData: { [groupId: string]: GroupMembersData } = {}

    for (const groupId of groupIds) {
      // Mapからメンバーと招待を取得
      const members = membersMap.get(groupId) || []
      const pendingInvitations = invitationsMap.get(groupId) || []

      // グループオーナーID取得
      const groupInfo = groupsWithStats.find(g => g.id === groupId)
      const ownerId = groupInfo?.owner_id || ''

      // 各メンバーの署名付きURL生成
      const membersList = await Promise.all(members.map(async (member: any) => {
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
          is_pending: false,
          notification_deadline: member.users.notification_deadline,
          notification_new_todo: member.users.notification_new_todo,
          notification_assigned: member.users.notification_assigned,
          created_at: member.users.created_at,
          updated_at: member.users.updated_at
        }
      }))

      // 承諾待ちユーザーのリスト構築
      const pendingList = await Promise.all(pendingInvitations.map(async (invitation: any) => {
        let signedAvatarUrl: string | null = null
        if (invitation.users.avatar_url) {
          try {
            const { data: signedUrlData, error: signedUrlError } = await supabaseClient
              .storage
              .from('user-avatars')
              .createSignedUrl(invitation.users.avatar_url, 3600)

            if (!signedUrlError && signedUrlData?.signedUrl) {
              signedAvatarUrl = signedUrlData.signedUrl
            }
          } catch (error) {
            console.error('Failed to create signed URL for user:', invitation.users.id, error)
          }
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
      const allMembersForGroup = [...membersList, ...pendingList].sort((a, b) => {
        // roleの優先順位を数値化
        const getRolePriority = (member: any) => {
          if (member.role === 'owner') return 1
          if (member.role === 'member') return 2
          if (member.is_pending) return 3
          return 4
        }

        return getRolePriority(a) - getRolePriority(b)
      })

      groupMembersData[groupId] = {
        success: true,
        members: allMembersForGroup,
        owner_id: ownerId
      }
    }

    // ========================================
    // 4. 全グループの定期TODO取得
    // ========================================
    let allRecurringTodos: RecurringTodoItem[] = []

    if (groupIds.length > 0) {
      const { data: recurringTodos, error: recurringTodosError } = await supabaseClient
        .from('recurring_todos')
        .select(`
          id,
          group_id,
          title,
          description,
          recurrence_pattern,
          recurrence_days,
          generation_time,
          next_generation_at,
          deadline_days_after,
          is_active,
          created_by,
          created_at
        `)
        .in('group_id', groupIds)
        .order('created_at', { ascending: false })

      if (recurringTodosError) {
        return new Response(
          JSON.stringify({ success: false, error: `Failed to get recurring todos: ${recurringTodosError.message}` }),
          {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        )
      }

      // 定期TODOの担当者情報を一括取得
      const recurringTodoIds = (recurringTodos || []).map(rt => rt.id)
      const { data: recurringAssignments } = await supabaseClient
        .from('recurring_todo_assignments')
        .select(`
          recurring_todo_id,
          user_id,
          users:user_id (
            display_name,
            avatar_url
          )
        `)
        .in('recurring_todo_id', recurringTodoIds)

      // 定期TODO IDごとに担当者情報をグループ化
      const recurringAssignmentsMap = new Map<string, any[]>()
      for (const assignment of recurringAssignments || []) {
        const existing = recurringAssignmentsMap.get(assignment.recurring_todo_id) || []
        existing.push({
          user_id: assignment.user_id,
          display_name: assignment.users?.display_name || '',
          avatar_url: assignment.users?.avatar_url || null
        })
        recurringAssignmentsMap.set(assignment.recurring_todo_id, existing)
      }

      // 各定期TODOに担当者情報を追加
      allRecurringTodos = (recurringTodos || []).map(rt => ({
        id: rt.id,
        group_id: rt.group_id,
        title: rt.title,
        description: rt.description,
        recurrence_pattern: rt.recurrence_pattern,
        recurrence_days: rt.recurrence_days,
        generation_time: rt.generation_time,
        next_generation_at: rt.next_generation_at,
        deadline_days_after: rt.deadline_days_after,
        is_active: rt.is_active,
        created_by: rt.created_by,
        created_at: rt.created_at,
        assignees: recurringAssignmentsMap.get(rt.id) || []
      }))
    }

    // ========================================
    // 5. 全グループのクイックアクション取得
    // ========================================
    let allQuickActions: QuickActionItem[] = []

    if (groupIds.length > 0) {
      const { data: quickActions, error: quickActionsError } = await supabaseClient
        .from('quick_actions')
        .select(`
          id,
          group_id,
          name,
          description,
          created_by,
          created_at
        `)
        .in('group_id', groupIds)
        .order('created_at', { ascending: false })

      if (quickActionsError) {
        return new Response(
          JSON.stringify({ success: false, error: `Failed to get quick actions: ${quickActionsError.message}` }),
          {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        )
      }

      // クイックアクションのテンプレート情報を一括取得
      const quickActionIds = (quickActions || []).map(qa => qa.id)
      const { data: templates } = await supabaseClient
        .from('quick_action_templates')
        .select(`
          id,
          quick_action_id,
          title,
          description,
          deadline_days_after,
          assigned_user_id,
          display_order
        `)
        .in('quick_action_id', quickActionIds)
        .order('display_order', { ascending: true })

      // クイックアクション IDごとにテンプレートをグループ化
      const templatesMap = new Map<string, any[]>()
      for (const template of templates || []) {
        const existing = templatesMap.get(template.quick_action_id) || []
        existing.push({
          id: template.id,
          title: template.title,
          description: template.description,
          deadline_days_after: template.deadline_days_after,
          assigned_user_id: template.assigned_user_id,
          display_order: template.display_order
        })
        templatesMap.set(template.quick_action_id, existing)
      }

      // 各クイックアクションにテンプレート情報を追加
      allQuickActions = (quickActions || []).map(qa => ({
        id: qa.id,
        group_id: qa.group_id,
        name: qa.name,
        description: qa.description,
        templates: templatesMap.get(qa.id) || [],
        created_by: qa.created_by,
        created_at: qa.created_at
      }))
    }

    // ========================================
    // レスポンス返却
    // ========================================
    const response: InitializeUserCacheResponse = {
      success: true,
      todos: todoItems,
      groups: groupsWithStats,
      group_members: groupMembersData,
      recurring_todos: allRecurringTodos,
      quick_actions: allQuickActions
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
