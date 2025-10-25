// グループ作成 Edge Function
import { serve } from "https://deno.land/std@0.192.0/http/server.ts"

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

declare var Deno: any;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface CreateGroupRequest {
  user_id: string
  name: string
  description?: string
  category?: string
  image_data?: string // base64エンコードされた画像データ（オプション）
}

interface CreateGroupResponse {
  success: boolean
  group?: {
    id: string
    name: string
    description: string | null
    category: string | null
    icon_url: string | null
    signed_icon_url: string | null
    owner_id: string
    created_at: string
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

    const { user_id, name, description, category, image_data }: CreateGroupRequest = await req.json()

    if (!user_id || !name) {
      return new Response(
        JSON.stringify({ success: false, error: 'user_id and name are required' }),
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

        // グループID生成（アップロード前に必要）
        const tempGroupId = crypto.randomUUID()

        // Storageにアップロード
        const filePath = `${tempGroupId}/icon.${fileExtension}`
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

    const now = new Date().toISOString()

    // グループ作成
    const { data: newGroup, error: groupError } = await supabaseClient
      .from('groups')
      .insert({
        name: name,
        description: description || null,
        category: category || null,
        icon_url: uploadedIconUrl,
        owner_id: user_id,
        created_at: now,
        updated_at: now
      })
      .select('id, name, description, category, icon_url, owner_id, created_at')
      .single()

    if (groupError || !newGroup) {
      return new Response(
        JSON.stringify({ success: false, error: `Group creation failed: ${groupError?.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // ユーザーの最大display_orderを取得
    const { data: maxOrderData } = await supabaseClient
      .from('group_members')
      .select('display_order')
      .eq('user_id', user_id)
      .order('display_order', { ascending: false })
      .limit(1)
      .maybeSingle()

    const displayOrder = (maxOrderData?.display_order || 0) + 1

    // グループメンバーにオーナーを追加
    const { error: memberError } = await supabaseClient
      .from('group_members')
      .insert({
        group_id: newGroup.id,
        user_id: user_id,
        role: 'owner',
        joined_at: now,
        display_order: displayOrder
      })

    if (memberError) {
      // グループ作成は成功したが、メンバー追加に失敗した場合はロールバック
      await supabaseClient
        .from('groups')
        .delete()
        .eq('id', newGroup.id)

      return new Response(
        JSON.stringify({ success: false, error: `Member addition failed: ${memberError.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 署名付きURL生成（icon_urlが存在する場合）
    let signedIconUrl: string | null = null
    if (newGroup.icon_url) {
      try {
        const { data: signedUrlData, error: signedUrlError } = await supabaseClient
          .storage
          .from('group-icons')
          .createSignedUrl(newGroup.icon_url, 3600) // 有効期限1時間

        if (!signedUrlError && signedUrlData?.signedUrl) {
          signedIconUrl = signedUrlData.signedUrl
        }
      } catch (error) {
        console.error('Failed to create signed URL:', error)
        // 署名付きURL生成失敗時もエラーにせず、nullのまま返す
      }
    }

    const response: CreateGroupResponse = {
      success: true,
      group: {
        id: newGroup.id,
        name: newGroup.name,
        description: newGroup.description,
        category: newGroup.category,
        icon_url: newGroup.icon_url,
        signed_icon_url: signedIconUrl,
        owner_id: newGroup.owner_id,
        created_at: newGroup.created_at
      }
    }

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Create group error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
