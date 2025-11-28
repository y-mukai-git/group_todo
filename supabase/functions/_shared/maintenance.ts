/**
 * メンテナンスモードチェック
 * 全Edge Functionで共通使用
 */

declare var Deno: any;

interface MaintenanceCheckResult {
  status: 'active' | 'maintenance' | 'error'
  message?: string
  end_time?: string
}

/**
 * メンテナンスモードをチェック
 * @param req リクエストオブジェクト（ヘッダーから管理者スキップフラグを取得）
 * @returns メンテナンスモードの状態
 */
export async function checkMaintenanceMode(req: Request): Promise<MaintenanceCheckResult> {
  // 管理者スキップヘッダーがある場合はメンテナンスチェックをスキップ
  const skipMaintenance = req.headers.get('x-admin-skip-maintenance')
  if (skipMaintenance === 'true') {
    return { status: 'active' }
  }

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
