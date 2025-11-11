// 権限チェック共通処理

import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'

/**
 * グループメンバーシップチェック
 * 指定されたユーザーがグループのメンバーかどうかを確認
 *
 * @param supabaseClient - Supabaseクライアント
 * @param groupId - グループID
 * @param userId - 確認対象のユーザーID
 * @returns success: メンバーの場合true、error: エラーメッセージ
 */
export async function checkGroupMembership(
  supabaseClient: SupabaseClient,
  groupId: string,
  userId: string
): Promise<{ success: boolean; error?: string }> {
  // group_membersテーブルでメンバーシップを確認
  const { data: memberCheck, error: memberError } = await supabaseClient
    .from('group_members')
    .select('id')
    .eq('group_id', groupId)
    .eq('user_id', userId)
    .single()

  if (memberError || !memberCheck) {
    return {
      success: false,
      error: 'メンバーでないため操作できません'
    }
  }

  return { success: true }
}

/**
 * 担当者メンバーチェック
 * 指定された担当者全員がグループのメンバーかどうかを確認
 *
 * @param supabaseClient - Supabaseクライアント
 * @param groupId - グループID
 * @param assigneeUserIds - 確認対象の担当者ユーザーIDの配列
 * @returns success: 全員メンバーの場合true、error: エラーメッセージ
 */
export async function checkAssigneesAreMembers(
  supabaseClient: SupabaseClient,
  groupId: string,
  assigneeUserIds: string[]
): Promise<{ success: boolean; error?: string }> {
  // 担当者が指定されていない場合はチェック不要
  if (!assigneeUserIds || assigneeUserIds.length === 0) {
    return { success: true }
  }

  // 各担当者がメンバーかチェック
  for (const assignedUserId of assigneeUserIds) {
    const { data: assigneeMember, error: assigneeError } = await supabaseClient
      .from('group_members')
      .select('id')
      .eq('group_id', groupId)
      .eq('user_id', assignedUserId)
      .single()

    if (assigneeError || !assigneeMember) {
      return {
        success: false,
        error: 'メンバー以外を担当者に選択できません'
      }
    }
  }

  return { success: true }
}
