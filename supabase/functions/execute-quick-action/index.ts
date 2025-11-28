// クイックアクション実行 Edge Function
import { serve } from "https://deno.land/std@0.192.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'
import { checkMaintenanceMode } from '../_shared/maintenance.ts'
import { checkGroupMembership } from '../_shared/permission.ts'

declare var Deno: any;

interface ExecuteQuickActionRequest {
  quick_action_id: string
  executed_by: string
}

interface ExecuteQuickActionResponse {
  success: boolean
  todos?: Array<{
    id: string
    group_id: string
    title: string
    description: string | null
    deadline: string | null
    is_completed: boolean
    created_by: string
    created_at: string
    assigned_users: string[]
  }>
  error?: string
}

/**
 * 担当者がグループメンバーかチェックし、離脱者の場合はフォールバック先を返す
 * 優先順位: クイックアクション作成者 → グループ作成者 → オーナー
 */
async function resolveAssignees(
  supabaseClient: any,
  groupId: string,
  quickActionCreatedBy: string,
  assignedUserIds: string[]
): Promise<string[]> {
  const resolvedAssignees: string[] = []

  // グループメンバー一覧を取得
  const { data: members, error: membersError } = await supabaseClient
    .from('group_members')
    .select('user_id, role')
    .eq('group_id', groupId)

  if (membersError || !members) {
    console.error('Failed to get group members:', membersError)
    return []
  }

  const memberIds = new Set(members.map((m: any) => m.user_id))
  const ownerId = members.find((m: any) => m.role === 'owner')?.user_id

  // グループ情報を取得（グループ作成者取得用）
  const { data: group, error: groupError } = await supabaseClient
    .from('groups')
    .select('created_by')
    .eq('id', groupId)
    .single()

  if (groupError || !group) {
    console.error('Failed to get group:', groupError)
    return []
  }

  const groupCreatedBy = group.created_by

  // 各担当者をチェック
  for (const userId of assignedUserIds) {
    if (memberIds.has(userId)) {
      // まだグループメンバー → そのまま割り当て
      resolvedAssignees.push(userId)
    } else {
      // グループから離脱 → フォールバック
      let fallbackUserId: string | null = null

      // 優先順位1: クイックアクション作成者
      if (memberIds.has(quickActionCreatedBy)) {
        fallbackUserId = quickActionCreatedBy
      }
      // 優先順位2: グループ作成者
      else if (memberIds.has(groupCreatedBy)) {
        fallbackUserId = groupCreatedBy
      }
      // 優先順位3: オーナー
      else if (ownerId) {
        fallbackUserId = ownerId
      }

      if (fallbackUserId) {
        resolvedAssignees.push(fallbackUserId)
      }
    }
  }

  // 重複を除去
  return Array.from(new Set(resolvedAssignees))
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

    const { quick_action_id, executed_by }: ExecuteQuickActionRequest = await req.json()

    if (!quick_action_id || !executed_by) {
      return new Response(
        JSON.stringify({ success: false, error: 'quick_action_id and executed_by are required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // クイックアクションを取得
    const { data: quickAction, error: quickActionError } = await supabaseClient
      .from('quick_actions')
      .select('id, group_id, name, created_by')
      .eq('id', quick_action_id)
      .single()

    if (quickActionError || !quickAction) {
      return new Response(
        JSON.stringify({ success: false, error: 'Quick action not found' }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // メンバーシップチェック
    const membershipCheck = await checkGroupMembership(supabaseClient, quickAction.group_id, executed_by)
    if (!membershipCheck.success) {
      return new Response(
        JSON.stringify({ success: false, error: membershipCheck.error }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // クイックアクションテンプレートを取得
    const { data: templates, error: templatesError } = await supabaseClient
      .from('quick_action_templates')
      .select('id, title, description, deadline_days_after, assigned_user_ids, display_order')
      .eq('quick_action_id', quick_action_id)
      .order('display_order')

    if (templatesError) {
      return new Response(
        JSON.stringify({ success: false, error: `Failed to get templates: ${templatesError.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    if (!templates || templates.length === 0) {
      return new Response(
        JSON.stringify({ success: false, error: 'No templates found for this quick action' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const now = new Date().toISOString()
    const createdTodos: any[] = []

    // 各テンプレートからTODOを生成
    for (const template of templates) {
      // 担当者の解決（グループ離脱者のフォールバック処理）
      const assignedUserIds = template.assigned_user_ids || []
      const resolvedAssignees = await resolveAssignees(
        supabaseClient,
        quickAction.group_id,
        quickAction.created_by,
        assignedUserIds
      )

      // 期限計算
      let deadline: string | null = null
      if (template.deadline_days_after) {
        const deadlineDate = new Date()
        deadlineDate.setDate(deadlineDate.getDate() + template.deadline_days_after)
        deadline = deadlineDate.toISOString()
      }

      // TODO作成
      const { data: newTodo, error: todoError } = await supabaseClient
        .from('todos')
        .insert({
          group_id: quickAction.group_id,
          title: template.title,
          description: template.description || null,
          deadline: deadline,
          is_completed: false,
          created_by: executed_by,
          created_at: now,
          updated_at: now
        })
        .select('id, group_id, title, description, deadline, is_completed, created_by, created_at')
        .single()

      if (todoError || !newTodo) {
        console.error('TODO creation failed:', todoError)
        continue // エラーでも他のテンプレートは処理を続ける
      }

      // 担当者を追加
      if (resolvedAssignees.length > 0) {
        const assignmentInserts = resolvedAssignees.map(user_id => ({
          todo_id: newTodo.id,
          user_id: user_id,
          assigned_at: now
        }))

        const { error: assignmentError } = await supabaseClient
          .from('todo_assignments')
          .insert(assignmentInserts)

        if (assignmentError) {
          console.error('Assignment creation failed:', assignmentError)
          // 担当者追加に失敗してもTODOは作成されたままにする
        }
      }

      createdTodos.push({
        id: newTodo.id,
        group_id: newTodo.group_id,
        title: newTodo.title,
        description: newTodo.description,
        deadline: newTodo.deadline,
        is_completed: newTodo.is_completed,
        created_by: newTodo.created_by,
        created_at: newTodo.created_at,
        assigned_users: resolvedAssignees
      })
    }

    const response: ExecuteQuickActionResponse = {
      success: true,
      todos: createdTodos
    }

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Execute quick action error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
