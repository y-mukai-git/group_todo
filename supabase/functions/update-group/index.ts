// グループ更新 Edge Function
import { serve } from "https://deno.land/std@0.192.0/http/server.ts"

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

declare var Deno: any;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface UpdateGroupRequest {
  group_id: string
  user_id: string // オーナーチェック用
  name?: string
  description?: string
  image_data?: string // base64エンコードされた画像データ（オプション）
  category?: string
}

interface UpdateGroupResponse {
  success: boolean
  group?: {
    id: string
    name: string
    description: string | null
    icon_url: string | null
    signed_icon_url: string | null
    owner_id: string
    category: string | null
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

    const { group_id, user_id, name, description, image_data, category }: UpdateGroupRequest = await req.json()

    if (!group_id || !user_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'group_id and user_id are required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 画像アップロード処理（image_dataがある場合）
    let uploadedIconUrl: string | null = null
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
        const filePath = `${group_id}/icon.${fileExtension}`
        const { error: uploadError } = await supabaseClient
          .storage
          .from('group-icons')
          .upload(filePath, imageBuffer, {
            contentType: contentType,
            upsert: true
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

        uploadedIconUrl = filePath
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

    // オーナーチェック
    const { data: group, error: groupError } = await supabaseClient
      .from('groups')
      .select('owner_id')
      .eq('id', group_id)
      .single()

    if (groupError || !group) {
      return new Response(
        JSON.stringify({ success: false, error: 'Group not found' }),
        {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    if (group.owner_id !== user_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'Only group owner can update group' }),
        {
          status: 403,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 更新データ準備
    const updateData: any = { updated_at: new Date().toISOString() }
    if (name !== undefined) updateData.name = name
    if (description !== undefined) updateData.description = description
    if (uploadedIconUrl !== null) updateData.icon_url = uploadedIconUrl
    if (category !== undefined) updateData.category = category

    // グループ更新
    const { data: updatedGroup, error: updateError } = await supabaseClient
      .from('groups')
      .update(updateData)
      .eq('id', group_id)
      .select('id, name, description, icon_url, owner_id, category')
      .single()

    if (updateError || !updatedGroup) {
      return new Response(
        JSON.stringify({ success: false, error: `Failed to update group: ${updateError?.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 署名付きURL生成（icon_urlが存在する場合）
    let signedIconUrl: string | null = null
    if (updatedGroup.icon_url) {
      try {
        const { data: signedUrlData, error: signedUrlError } = await supabaseClient
          .storage
          .from('group-icons')
          .createSignedUrl(updatedGroup.icon_url, 3600) // 有効期限1時間

        if (!signedUrlError && signedUrlData?.signedUrl) {
          signedIconUrl = signedUrlData.signedUrl
        }
      } catch (error) {
        console.error('Failed to create signed URL:', error)
        // 署名付きURL生成失敗時もエラーにせず、nullのまま返す
      }
    }

    const response: UpdateGroupResponse = {
      success: true,
      group: {
        id: updatedGroup.id,
        name: updatedGroup.name,
        description: updatedGroup.description,
        icon_url: updatedGroup.icon_url,
        signed_icon_url: signedIconUrl,
        owner_id: updatedGroup.owner_id,
        category: updatedGroup.category
      }
    }

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Update group error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
