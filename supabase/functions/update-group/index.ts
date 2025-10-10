// グループ更新 Edge Function
import { serve } from "https://deno.land/std@0.192.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

declare var Deno: any;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface UpdateGroupRequest {
  group_id: string
  user_id: string // オーナーチェック用
  name?: string
  description?: string
  icon_color?: string
  category?: string
}

interface UpdateGroupResponse {
  success: boolean
  group?: {
    id: string
    name: string
    description: string | null
    icon_color: string
    owner_id: string
    category: string | null
  }
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

    const { group_id, user_id, name, description, icon_color, category }: UpdateGroupRequest = await req.json()

    if (!group_id || !user_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'group_id and user_id are required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // オーナーチェック
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

    if (group.owner_id !== user_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'Only group owner can update group' }),
        {
          status: 403,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 更新データ準備
    const updateData: any = { updated_at: new Date().toISOString() }
    if (name !== undefined) updateData.name = name
    if (description !== undefined) updateData.description = description
    if (icon_color !== undefined) updateData.icon_color = icon_color
    if (category !== undefined) updateData.category = category

    // グループ更新
    const { data: updatedGroup, error: updateError } = await supabaseClient
      .from('groups')
      .update(updateData)
      .eq('id', group_id)
      .select('id, name, description, icon_color, owner_id, category')
      .single()

    if (updateError || !updatedGroup) {
      return new Response(
        JSON.stringify({ success: false, error: `Failed to update group: ${updateError?.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const response: UpdateGroupResponse = {
      success: true,
      group: {
        id: updatedGroup.id,
        name: updatedGroup.name,
        description: updatedGroup.description,
        icon_color: updatedGroup.icon_color,
        owner_id: updatedGroup.owner_id,
        category: updatedGroup.category
      }
    }

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Update group error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
