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
  deadline_days_after?: number // 生成から何日後に期限を設定するか（null = 期限なし）
  assigned_user_ids: string[]
  created_by: string
}

interface CreateRecurringTodoResponse {
  success: boolean
  recurring_todo?: any  // 全フィールドを返すため、型を柔軟に
  error?: string
}

// 次回生成日時を計算（JST対応版）
// generation_timeをJST（Asia/Tokyo）として解釈し、UTCのDateを返す
function calculateNextGeneration(
  pattern: string,
  days: number[] | null,
  time: string
): Date {
  const JST_OFFSET = 9 * 60 * 60 * 1000; // 9時間をミリ秒で
  const now = new Date();
  const [hours, minutes] = time.split(':').map(Number);

  // 現在時刻をJSTに変換（UTC時刻に9時間加算）
  const nowJst = new Date(now.getTime() + JST_OFFSET);

  if (pattern === 'daily') {
    // JSTで翌日の日付を取得
    const nextJst = new Date(nowJst);
    nextJst.setUTCDate(nextJst.getUTCDate() + 1);
    nextJst.setUTCHours(hours, minutes, 0, 0);

    // UTCに戻す（9時間減算）
    return new Date(nextJst.getTime() - JST_OFFSET);
  }

  if (pattern === 'weekly' && days && days.length > 0) {
    const currentDay = nowJst.getUTCDay();
    let daysToAdd = 7; // デフォルトは1週間後

    // 次の該当曜日を探す
    for (let i = 1; i <= 7; i++) {
      const targetDay = (currentDay + i) % 7;
      if (days.includes(targetDay)) {
        daysToAdd = i;
        break;
      }
    }

    // JSTで該当曜日の日付を取得
    const nextJst = new Date(nowJst);
    nextJst.setUTCDate(nextJst.getUTCDate() + daysToAdd);
    nextJst.setUTCHours(hours, minutes, 0, 0);

    // UTCに戻す
    return new Date(nextJst.getTime() - JST_OFFSET);
  }

  if (pattern === 'monthly' && days && days.length > 0) {
    const targetDay = days[0];

    if (targetDay === -1) {
      // 月末の場合
      const nextJst = new Date(nowJst);
      // 来月の0日 = 今月の最終日
      nextJst.setUTCMonth(nextJst.getUTCMonth() + 1, 0);
      nextJst.setUTCHours(hours, minutes, 0, 0);

      // UTCに戻す
      return new Date(nextJst.getTime() - JST_OFFSET);
    } else {
      // 特定の日付の場合
      const nextJst = new Date(nowJst);
      nextJst.setUTCMonth(nextJst.getUTCMonth() + 1, targetDay);
      nextJst.setUTCHours(hours, minutes, 0, 0);

      // 日付が存在しない場合（例：2月30日）は月末に調整
      if (nextJst.getUTCDate() !== targetDay) {
        nextJst.setUTCMonth(nextJst.getUTCMonth() + 1, 0);
      }

      // UTCに戻す
      return new Date(nextJst.getTime() - JST_OFFSET);
    }
  }

  // デフォルト：翌日
  const nextJst = new Date(nowJst);
  nextJst.setUTCDate(nextJst.getUTCDate() + 1);
  nextJst.setUTCHours(hours, minutes, 0, 0);

  // UTCに戻す
  return new Date(nextJst.getTime() - JST_OFFSET);
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

    const {
      group_id,
      title,
      description,
      category,
      recurrence_pattern,
      recurrence_days,
      generation_time,
      deadline_days_after,
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
        deadline_days_after: deadline_days_after || null,
        next_generation_at: nextGeneration.toISOString(),
        is_active: true,
        created_by: created_by,
        created_at: now,
        updated_at: now
      })
      .select('*, recurring_todo_assignments(user_id)')
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
      recurring_todo: newRecurringTodo  // 全フィールドを返す
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
