// 定期TODO更新 Edge Function
import { serve } from "https://deno.land/std@0.192.0/http/server.ts"
import { corsHeaders } from '../_shared/cors.ts'
import { checkMaintenanceMode } from '../_shared/maintenance.ts'
import { checkGroupMembership, checkAssigneesAreMembers } from '../_shared/permission.ts'

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

declare var Deno: any;



interface UpdateRecurringTodoRequest {
  recurring_todo_id: string
  user_id: string
  is_active?: boolean
  title?: string
  description?: string
  recurrence_pattern?: 'daily' | 'weekly' | 'monthly'
  recurrence_days?: number[]
  generation_time?: string
  deadline_days_after?: number
  assigned_user_ids?: string[]
}

interface UpdateRecurringTodoResponse {
  success: boolean
  recurring_todo?: {
    id: string
    is_active: boolean
    updated_at: string
  }
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

  // time形式のバリデーション（HH:MM または HH:MM:SS を許可）
  const timeParts = time.split(':');
  if (timeParts.length < 2 || timeParts.length > 3) {
    throw new Error('Invalid time format. Expected HH:MM or HH:MM:SS');
  }
  const [hours, minutes] = timeParts.map(Number);
  if (isNaN(hours) || isNaN(minutes) || hours < 0 || hours > 23 || minutes < 0 || minutes > 59) {
    throw new Error('Invalid time values. Hours must be 0-23, minutes must be 0-59');
  }

  // 現在時刻をJSTに変換（UTC時刻に9時間加算）
  const nowJst = new Date(now.getTime() + JST_OFFSET);

  if (pattern === 'daily') {
    // まず当日の指定時刻を計算
    const todayJst = new Date(nowJst);
    todayJst.setUTCHours(hours, minutes, 0, 0);

    // 現在時刻と比較
    if (nowJst.getTime() < todayJst.getTime()) {
      // 当日の指定時刻がまだ来ていない → 当日
      return new Date(todayJst.getTime() - JST_OFFSET);
    } else {
      // 当日の指定時刻は過ぎた → 翌日
      todayJst.setUTCDate(todayJst.getUTCDate() + 1);
      return new Date(todayJst.getTime() - JST_OFFSET);
    }
  }

  if (pattern === 'weekly' && days && days.length > 0) {
    const currentDay = nowJst.getUTCDay();

    // まず今日が該当曜日かチェック
    if (days.includes(currentDay)) {
      const todayJst = new Date(nowJst);
      todayJst.setUTCHours(hours, minutes, 0, 0);

      if (nowJst.getTime() < todayJst.getTime()) {
        // 今日の指定時刻がまだ来ていない → 今日
        return new Date(todayJst.getTime() - JST_OFFSET);
      }
    }

    // 今日は該当しない、または今日の時刻は過ぎた → 次の該当曜日を探す
    let daysToAdd = 7; // デフォルトは1週間後
    for (let i = 1; i <= 7; i++) {
      const targetDay = (currentDay + i) % 7;
      if (days.includes(targetDay)) {
        daysToAdd = i;
        break;
      }
    }

    const nextJst = new Date(nowJst);
    nextJst.setUTCDate(nextJst.getUTCDate() + daysToAdd);
    nextJst.setUTCHours(hours, minutes, 0, 0);

    // UTCに戻す
    return new Date(nextJst.getTime() - JST_OFFSET);
  }

