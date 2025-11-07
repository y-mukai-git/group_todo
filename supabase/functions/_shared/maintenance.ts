/**
 * メンテナンスモードチェック
 * 全Edge Functionで共通使用
 */

interface MaintenanceCheckResult {
  status: 'active' | 'maintenance' | 'error'
  message?: string
}

/**
 * メンテナンスモードをチェック
 * @returns メンテナンスモードの状態
 */
export async function checkMaintenanceMode(): Promise<MaintenanceCheckResult> {
  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
  const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? ''

  const checkResponse = await fetch(`${supabaseUrl}/functions/v1/check-maintenance-mode`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${supabaseAnonKey}`,
    },
  })

  return await checkResponse.json()
}
