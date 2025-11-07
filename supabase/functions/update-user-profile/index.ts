// ユーザープロフィール更新 Edge Function
import { serve } from "https://deno.land/std@0.192.0/http/server.ts"
import { corsHeaders } from '../_shared/cors.ts'
import { checkMaintenanceMode } from '../_shared/maintenance.ts'

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

declare var Deno: any;



interface UpdateUserProfileRequest {
  user_id: string
  display_name?: string
  avatar_url?: string
  image_data?: string // base64エンコードされた画像データ（オプション）
  notification_deadline?: boolean
  notification_new_todo?: boolean
  notification_assigned?: boolean
}

interface UpdateUserProfileResponse {
  success: boolean
  user?: {
    id: string
    device_id: string
    display_name: string
    display_id: string
    avatar_url: string | null
    signed_avatar_url: string | null // 署名付きURL（有効期限1時間）
    notification_deadline: boolean
    notification_new_todo: boolean
    notification_assigned: boolean
    created_at: string
    updated_at: string
  }
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
    const checkResult = await checkMaintenanceMode()
    if (checkResult.status === 'error' || checkResult.status === 'maintenance') {
      return new Response(
        JSON.stringify(checkResult),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const {
      user_id,
      display_name,
      avatar_url,
      image_data,
      notification_deadline,
      notification_new_todo,
      notification_assigned
    }: UpdateUserProfileRequest = await req.json()

    if (!user_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'user_id is required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 画像アップロード処理（image_dataがある場合）
    let uploadedAvatarUrl: string | null = null
    if (image_data) {
      try {
        // base64デコード
        const base64Data = image_data.replace(/^data:image\/\w+;base64,/, '')
        const imageBuffer = Uint8Array.from(atob(base64Data), c => c.charCodeAt(0))

        // 画像形式判定（JPEG or PNG）
        let fileExtension = 'jpg'
        let contentType = 'image/jpeg' // 正しいMIMEタイプ
        if (image_data.startsWith('data:image/png')) {
          fileExtension = 'png'
          contentType = 'image/png'
        }

        // Storageにアップロード
        const filePath = `${user_id}/avatar.${fileExtension}`
        const { error: uploadError } = await supabaseClient
          .storage
          .from('user-avatars')
          .upload(filePath, imageBuffer, {
            contentType: contentType,
            upsert: true // 既存ファイルがあれば上書き
          })

        if (uploadError) {
          console.error('Image upload error:', uploadError)
          return new Response(
            JSON.stringify({ success: false, error: `Failed to upload image: ${uploadError.message}` }),
            {
              status: 500,
              headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            }
          )
        }

        uploadedAvatarUrl = filePath
      } catch (error) {
        console.error('Image processing error:', error)
        return new Response(
          JSON.stringify({ success: false, error: `Failed to process image: ${error.message}` }),
          {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        )
      }
    }

    // 更新データ準備
    const updateData: any = { updated_at: new Date().toISOString() }
    if (display_name !== undefined) updateData.display_name = display_name
    if (avatar_url !== undefined) updateData.avatar_url = avatar_url
    if (uploadedAvatarUrl !== null) updateData.avatar_url = uploadedAvatarUrl // 画像アップロード時はこちらを優先
    if (notification_deadline !== undefined) updateData.notification_deadline = notification_deadline
    if (notification_new_todo !== undefined) updateData.notification_new_todo = notification_new_todo
    if (notification_assigned !== undefined) updateData.notification_assigned = notification_assigned

    // ユーザー更新
    const { data: updatedUser, error: updateError } = await supabaseClient
      .from('users')
      .update(updateData)
      .eq('id', user_id)
      .select('id, device_id, display_name, display_id, avatar_url, notification_deadline, notification_new_todo, notification_assigned, created_at, updated_at')
      .single()

    if (updateError || !updatedUser) {
      return new Response(
        JSON.stringify({ success: false, error: `Failed to update user: ${updateError?.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 署名付きURL生成（avatar_urlが存在する場合）
    let signedAvatarUrl: string | null = null
    if (updatedUser.avatar_url) {
      const { data: signedUrlData, error: signedUrlError } = await supabaseClient
        .storage
        .from('user-avatars')
        .createSignedUrl(updatedUser.avatar_url, 3600) // 有効期限1時間

      if (signedUrlError) {
        throw new Error(`Failed to create signed URL: ${signedUrlError.message}`)
      }

      signedAvatarUrl = signedUrlData.signedUrl
    }

    const response: UpdateUserProfileResponse = {
      success: true,
      user: {
        id: updatedUser.id,
        device_id: updatedUser.device_id,
        display_name: updatedUser.display_name,
        display_id: updatedUser.display_id,
        avatar_url: updatedUser.avatar_url,
        signed_avatar_url: signedAvatarUrl,
        notification_deadline: updatedUser.notification_deadline,
        notification_new_todo: updatedUser.notification_new_todo,
        notification_assigned: updatedUser.notification_assigned,
        created_at: updatedUser.created_at,
        updated_at: updatedUser.updated_at
      }
    }

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Update user profile error:', error)
    return new Response(
      JSON.stringify({ success: false, error: (error as Error).message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
