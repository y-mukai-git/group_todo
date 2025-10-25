// TODOコメント作成 Edge Function
// URL・外部リンク検出機能付き

import { serve } from "https://deno.land/std@0.192.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

declare var Deno: any;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface CreateCommentRequest {
  todo_id: string
  user_id: string
  content: string
}

interface CreateCommentResponse {
  success: boolean
  comment?: {
    id: string
    todo_id: string
    user_id: string
    content: string
    created_at: string
  }
  error?: string
}

// URL・リンク検出（セキュリティ対策）
function containsUrl(text: string): boolean {
  const urlPatterns = [
    /https?:\/\//i,
    /www\./i,
    /\:\/\//,
    /\.(com|net|org|jp|co\.jp|info|io|dev|app)/i
  ]
  return urlPatterns.some(pattern => pattern.test(text))
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

    const { todo_id, user_id, content }: CreateCommentRequest = await req.json()

    if (!todo_id || !user_id || !content) {
      return new Response(
        JSON.stringify({ success: false, error: 'todo_id, user_id, and content are required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // URL・リンク検出
    if (containsUrl(content)) {
      return new Response(
        JSON.stringify({ success: false, error: 'URLs and links are not allowed in comments' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const now = new Date().toISOString()

    // コメント作成
    const { data: newComment, error: commentError } = await supabaseClient
      .from('todo_comments')
      .insert({
        todo_id: todo_id,
        user_id: user_id,
        content: content,
        created_at: now,
        updated_at: now
      })
      .select('id, todo_id, user_id, content, created_at')
      .single()

    if (commentError || !newComment) {
      return new Response(
        JSON.stringify({ success: false, error: `Comment creation failed: ${commentError?.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const response: CreateCommentResponse = {
      success: true,
      comment: {
        id: newComment.id,
        todo_id: newComment.todo_id,
        user_id: newComment.user_id,
        content: newComment.content,
        created_at: newComment.created_at
      }
    }

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Create comment error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
