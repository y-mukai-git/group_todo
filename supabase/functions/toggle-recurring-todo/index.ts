// 定期TODO有効/無効切り替え Edge Function
import { serve } from "https://deno.land/std@0.192.0/http/server.ts"
import { corsHeaders } from '../_shared/cors.ts'
import { checkMaintenanceMode } from '../_shared/maintenance.ts'
import { checkGroupMembership } from '../_shared/permission.ts'

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

declare var Deno: any;



interface ToggleRecurringTodoRequest {
  recurring_todo_id: string
  user_id: string // 権限チェック用
}

interface ToggleRecurringTodoResponse {
  success: boolean
  recurring_todo?: {
    id: string
    is_active: boolean
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

    const { recurring_todo_id, user_id }: ToggleRecurringTodoRequest = await req.json()

    if (!recurring_todo_id || !user_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'recurring_todo_id and user_id are required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 1. 定期TODOとグループ情報を取得（JOINで1回のクエリに最適化）
    const { data: recurringTodo, error: fetchError } = await supabaseClient
      .from('recurring_todos')
      .select('id, is_active, created_by, group_id, recurrence_pattern, recurrence_days, generation_time, groups(owner_id)')
      .eq('id', recurring_todo_id)
      .single()

    if (fetchError || !recurringTodo) {
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

    // 2. 権限チェック：作成者またはグループオーナーのみ切り替え可能
    const group = recurringTodo.groups as any
    if (!group) {
      return new Response(
        JSON.stringify({ success: false, error: 'Group not found' }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const isCreator = recurringTodo.created_by === user_id
    const isOwner = group.owner_id === user_id

    if (!isCreator && !isOwner) {
      return new Response(
        JSON.stringify({ success: false, error: 'Permission denied: Only creator or group owner can toggle' }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 3. is_activeを切り替え
    const newIsActive = !recurringTodo.is_active

    // 更新データ準備
    const updateData: any = { is_active: newIsActive }

    // 有効化時は next_generation_at を再計算
    if (newIsActive === true) {
      const nextGeneration = calculateNextGeneration(
        recurringTodo.recurrence_pattern,
        recurringTodo.recurrence_days,
        recurringTodo.generation_time
      )
      updateData.next_generation_at = nextGeneration.toISOString()
    }

    const { data: updatedTodo, error: updateError } = await supabaseClient
      .from('recurring_todos')
      .update(updateData)
      .eq('id', recurring_todo_id)
      .select('*, recurring_todo_assignments(user_id)')
      .single()

    if (updateError || !updatedTodo) {
      return new Response(
        JSON.stringify({ success: false, error: `Toggle failed: ${updateError?.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const response: ToggleRecurringTodoResponse = {
      success: true,
      recurring_todo: {
        ...updatedTodo,
        assigned_user_ids: (updatedTodo.recurring_todo_assignments || []).map((a: any) => a.user_id)
      }
    }

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Toggle recurring todo error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
