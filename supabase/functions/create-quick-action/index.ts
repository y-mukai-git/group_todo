// クイックアクション作成 Edge Function
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

interface CreateQuickActionRequest {
  group_id: string
  name: string
  description?: string
  created_by: string
  templates: QuickActionTemplate[]
}

interface CreateQuickActionResponse {
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
    const checkResult = await checkMaintenanceMode()
    if (checkResult.status === 'error' || checkResult.status === 'maintenance') {
      return new Response(
        JSON.stringify(checkResult),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const {
      group_id,
      name,
      description,
      created_by,
      templates
    }: CreateQuickActionRequest = await req.json()

    if (!group_id || !name || !created_by || !templates || templates.length === 0) {
      return new Response(
        JSON.stringify({ success: false, error: 'Required fields are missing' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // メンバーシップチェック
    const membershipCheck = await checkGroupMembership(supabaseClient, group_id, created_by)
    if (!membershipCheck.success) {
      return new Response(
        JSON.stringify({ success: false, error: membershipCheck.error }),
        {
          status: 403,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const now = new Date().toISOString()

    // クイックアクション作成
    const { data: newQuickAction, error: quickActionError } = await supabaseClient
      .from('quick_actions')
      .insert({
        group_id: group_id,
        name: name,
        description: description || null,
        created_by: created_by,
        created_at: now,
        updated_at: now,
        display_order: 0
      })
      .select('id, group_id, name, description, created_by, created_at, updated_at, display_order')
      .single()

    if (quickActionError || !newQuickAction) {
      return new Response(
        JSON.stringify({ success: false, error: `Quick action creation failed: ${quickActionError?.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // テンプレート作成
    const templateInserts = templates.map(template => ({
      quick_action_id: newQuickAction.id,
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
      // ロールバック: クイックアクションを削除
      await supabaseClient
        .from('quick_actions')
        .delete()
        .eq('id', newQuickAction.id)

      return new Response(
        JSON.stringify({ success: false, error: `Template creation failed: ${templateError.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // レスポンス作成（テンプレートを含む）
    const response: CreateQuickActionResponse = {
      success: true,
      quick_action: {
        ...newQuickAction,
        templates: createdTemplates
      }
    }

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Create quick action error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
