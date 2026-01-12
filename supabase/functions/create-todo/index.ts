// TODO作成 Edge Function
import { serve } from "https://deno.land/std@0.192.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'
import { checkMaintenanceMode } from '../_shared/maintenance.ts'
import { checkGroupMembership, checkAssigneesAreMembers } from '../_shared/permission.ts'

declare var Deno: any;

// 新規グループ作成用の情報
interface NewGroupInfo {
  name: string
  description?: string
  category?: string
  image_data?: string // base64エンコードされた画像データ
}

interface CreateTodoRequest {
  group_id?: string // 既存グループ指定時
  new_group?: NewGroupInfo // 新規グループ作成時
  title: string
  description?: string
  deadline?: string
  assigned_user_ids: string[]
  created_by: string
}

interface CreateTodoResponse {
  success: boolean
  todo?: {
    id: string
    group_id: string
    title: string
    description: string | null
    deadline: string | null
    is_completed: boolean
    created_by: string
    created_at: string
    assigned_users: string[]
  }
  created_group?: {
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
    const checkResult = await checkMaintenanceMode(req)
    if (checkResult.status === 'error' || checkResult.status === 'maintenance') {
      return new Response(
        JSON.stringify(checkResult),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const { group_id, new_group, title, description, deadline, assigned_user_ids, created_by }: CreateTodoRequest = await req.json()

    // バリデーション: group_id か new_group のどちらか必須
    if (!group_id && !new_group) {
      return new Response(
        JSON.stringify({ success: false, error: 'group_id or new_group is required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    if (!title || !created_by) {
      return new Response(
        JSON.stringify({ success: false, error: 'title and created_by are required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // assigned_user_idsが未定義の場合は空配列に（指定なし = 全員に見える）
    const effectiveAssignedUserIds = assigned_user_ids || []

    if (new_group && !new_group.name) {
      return new Response(
        JSON.stringify({ success: false, error: 'new_group.name is required when creating new group' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const now = new Date().toISOString()

    // ロールバック用の変数
    let createdGroupId: string | null = null
    let createdTodoId: string | null = null
    let uploadedIconPath: string | null = null
    let createdGroupData: any = null

    // 使用するグループID
    let targetGroupId: string

    try {
      // ========================================
      // 1. 新規グループ作成（new_groupがある場合）
      // ========================================
      if (new_group) {
        // 画像アップロード処理（image_dataがある場合）
        if (new_group.image_data) {
          try {
            const base64Data = new_group.image_data.replace(/^data:image\/\w+;base64,/, '')
            const imageBuffer = Uint8Array.from(atob(base64Data), c => c.charCodeAt(0))

            let fileExtension = 'jpg'
            let contentType = 'image/jpeg'
            if (new_group.image_data.startsWith('data:image/png')) {
              fileExtension = 'png'
              contentType = 'image/png'
            }

            const tempGroupId = crypto.randomUUID()
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

            uploadedIconPath = filePath
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

        // グループ作成
        const { data: newGroup, error: groupError } = await supabaseClient
          .from('groups')
          .insert({
            name: new_group.name,
            description: new_group.description || null,
            category: new_group.category || null,
            icon_url: uploadedIconPath,
            owner_id: created_by,
            created_at: now,
            updated_at: now
          })
          .select('id, name, description, category, icon_url, owner_id, created_at')
          .single()

        if (groupError || !newGroup) {
          // アップロードした画像を削除
          if (uploadedIconPath) {
            await supabaseClient.storage.from('group-icons').remove([uploadedIconPath])
          }
          return new Response(
            JSON.stringify({ success: false, error: `Group creation failed: ${groupError?.message}` }),
            {
              status: 500,
              headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            }
          )
        }

        createdGroupId = newGroup.id
        createdGroupData = newGroup
        targetGroupId = newGroup.id

        // ユーザーの最大display_orderを取得
        const { data: maxOrderData } = await supabaseClient
          .from('group_members')
          .select('display_order')
          .eq('user_id', created_by)
          .order('display_order', { ascending: false })
          .limit(1)
          .maybeSingle()

        const displayOrder = (maxOrderData?.display_order || 0) + 1

        // グループメンバーにオーナーを追加
        const { error: memberError } = await supabaseClient
          .from('group_members')
          .insert({
            group_id: newGroup.id,
            user_id: created_by,
            role: 'owner',
            joined_at: now,
            display_order: displayOrder
          })

        if (memberError) {
          // ロールバック: グループ削除、画像削除
          await supabaseClient.from('groups').delete().eq('id', newGroup.id)
          if (uploadedIconPath) {
            await supabaseClient.storage.from('group-icons').remove([uploadedIconPath])
          }
          return new Response(
            JSON.stringify({ success: false, error: `Member addition failed: ${memberError.message}` }),
            {
              status: 500,
              headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            }
          )
        }
      } else {
        // 既存グループを使用
        targetGroupId = group_id!

        // メンバーシップチェック
        const membershipCheck = await checkGroupMembership(supabaseClient, targetGroupId, created_by)
        if (!membershipCheck.success) {
          return new Response(
            JSON.stringify({ success: false, error: membershipCheck.error }),
            {
              status: 200,
              headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            }
          )
        }
      }

      // ========================================
      // 2. 担当者メンバーチェック（担当者指定がある場合のみ）
      // ========================================
      if (effectiveAssignedUserIds.length > 0) {
        const assigneeCheck = await checkAssigneesAreMembers(supabaseClient, targetGroupId, effectiveAssignedUserIds)
        if (!assigneeCheck.success) {
          // ロールバック: 新規グループ作成していた場合は削除
          if (createdGroupId) {
            await supabaseClient.from('group_members').delete().eq('group_id', createdGroupId)
            await supabaseClient.from('groups').delete().eq('id', createdGroupId)
            if (uploadedIconPath) {
              await supabaseClient.storage.from('group-icons').remove([uploadedIconPath])
            }
          }
          return new Response(
            JSON.stringify({ success: false, error: assigneeCheck.error }),
            {
              status: 200,
              headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            }
          )
        }
      }

      // ========================================
      // 3. TODO作成
      // ========================================
      const { data: newTodo, error: todoError } = await supabaseClient
        .from('todos')
        .insert({
          group_id: targetGroupId,
          title: title,
          description: description || null,
          deadline: deadline || null,
          is_completed: false,
          created_by: created_by,
          created_at: now,
          updated_at: now
        })
        .select('id, group_id, title, description, deadline, is_completed, created_by, created_at')
        .single()

      if (todoError || !newTodo) {
        // ロールバック: 新規グループ作成していた場合は削除
        if (createdGroupId) {
          await supabaseClient.from('group_members').delete().eq('group_id', createdGroupId)
          await supabaseClient.from('groups').delete().eq('id', createdGroupId)
          if (uploadedIconPath) {
            await supabaseClient.storage.from('group-icons').remove([uploadedIconPath])
          }
        }
        return new Response(
          JSON.stringify({ success: false, error: `TODO creation failed: ${todoError?.message}` }),
          {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        )
      }

      createdTodoId = newTodo.id

      // ========================================
      // 4. 担当者を追加（担当者指定がある場合のみ）
      // ========================================
      if (effectiveAssignedUserIds.length > 0) {
        const assignmentInserts = effectiveAssignedUserIds.map(user_id => ({
          todo_id: newTodo.id,
          user_id: user_id,
          assigned_at: now
        }))

        const { error: assignmentError } = await supabaseClient
          .from('todo_assignments')
          .insert(assignmentInserts)

        if (assignmentError) {
          // ロールバック: TODO削除、新規グループ作成していた場合はグループも削除
          await supabaseClient.from('todos').delete().eq('id', newTodo.id)
          if (createdGroupId) {
            await supabaseClient.from('group_members').delete().eq('group_id', createdGroupId)
            await supabaseClient.from('groups').delete().eq('id', createdGroupId)
            if (uploadedIconPath) {
              await supabaseClient.storage.from('group-icons').remove([uploadedIconPath])
            }
          }
          return new Response(
            JSON.stringify({ success: false, error: `Assignment creation failed: ${assignmentError.message}` }),
            {
              status: 500,
              headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            }
          )
        }
      }

      // ========================================
      // 5. 成功レスポンス作成
      // ========================================
      // 新規グループの署名付きURL生成
      let signedIconUrl: string | null = null
      if (createdGroupData?.icon_url) {
        const { data: signedUrlData } = await supabaseClient
          .storage
          .from('group-icons')
          .createSignedUrl(createdGroupData.icon_url, 3600)
        signedIconUrl = signedUrlData?.signedUrl || null
      }

      const response: CreateTodoResponse = {
        success: true,
        todo: {
          id: newTodo.id,
          group_id: newTodo.group_id,
          title: newTodo.title,
          description: newTodo.description,
          deadline: newTodo.deadline,
          is_completed: newTodo.is_completed,
          created_by: newTodo.created_by,
          created_at: newTodo.created_at,
          assigned_users: effectiveAssignedUserIds
        },
        created_group: createdGroupData ? {
          id: createdGroupData.id,
          name: createdGroupData.name,
          description: createdGroupData.description,
          category: createdGroupData.category,
          icon_url: createdGroupData.icon_url,
          signed_icon_url: signedIconUrl,
          owner_id: createdGroupData.owner_id,
          created_at: createdGroupData.created_at
        } : undefined
      }

      return new Response(
        JSON.stringify(response),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )

    } catch (innerError) {
      // 内部try-catchでの予期せぬエラー: ロールバック
      console.error('Unexpected error during creation:', innerError)
      if (createdTodoId) {
        await supabaseClient.from('todo_assignments').delete().eq('todo_id', createdTodoId)
        await supabaseClient.from('todos').delete().eq('id', createdTodoId)
      }
      if (createdGroupId) {
        await supabaseClient.from('group_members').delete().eq('group_id', createdGroupId)
        await supabaseClient.from('groups').delete().eq('id', createdGroupId)
        if (uploadedIconPath) {
          await supabaseClient.storage.from('group-icons').remove([uploadedIconPath])
        }
      }
      throw innerError
    }

  } catch (error) {
    console.error('Create todo error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
