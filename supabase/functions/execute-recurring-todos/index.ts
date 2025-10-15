// 定期TODO自動生成 Edge Function (Cron実行用)
// 1分おきにrecurring_todosテーブルを監視し、該当時刻に達したらTODOを自動生成
import { serve } from "https://deno.land/std@0.192.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

declare var Deno: any;

interface RecurringTodo {
  id: string
  group_id: string
  title: string
  description: string | null
  category: string
  recurrence_pattern: 'daily' | 'weekly' | 'monthly'
  recurrence_days: number[] | null
  generation_time: string
  next_generation_at: string
  created_by: string
  recurring_todo_assignments: Array<{ user_id: string }>
}

interface ProcessResult {
  success: boolean
  processed: number
  errors: number
  details?: string[]
}

serve(async (_req) => {
  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // 1. 現在時刻取得（UTC）
    const now = new Date()
    console.log(`[execute-recurring-todos] Starting at ${now.toISOString()}`)

    // 2. 該当するrecurring_todosを取得
    const { data: recurringTodos, error: fetchError } = await supabaseClient
      .from('recurring_todos')
      .select('*, recurring_todo_assignments(*)')
      .eq('is_active', true)
      .lte('next_generation_at', now.toISOString())

    if (fetchError) {
      console.error('[execute-recurring-todos] Fetch error:', fetchError.message)
      throw fetchError
    }

    if (!recurringTodos || recurringTodos.length === 0) {
      console.log('[execute-recurring-todos] No recurring todos to process')
      return new Response(
        JSON.stringify({ success: true, processed: 0, errors: 0 }),
        { headers: { 'Content-Type': 'application/json' } }
      )
    }

    console.log(`[execute-recurring-todos] Found ${recurringTodos.length} recurring todos to process`)

    let processed = 0
    let errors = 0
    const errorDetails: string[] = []

    // 3. 各recurring_todoに対してTODO作成
    for (const recurringTodo of recurringTodos as RecurringTodo[]) {
      try {
        // 3-1. TODOを作成
        const { data: newTodo, error: createTodoError } = await supabaseClient
          .from('todos')
          .insert({
            group_id: recurringTodo.group_id,
            title: recurringTodo.title,
            description: recurringTodo.description,
            category: recurringTodo.category,
            created_by: recurringTodo.created_by,
            // deadline: 必要に応じて設定（今は設定しない）
          })
          .select()
          .single()

        if (createTodoError) {
          console.error(`[execute-recurring-todos] TODO creation error for ${recurringTodo.id}:`, createTodoError.message)

          // エラーログ記録
          await supabaseClient.from('error_logs').insert({
            user_id: null,
            error_type: 'recurring_todo_generation_error',
            error_message: `TODO creation failed: ${createTodoError.message}`,
            screen_name: 'Cron Job: execute-recurring-todos',
            stack_trace: JSON.stringify({ recurring_todo_id: recurringTodo.id })
          })

          errors++
          errorDetails.push(`Failed to create TODO for ${recurringTodo.id}`)
          continue
        }

        // 3-2. 担当者を割り当て
        if (recurringTodo.recurring_todo_assignments && recurringTodo.recurring_todo_assignments.length > 0) {
          const assignments = recurringTodo.recurring_todo_assignments.map(a => ({
            todo_id: newTodo.id,
            user_id: a.user_id
          }))

          const { error: assignmentError } = await supabaseClient
            .from('todo_assignments')
            .insert(assignments)

          if (assignmentError) {
            console.error(`[execute-recurring-todos] Assignment error for ${recurringTodo.id}:`, assignmentError.message)
            // 担当者割り当て失敗してもTODOは作成できたので継続
          }
        }

        // 3-3. next_generation_atを次回に更新
        const nextGeneration = calculateNextGeneration(
          recurringTodo.recurrence_pattern,
          recurringTodo.recurrence_days,
          recurringTodo.generation_time,
          now
        )

        const { error: updateError } = await supabaseClient
          .from('recurring_todos')
          .update({ next_generation_at: nextGeneration.toISOString() })
          .eq('id', recurringTodo.id)

        if (updateError) {
          console.error(`[execute-recurring-todos] Update error for ${recurringTodo.id}:`, updateError.message)
          errors++
          errorDetails.push(`Failed to update next_generation_at for ${recurringTodo.id}`)
          continue
        }

        processed++
        console.log(`[execute-recurring-todos] Successfully processed ${recurringTodo.id}`)

      } catch (error) {
        console.error(`[execute-recurring-todos] Unexpected error for ${recurringTodo.id}:`, error)
        errors++
        errorDetails.push(`Unexpected error for ${recurringTodo.id}: ${error.message}`)
      }
    }

    const result: ProcessResult = {
      success: true,
      processed,
      errors,
      details: errorDetails.length > 0 ? errorDetails : undefined
    }

    console.log(`[execute-recurring-todos] Completed: ${processed} processed, ${errors} errors`)

    return new Response(
      JSON.stringify(result),
      { headers: { 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('[execute-recurring-todos] Fatal error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})

/**
 * 次回生成日時を計算
 * @param pattern 繰り返しパターン（daily, weekly, monthly）
 * @param days 繰り返し曜日または日付
 * @param time 生成時刻（HH:mm:ss）
 * @param current 現在日時
 * @returns 次回生成日時
 */
function calculateNextGeneration(
  pattern: 'daily' | 'weekly' | 'monthly',
  days: number[] | null,
  time: string,
  current: Date
): Date {
  const [hours, minutes, seconds] = time.split(':').map(Number)
  const next = new Date(current)

  switch (pattern) {
    case 'daily':
      // 毎日：翌日の指定時刻
      next.setDate(next.getDate() + 1)
      next.setHours(hours, minutes, seconds, 0)
      break

    case 'weekly':
      // 毎週：次の該当曜日の指定時刻
      if (!days || days.length === 0) {
        throw new Error('Weekly pattern requires recurrence_days')
      }

      // 現在の曜日（0=日曜, 6=土曜）
      const currentDay = next.getDay()

      // 次の該当曜日を探す
      let daysToAdd = 7 // デフォルトは1週間後
      for (let i = 1; i <= 7; i++) {
        const targetDay = (currentDay + i) % 7
        if (days.includes(targetDay)) {
          daysToAdd = i
          break
        }
      }

      next.setDate(next.getDate() + daysToAdd)
      next.setHours(hours, minutes, seconds, 0)
      break

    case 'monthly':
      // 毎月：次の該当日の指定時刻
      if (!days || days.length === 0) {
        throw new Error('Monthly pattern requires recurrence_days')
      }

      const targetDate = days[0] // 最初の指定日を使用

      if (targetDate === -1) {
        // 月末の場合
        next.setMonth(next.getMonth() + 1, 0) // 翌月の0日 = 当月の最終日
        next.setHours(hours, minutes, seconds, 0)
      } else {
        // 特定の日付の場合
        next.setMonth(next.getMonth() + 1, targetDate)
        next.setHours(hours, minutes, seconds, 0)

        // 日付が存在しない場合（例：2月30日）は月末に調整
        if (next.getDate() !== targetDate) {
          next.setDate(0) // 前月の最終日
        }
      }
      break

    default:
      throw new Error(`Unknown recurrence pattern: ${pattern}`)
  }

  return next
}
