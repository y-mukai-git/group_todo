// グループ作成 Edge Function
import { serve } from "https://deno.land/std@0.192.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

declare var Deno: any;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface CreateGroupRequest {
  user_id: string
  name: string
  description?: string
  icon_color: string
}

interface CreateGroupResponse {
  success: boolean
  group?: {
    id: string
    name: string
    description: string | null
    icon_color: string
    owner_id: string
    created_at: string
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

    const { user_id, name, description, icon_color }: CreateGroupRequest = await req.json()

    if (!user_id || !name || !icon_color) {
      return new Response(
        JSON.stringify({ success: false, error: 'user_id, name, and icon_color are required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const now = new Date().toISOString()

    // グループ作成
    const { data: newGroup, error: groupError } = await supabaseClient
      .from('groups')
      .insert({
        name: name,
        description: description || null,
        icon_color: icon_color,
        owner_id: user_id,
        created_at: now,
        updated_at: now
      })
      .select('id, name, description, icon_color, owner_id, created_at')
      .single()

    if (groupError || !newGroup) {
      return new Response(
        JSON.stringify({ success: false, error: `Group creation failed: ${groupError?.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // グループメンバーにオーナーを追加
    const { error: memberError } = await supabaseClient
      .from('group_members')
      .insert({
        group_id: newGroup.id,
        user_id: user_id,
        role: 'owner',
        joined_at: now
      })

    if (memberError) {
      // グループ作成は成功したが、メンバー追加に失敗した場合はロールバック
      await supabaseClient
        .from('groups')
        .delete()
        .eq('id', newGroup.id)

      return new Response(
        JSON.stringify({ success: false, error: `Member addition failed: ${memberError.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const response: CreateGroupResponse = {
      success: true,
      group: {
        id: newGroup.id,
        name: newGroup.name,
        description: newGroup.description,
        icon_color: newGroup.icon_color,
        owner_id: newGroup.owner_id,
        created_at: newGroup.created_at
      }
    }

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Create group error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