  if (pattern === 'monthly' && days && days.length > 0) {
    const targetDay = days[0];
    const currentDate = nowJst.getUTCDate();

    if (targetDay === -1) {
      // 月末の場合
      // 今月の最終日を取得
      const lastDayOfMonth = new Date(nowJst.getUTCFullYear(), nowJst.getUTCMonth() + 1, 0).getUTCDate();

      if (currentDate === lastDayOfMonth) {
        // 今日が月末の場合
        const todayJst = new Date(nowJst);
        todayJst.setUTCHours(hours, minutes, 0, 0);

        if (nowJst.getTime() < todayJst.getTime()) {
          // 今日の指定時刻がまだ来ていない → 今月の月末
          return new Date(todayJst.getTime() - JST_OFFSET);
        }
      }

      // 今日は月末ではない、または月末の時刻は過ぎた → 来月の月末
      const nextJst = new Date(nowJst);
      nextJst.setUTCMonth(nextJst.getUTCMonth() + 1, 0);
      nextJst.setUTCHours(hours, minutes, 0, 0);
      return new Date(nextJst.getTime() - JST_OFFSET);
    } else {
      // 特定の日付の場合
      if (currentDate === targetDay) {
        // 今日が該当日の場合
        const todayJst = new Date(nowJst);
        todayJst.setUTCHours(hours, minutes, 0, 0);

        if (nowJst.getTime() < todayJst.getTime()) {
          // 今日の指定時刻がまだ来ていない → 今月
          return new Date(todayJst.getTime() - JST_OFFSET);
        }
      }

      // 今日は該当日ではない、または該当日の時刻は過ぎた → 来月
      const nextJst = new Date(nowJst);
      nextJst.setUTCMonth(nextJst.getUTCMonth() + 1, targetDay);
      nextJst.setUTCHours(hours, minutes, 0, 0);

      // 日付が存在しない場合（例：2月30日）は月末に調整
      if (nextJst.getUTCDate() !== targetDay) {
        nextJst.setUTCMonth(nextJst.getUTCMonth() + 1, 0);
      }

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
    const checkResult = await checkMaintenanceMode(req)
    if (checkResult.status === 'error' || checkResult.status === 'maintenance') {
      return new Response(
        JSON.stringify(checkResult),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const {
      recurring_todo_id,
      user_id,
      is_active,
      title,
      description,
      recurrence_pattern,
      recurrence_days,
      generation_time,
      deadline_days_after,
      assigned_user_ids
    }: UpdateRecurringTodoRequest = await req.json()

    if (!recurring_todo_id || !user_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'recurring_todo_id and user_id are required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 権限チェック
    const { data: recurringTodo } = await supabaseClient
      .from('recurring_todos')
      .select('created_by, group_id')
      .eq('id', recurring_todo_id)
      .single()

    if (!recurringTodo) {
      return new Response(
        JSON.stringify({ success: false, error: 'Recurring TODO not found' }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // メンバーシップチェック
    const membershipCheck = await checkGroupMembership(supabaseClient, recurringTodo.group_id, user_id)
    if (!membershipCheck.success) {
      return new Response(
        JSON.stringify({ success: false, error: membershipCheck.error }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 担当者メンバーチェック（assigned_user_idsが指定されている場合）
    if (assigned_user_ids && assigned_user_ids.length > 0) {
      const assigneeCheck = await checkAssigneesAreMembers(supabaseClient, recurringTodo.group_id, assigned_user_ids)
      if (!assigneeCheck.success) {
        return new Response(
          JSON.stringify({ success: false, error: assigneeCheck.error }),
          {
            status: 200,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        )
      }
    }

    const { data: group } = await supabaseClient
      .from('groups')
      .select('owner_id')
      .eq('id', recurringTodo.group_id)
      .single()

    const isCreator = recurringTodo.created_by === user_id
    const isOwner = group?.owner_id === user_id

    if (!isCreator && !isOwner) {
      return new Response(
        JSON.stringify({ success: false, error: 'Only creator or group owner can update recurring TODO' }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 更新データ準備
    const updateData: any = { updated_at: new Date().toISOString() }
    if (is_active !== undefined) updateData.is_active = is_active
    if (title !== undefined) updateData.title = title
    if (description !== undefined) updateData.description = description
    if (recurrence_pattern !== undefined) updateData.recurrence_pattern = recurrence_pattern
    if (recurrence_days !== undefined) updateData.recurrence_days = recurrence_days
    if (generation_time !== undefined) updateData.generation_time = generation_time
    if (deadline_days_after !== undefined) updateData.deadline_days_after = deadline_days_after

    // generation_time, recurrence_pattern, recurrence_daysのいずれかが更新された場合、next_generation_atを再計算
    if (generation_time !== undefined || recurrence_pattern !== undefined || recurrence_days !== undefined) {
      // 既存データを取得
      const { data: existingData } = await supabaseClient
        .from('recurring_todos')
        .select('recurrence_pattern, recurrence_days, generation_time')
        .eq('id', recurring_todo_id)
        .single()

      if (existingData) {
        // 更新後の値を使用（未指定の場合は既存値を使用）
        const finalPattern = recurrence_pattern ?? existingData.recurrence_pattern
        const finalDays = recurrence_days ?? existingData.recurrence_days
        const finalTime = generation_time ?? existingData.generation_time

        // next_generation_atを再計算
        const nextGeneration = calculateNextGeneration(finalPattern, finalDays, finalTime)
        updateData.next_generation_at = nextGeneration.toISOString()
      }
    }

    const { data: updated, error: updateError } = await supabaseClient
      .from('recurring_todos')
      .update(updateData)
      .eq('id', recurring_todo_id)
      .select('*, recurring_todo_assignments(user_id)')
      .single()

    if (updateError || !updated) {
      return new Response(
        JSON.stringify({ success: false, error: `Failed to update: ${updateError?.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 担当者更新
    if (assigned_user_ids && assigned_user_ids.length > 0) {
      await supabaseClient
        .from('recurring_todo_assignments')
        .delete()
        .eq('recurring_todo_id', recurring_todo_id)

      const now = new Date().toISOString()
      const assignmentInserts = assigned_user_ids.map(uid => ({
        recurring_todo_id: recurring_todo_id,
        user_id: uid,
        assigned_at: now
      }))

      await supabaseClient
        .from('recurring_todo_assignments')
        .insert(assignmentInserts)
    }

    const response: UpdateRecurringTodoResponse = {
      success: true,
      recurring_todo: {
        ...updated,
        assigned_user_ids: (updated.recurring_todo_assignments || []).map((a: any) => a.user_id)
      }
    }

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Update recurring todo error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
