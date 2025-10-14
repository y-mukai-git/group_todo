# Supabase Storage セットアップガイド

## 概要

このガイドでは、ユーザーアバター画像を保存するための Supabase Storage（Private Bucket）のセットアップ手順を説明します。

---

## 🎯 設計方針

### セキュリティ設計

**Private Bucket + Edge Function 経由アクセス**

- **Storage**: Private Bucket（非公開）
- **アクセス方法**: Edge Function 経由のみ
- **認証**: デバイスベース認証（既存のアプリ設計と統一）
- **画像URL**: 署名付きURL（有効期限付き）

### メリット

1. **セキュリティ確保**
   - Storage 自体は非公開
   - Edge Function で認証・認可チェック
   - ユーザー本人のみアクセス可能

2. **アクセス制御の柔軟性**
   - Edge Function でユーザー権限チェック
   - 不正アクセスを防止

3. **デバイスベース認証との整合性**
   - 既存のアプリ設計（デバイスベース認証）と統一

---

## 📋 セットアップ手順

### Step 1: Supabase コンソールにログイン

1. [Supabase Dashboard](https://supabase.com/dashboard) にアクセス
2. 対象プロジェクトを選択（dev / stg / prod）

---

### Step 2: Storage Bucket 作成

1. 左サイドバーから **Storage** を選択
2. **Create a new bucket** をクリック
3. 以下の設定で作成：

| 設定項目 | 設定値 | 説明 |
|---------|--------|------|
| **Bucket name** | `user-avatars` | バケット名（固定） |
| **Public bucket** | **オフ** | Private Bucket（非公開） |
| **File size limit** | `5 MB`（推奨） | アップロード可能な最大ファイルサイズ |
| **Allowed MIME types** | `image/jpeg, image/png`（推奨） | 許可する画像形式 |

4. **Create bucket** をクリック

---

### Step 3: ファイルパス構造

作成した `user-avatars` バケット内のファイルは以下の構造で保存されます：

```
user-avatars/
└── {user_id}/
    └── avatar.jpg  または avatar.png
```

**例**:
```
user-avatars/
├── 01234567-89ab-cdef-0123-456789abcdef/
│   └── avatar.jpg
└── fedcba98-7654-3210-fedc-ba9876543210/
    └── avatar.png
```

**ポイント**:
- ユーザーごとにフォルダ分離（`{user_id}/`）
- ファイル名は固定（`avatar.jpg` または `avatar.png`）
- 既存ファイルがある場合は上書き保存

---

### Step 4: RLS（Row Level Security）ポリシー設定

**重要**: Private Bucket の場合、RLS ポリシーは不要です。

- Edge Function が **Service Role Key** でアクセスするため、RLS は適用されません
- アクセス制御は Edge Function 側で実装します

**設定不要**: Policies タブでの設定は何も行いません

---

## 🔧 Edge Function 連携

### 必要な Edge Function

Storage へのアクセスは、以下の Edge Function 経由で行います：

| Edge Function | 用途 | 実装ステータス |
|--------------|------|--------------|
| `upload-avatar` | 画像アップロード | 未実装 |
| `get-avatar` | 画像取得（署名付きURL発行） | 未実装 |
| `delete-avatar` | 画像削除 | 未実装 |

### 実装フロー

#### 【アップロード】
```
1. アプリ → Edge Function (upload-avatar)
   - user_id、画像データ送信
2. Edge Function:
   - user_id 認証チェック
   - Storage にアップロード（{user_id}/avatar.jpg）
   - 署名付きURL生成（有効期限1時間）
   - avatar_url を DB に保存
3. アプリ ← 署名付きURL 返却
```

#### 【画像表示】
```
1. アプリ → Edge Function (get-avatar)
   - user_id 送信
2. Edge Function:
   - DB から avatar_url 取得
   - 署名付きURL 生成（有効期限1時間）
3. アプリ ← 署名付きURL 返却
4. NetworkImage で表示
```

#### 【画像削除】
```
1. アプリ → Edge Function (delete-avatar)
   - user_id 送信
2. Edge Function:
   - user_id 認証チェック
   - Storage から画像削除（{user_id}/avatar.jpg）
   - DB の avatar_url を NULL に更新
3. アプリ ← 削除完了通知
```

---

## 🔒 セキュリティ対策

### 1. 認証チェック

Edge Function 内で以下をチェック：
- リクエストに含まれる `user_id` の妥当性確認
- デバイスIDとの整合性確認

### 2. 署名付きURL

- **有効期限**: 1時間（3600秒）
- **URLの再利用不可**: 期限切れ後は再取得が必要
- **漏洩対策**: 短い有効期限により不正利用を防止

### 3. ファイルサイズ制限

- **最大ファイルサイズ**: 5 MB（推奨）
- **MIME type制限**: `image/jpeg`, `image/png` のみ許可

### 4. アクセス制御

- **ユーザー本人のみ**: 自分のアバター画像のみアップロード・削除可能
- **閲覧**: グループメンバーなど、適切な権限を持つユーザーのみ

---

## 📊 環境別セットアップ

### dev 環境

- Supabase Project: `group-todo-dev`
- Bucket name: `user-avatars`
- Public: オフ

### stg 環境

- Supabase Project: `group-todo-stg`
- Bucket name: `user-avatars`
- Public: オフ

### prod 環境

- Supabase Project: `group-todo-prod`
- Bucket name: `user-avatars`
- Public: オフ

**注意**: 各環境で同じ手順を繰り返してください。

---

## ✅ セットアップ完了確認

以下を確認してセットアップ完了です：

- [ ] `user-avatars` バケットが作成されている
- [ ] Public bucket が **オフ**（Private）になっている
- [ ] File size limit が設定されている（推奨: 5 MB）
- [ ] Allowed MIME types が設定されている（推奨: image/jpeg, image/png）

---

## 🔗 関連ドキュメント

- [Supabase Storage 公式ドキュメント](https://supabase.com/docs/guides/storage)
- [Supabase Edge Functions 公式ドキュメント](https://supabase.com/docs/guides/functions)
- `docs/guide/environment_setup_guide.md`: 環境設定ガイド

---

## 📝 変更履歴

| 日付 | 変更内容 |
|------|---------|
| 2025-10-11 | 初版作成（Private Bucket + Edge Function 設計） |

---

**最終更新日**: 2025-10-11
