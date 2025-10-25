// グループメンバー削除 Edge Function
import { serve } from "https://deno.land/std@0.192.0/http/server.ts"

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

declare var Deno: any;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface RemoveGroupMemberRequest {
  group_id: string
  target_user_id: string // 削除対象のユーザーID
  requester_id: string // 削除実行者のユーザーID
}

interface RemoveGroupMemberResponse {
  success: boolean
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
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? ''
    const checkResponse = await fetch(`${supabaseUrl}/functions/v1/check-maintenance-mode`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${supabaseAnonKey}`,
      },
    })
    const checkResult = await checkResponse.json()
    if (checkResult.status === 'error' || checkResult.status === 'maintenance') {
      return new Response(
        JSON.stringify(checkResult),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const { group_id, target_user_id, requester_id }: RemoveGroupMemberRequest = await req.json()

    if (!group_id || !target_user_id || !requester_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'group_id, target_user_id, and requester_id are required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // グループ取得
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

    // 削除対象がオーナーの場合は削除不可
    if (group.owner_id === target_user_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'Cannot remove group owner' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 権限チェック：オーナーまたは本人のみ削除可能
    const isOwner = group.owner_id === requester_id
    const isSelf = target_user_id === requester_id

    if (!isOwner && !isSelf) {
      return new Response(
        JSON.stringify({ success: false, error: 'Only group owner or the member themselves can remove member' }),
        {
          status: 403,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // メンバー削除
    const { error: deleteError } = await supabaseClient
      .from('group_members')
      .delete()
      .eq('group_id', group_id)
      .eq('user_id', target_user_id)

    if (deleteError) {
      return new Response(
        JSON.stringify({ success: false, error: `Failed to remove member: ${deleteError.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const response: RemoveGroupMemberResponse = {
      success: true
    }

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Remove group member error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
