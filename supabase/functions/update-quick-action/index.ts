// クイックアクション更新 Edge Function
import { serve } from "https://deno.land/std@0.192.0/http/server.ts"
import { corsHeaders } from '../_shared/cors.ts'
import { checkMaintenanceMode } from '../_shared/maintenance.ts'
import { checkGroupMembership } from '../_shared/permission.ts'

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

declare var Deno: any;

interface QuickActionTemplate {
  title: string
  description?: string
  deadline_days_after?: number
  assigned_user_ids?: string[]
  display_order: number
}

interface UpdateQuickActionRequest {
  quick_action_id: string
  user_id: string
  name?: string
  description?: string
  templates?: QuickActionTemplate[]
}

interface UpdateQuickActionResponse {
  success: boolean
  quick_action?: any
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

    const {
      quick_action_id,
      user_id,
      name,
      description,
      templates
    }: UpdateQuickActionRequest = await req.json()

    if (!quick_action_id || !user_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'quick_action_id and user_id are required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // クイックアクション取得と権限チェック
    const { data: quickAction } = await supabaseClient
      .from('quick_actions')
      .select('created_by, group_id')
      .eq('id', quick_action_id)
      .single()

    if (!quickAction) {
      return new Response(
        JSON.stringify({ success: false, error: 'Quick action not found' }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // メンバーシップチェック
    const membershipCheck = await checkGroupMembership(supabaseClient, quickAction.group_id, user_id)
    if (!membershipCheck.success) {
      return new Response(
        JSON.stringify({ success: false, error: membershipCheck.error }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // グループオーナー確認
    const { data: group } = await supabaseClient
      .from('groups')
      .select('owner_id')
      .eq('id', quickAction.group_id)
      .single()

    const isCreator = quickAction.created_by === user_id
    const isOwner = group?.owner_id === user_id

    if (!isCreator && !isOwner) {
      return new Response(
        JSON.stringify({ success: false, error: 'Only creator or group owner can update quick action' }),
        {
          status: 403,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const now = new Date().toISOString()

    // 更新データ準備
    const updateData: any = { updated_at: now }
    if (name !== undefined) updateData.name = name
    if (description !== undefined) updateData.description = description

    // クイックアクション更新
    const { data: updated, error: updateError } = await supabaseClient
      .from('quick_actions')
      .update(updateData)
      .eq('id', quick_action_id)
      .select('id, group_id, name, description, created_by, created_at, updated_at, display_order')
      .single()

    if (updateError || !updated) {
      return new Response(
        JSON.stringify({ success: false, error: `Failed to update quick action: ${updateError?.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // テンプレート更新（指定されている場合）
    let updatedTemplates = []
    if (templates !== undefined) {
      // 既存テンプレート削除
      await supabaseClient
        .from('quick_action_templates')
        .delete()
        .eq('quick_action_id', quick_action_id)

      if (templates.length > 0) {
        // 新しいテンプレート挿入
        const templateInserts = templates.map(template => ({
          quick_action_id: quick_action_id,
          title: template.title,
          description: template.description || null,
          deadline_days_after: template.deadline_days_after || null,
          assigned_user_ids: template.assigned_user_ids || [],
          display_order: template.display_order,
          created_at: now
        }))

        const { data: createdTemplates, error: templateError } = await supabaseClient
          .from('quick_action_templates')
          .insert(templateInserts)
          .select('id, quick_action_id, title, description, deadline_days_after, assigned_user_ids, display_order, created_at')

        if (templateError) {
          return new Response(
            JSON.stringify({ success: false, error: `Template update failed: ${templateError.message}` }),
            {
              status: 500,
              headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            }
          )
        }

        updatedTemplates = createdTemplates || []
      }
    } else {
      // テンプレートが指定されていない場合は既存テンプレートを取得
      const { data: existingTemplates } = await supabaseClient
        .from('quick_action_templates')
        .select('*')
        .eq('quick_action_id', quick_action_id)
        .order('display_order', { ascending: true })

      updatedTemplates = existingTemplates || []
    }

    const response: UpdateQuickActionResponse = {
      success: true,
      quick_action: {
        ...updated,
        templates: updatedTemplates
      }
    }

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Update quick action error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
