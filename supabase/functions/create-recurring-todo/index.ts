// 定期TODO作成 Edge Function
import { serve } from "https://deno.land/std@0.192.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

declare var Deno: any;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface CreateRecurringTodoRequest {
  group_id: string
  title: string
  description?: string
  category: 'shopping' | 'housework' | 'other'
  recurrence_pattern: 'daily' | 'weekly' | 'monthly'
  recurrence_days?: number[] // weekly: 0-6, monthly: 1-31/-1
  generation_time: string // HH:MM形式
  assigned_user_ids: string[]
  created_by: string
}

interface CreateRecurringTodoResponse {
  success: boolean
  recurring_todo?: {
    id: string
    group_id: string
    title: string
    recurrence_pattern: string
    next_generation_at: string
  }
  error?: string
}

// 次回生成日時を計算
function calculateNextGeneration(
  pattern: string,
  days: number[] | null,
  time: string
): Date {
  const now = new Date()
  const [hours, minutes] = time.split(':').map(Number)

  if (pattern === 'daily') {
    const next = new Date(now)
    next.setHours(hours, minutes, 0, 0)
    if (next <= now) {
      next.setDate(next.getDate() + 1)
    }
    return next
  }

  if (pattern === 'weekly' && days && days.length > 0) {
    const next = new Date(now)
    next.setHours(hours, minutes, 0, 0)
    const currentDay = next.getDay()

    // 今週の残りの曜日をチェック
    const futureDays = days.filter(d => d > currentDay || (d === currentDay && next > now))
    if (futureDays.length > 0) {
      const nextDay = Math.min(...futureDays)
      next.setDate(next.getDate() + (nextDay - currentDay))
      return next
    }

    // 来週の最初の曜日
    const nextDay = Math.min(...days)
    next.setDate(next.getDate() + (7 - currentDay + nextDay))
    return next
  }

  if (pattern === 'monthly' && days && days.length > 0) {
    const next = new Date(now)
    next.setHours(hours, minutes, 0, 0)

    for (const day of days.sort((a, b) => a - b)) {
      if (day === -1) {
        // 月末
        const lastDay = new Date(next.getFullYear(), next.getMonth() + 1, 0)
        if (lastDay > now) {
          return lastDay
        }
      } else if (day > next.getDate()) {
        next.setDate(day)
        return next
      }
    }

    // 来月
    next.setMonth(next.getMonth() + 1)
    const firstDay = days[0] === -1
      ? new Date(next.getFullYear(), next.getMonth() + 1, 0)
      : new Date(next.getFullYear(), next.getMonth(), days[0])
    return firstDay
  }

  // デフォルト：明日
  const next = new Date(now)
  next.setDate(next.getDate() + 1)
  next.setHours(hours, minutes, 0, 0)
  return next
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

    const {
      group_id,
      title,
      description,
      category,
      recurrence_pattern,
      recurrence_days,
      generation_time,
      assigned_user_ids,
      created_by
    }: CreateRecurringTodoRequest = await req.json()

    if (!group_id || !title || !category || !recurrence_pattern || !generation_time || !assigned_user_ids || !created_by) {
      return new Response(
        JSON.stringify({ success: false, error: 'Required fields are missing' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const now = new Date().toISOString()
    const nextGeneration = calculateNextGeneration(recurrence_pattern, recurrence_days || null, generation_time)

    // 定期TODO作成
    const { data: newRecurringTodo, error: recurringError } = await supabaseClient
      .from('recurring_todos')
      .insert({
        group_id: group_id,
        title: title,
        description: description || null,
        category: category,
        recurrence_pattern: recurrence_pattern,
        recurrence_days: recurrence_days || null,
        generation_time: generation_time,
        next_generation_at: nextGeneration.toISOString(),
        is_active: true,
        created_by: created_by,
        created_at: now,
        updated_at: now
      })
      .select('id, group_id, title, recurrence_pattern, next_generation_at')
      .single()

    if (recurringError || !newRecurringTodo) {
      return new Response(
        JSON.stringify({ success: false, error: `Recurring TODO creation failed: ${recurringError?.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 担当者追加
    const assignmentInserts = assigned_user_ids.map(user_id => ({
      recurring_todo_id: newRecurringTodo.id,
      user_id: user_id,
      assigned_at: now
    }))

    const { error: assignmentError } = await supabaseClient
      .from('recurring_todo_assignments')
      .insert(assignmentInserts)

    if (assignmentError) {
      // ロールバック
      await supabaseClient
        .from('recurring_todos')
        .delete()
        .eq('id', newRecurringTodo.id)

      return new Response(
        JSON.stringify({ success: false, error: `Assignment creation failed: ${assignmentError.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const response: CreateRecurringTodoResponse = {
      success: true,
      recurring_todo: {
        id: newRecurringTodo.id,
        group_id: newRecurringTodo.group_id,
        title: newRecurringTodo.title,
        recurrence_pattern: newRecurringTodo.recurrence_pattern,
        next_generation_at: newRecurringTodo.next_generation_at
      }
    }

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Create recurring todo error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
