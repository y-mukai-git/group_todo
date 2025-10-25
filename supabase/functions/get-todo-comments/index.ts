// TODOコメント一覧取得 Edge Function
import { serve } from "https://deno.land/std@0.192.0/http/server.ts"

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

declare var Deno: any;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface GetCommentsRequest {
  todo_id: string
}

interface CommentWithUser {
  id: string
  user_id: string
  user_name: string
  avatar_url: string | null
  content: string
  created_at: string
}

interface GetCommentsResponse {
  success: boolean
  comments?: CommentWithUser[]
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

    const { todo_id }: GetCommentsRequest = await req.json()

    if (!todo_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'todo_id is required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // コメント一覧取得（時系列順）
    const { data: comments, error: commentError } = await supabaseClient
      .from('todo_comments')
      .select(`
        id,
        user_id,
        users:user_id (
          display_name,
          avatar_url
        ),
        content,
        created_at
      `)
      .eq('todo_id', todo_id)
      .order('created_at', { ascending: true })

    if (commentError) {
      return new Response(
        JSON.stringify({ success: false, error: `Failed to get comments: ${commentError.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const commentsWithUser: CommentWithUser[] = (comments || []).map((c: any) => ({
      id: c.id,
      user_id: c.user_id,
      user_name: c.users?.display_name || '',
      avatar_url: c.users?.avatar_url || null,
      content: c.content,
      created_at: c.created_at
    }))

    const response: GetCommentsResponse = {
      success: true,
      comments: commentsWithUser
    }

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Get comments error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
