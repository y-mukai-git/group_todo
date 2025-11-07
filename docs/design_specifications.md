# グループTODO - デザイン仕様書

## ドキュメント概要

- **作成日**: 2025-11-07
- **対象**: グループTODOアプリのデザインシステム
- **目的**: UI/UXの一貫性を保つためのデザイン仕様を記録する

---

## 1. デザインシステム概要

### 1.1 デザインフレームワーク

**Material Design 3採用**

- Googleの最新デザインシステム
- `useMaterial3: true`で有効化
- モダンで洗練されたUI
- アクセシビリティの向上

### 1.2 デザインコンセプト

**モダンブルー系の洗練されたデザイン**

- アプリアイコンに合わせた配色
- クリーンで読みやすいUI
- 直感的な操作性
- 家族・知人間で使いやすいシンプルなデザイン

**テーマ切り替え対応**

- ライトテーマ（デフォルト）
- ダークテーマ（将来実装予定）

---

## 2. カラーシステム

### 2.1 ライトテーマのカラーパレット

| カラー名 | カラーコード | 用途 |
|----------|-------------|------|
| Primary Color | `#2C3E50` | リッチダークブルー - ヘッダー・フッター・主要UI |
| Secondary Color | `#3498DB` | 鮮やかブルー - アクセント・選択状態 |
| Tertiary Color | `#E74C3C` | アクセントレッド - 削除・警告アクション |
| Accent Color | `#1ABC9C` | ターコイズ - 完了状態・成功表示 |
| Error Color | `#E53935` | エラー表示 |
| Background Color | `#F8F9FA` | クリーンホワイト背景 |
| Surface Color | `#FFFFFF` | カード・ダイアログ背景 |

### 2.2 ダークテーマのカラーパレット

| カラー名 | カラーコード | 用途 |
|----------|-------------|------|
| Primary Color | `#2C3E50` | リッチダークブルー |
| Surface Color | `#1C2530` | ダークブルー背景 |
| On Surface Color | `#E8EBF0` | ライトグレー文字 |
| Indicator Color | `#2C3A48` | 選択中アイコン背景 |
| Inactive Color | `#9CA3AF` | 非選択状態 |

### 2.3 カラー使用原則

**一貫性の維持**

- ヘッダーとフッターは同じPrimary Colorを使用
- 完了状態は常にAccent Color（ターコイズ）
- エラー・削除は常にError/Tertiary Color（レッド）
- 成功通知はグリーン系

**コントラストの確保**

- 背景色と文字色のコントラスト比を確保
- アクセシビリティの考慮
- 読みやすさ重視

---

## 3. タイポグラフィ

### 3.1 フォント設定

**デフォルトフォント**

- iOS: San Francisco（システムフォント）
- Android: Roboto（システムフォント）
- Web: システムフォント

**モノスペースフォント**

- エラーID表示時に使用
- コード・IDの表示に適した等幅フォント

### 3.2 テキストスタイル

| 用途 | フォントサイズ | 太さ | 用途例 |
|------|--------------|------|--------|
| Headline | 24-28pt | Bold | 画面タイトル |
| Title | 18-20pt | Bold | セクションタイトル |
| Body | 14-16pt | Regular | 本文テキスト |
| Caption | 12pt | Regular | 補足情報・説明文 |
| Small | 10-11pt | Regular | 注釈・エラーID |

### 3.3 テキスト配置

**中央揃え**

- AppBarのタイトル（`centerTitle: true`）
- ダイアログのタイトル

**左揃え**

- リスト表示
- 本文テキスト
- フォーム入力

---

## 4. レイアウトパターン

### 4.1 画面構成

**基本構造**

```
┌─────────────────────────┐
│ AppBar (ヘッダー)          │ 高さ: 56pt
├─────────────────────────┤
│                         │
│   コンテンツエリア         │
│                         │
│                         │
├─────────────────────────┤
│ NavigationBar (フッター)   │ 高さ: 65pt
└─────────────────────────┘
```

**スペーシング**

- カード間マージン: horizontal 16pt, vertical 8pt
- パディング: 12-16pt（用途に応じて）
- セクション間スペース: 16-24pt

### 4.2 カードレイアウト

**Card設定**

- elevation: 1（わずかな影）
- margin: horizontal 16pt, vertical 8pt
- 角丸: デフォルト（Material Design 3）

**カード内レイアウト**

- パディング: 12-16pt
- タイトルと本文の間: 8-12pt
- アイコンとテキストの間: 8pt

---

## 5. UIコンポーネント

### 5.1 AppBar（ヘッダー）

**ライトテーマ**

- 背景色: Primary Color (`#2C3E50`)
- 文字色: 白色
- elevation: 0（通常時）、3（スクロール時）
- タイトル中央揃え

**ダークテーマ**

- 背景色: `#1C2530`
- 文字色: `#E8EBF0`

### 5.2 NavigationBar（フッター）

**構成**

- 高さ: 65pt
- elevation: 3
- ラベル: 常に表示（`alwaysShow`）

**アイコン**

- 選択中: サイズ28、白色
- 非選択: サイズ24、透明度70%

**ラベル**

- フォントサイズ: 12pt
- 選択中: 白色
- 非選択: 透明度70%

### 5.3 FloatingActionButton

**設定**

- 形状: 円形（`CircleBorder()`）
- elevation: 3
- 用途: 主要アクション（TODO作成、グループ作成等）

**配置**

- 画面右下
- NavigationBarの上に配置

### 5.4 ダイアログ

**AlertDialog - エラー表示**

- アイコン: `Icons.error_outline`（サイズ64）
- タイトル: 太字
- ボタン: `FilledButton`（プライマリーアクション）

**AlertDialog - メンテナンス表示**

- アイコン: `Icons.build`（オレンジ色）
- タイトル: アイコンとテキスト横並び
- ボタン: `TextButton`
- `barrierDismissible: false`（外側タップで閉じない）

**共通仕様**

- 角丸: デフォルト（Material Design 3）
- パディング: 自動（Material Design 3）
- 背景色: Surface Color

### 5.5 ボトムシート

**showModalBottomSheet**

- 使用用途: フォーム入力（グループ作成、TODO作成等）
- 背景色: Surface Color
- 角丸: 上部のみ
- `isScrollControlled: true`（高さ可変）

**アニメーション**

- スライドイン: 下から上へ（300ms、`easeOutCubic`）
- スムーズな表示

**パディング**

- 内側パディング: 16-24pt
- `MediaQuery.viewInsets.bottom`対応（キーボード表示時）

### 5.6 SnackBar

**成功通知**

- 背景色: グリーン（`Colors.green`）
- 表示時間: 2秒
- アクション: なし

**一般通知**

- 背景色: デフォルト（Material Design 3）
- 表示時間: 2-3秒
- アクション: 必要に応じて

**配置**

- 画面下部
- NavigationBarの上に表示

### 5.7 TextField / TextFormField

**InputDecoration**

- border: `OutlineInputBorder`（枠線あり）
- contentPadding: horizontal 16pt, vertical 12pt
- labelText: フローティングラベル

**文字数制限**

- maxLength設定による制限
- カウンター表示（自動）

### 5.8 Checkbox

**形状**

- 角丸: 4pt（`RoundedRectangleBorder`）
- Material Design 3の標準スタイル

### 5.9 Divider

**設定**

- thickness: 1pt
- space: 1pt
- セクション区切りに使用

---

## 6. アイコンシステム

### 6.1 アイコンライブラリ

**Material Icons使用**

- Flutter標準のMaterial Icons
- `Icons.*`で参照
- 豊富なアイコンセット

### 6.2 カテゴリ別アイコン

| カテゴリ | アイコン | 用途 |
|---------|---------|------|
| 未設定 | `label_off` | カテゴリ未設定 |
| 買い物 | `shopping_cart` | 買い物リスト |
| 家事 | `home` | 家事タスク |
| 仕事 | `work` | 仕事タスク |
| 趣味 | `palette` | 趣味活動 |
| その他 | `label` | その他カテゴリ |

### 6.3 アクション別アイコン

| アクション | アイコン | 色 |
|-----------|---------|-----|
| 追加 | `add` | Primary |
| 編集 | `edit` | Primary |
| 削除 | `delete` | Error/Tertiary |
| コピー | `copy` | Primary |
| 完了 | `check` / `check_circle` | Accent |
| エラー | `error_outline` | Error |
| 警告 | `warning` / `warning_amber` | Amber |
| メンテナンス | `build` | Orange |

### 6.4 アイコンサイズ

| 用途 | サイズ |
|------|-------|
| 大アイコン（ダイアログ等） | 64pt |
| 標準アイコン | 24pt |
| 選択中アイコン（NavigationBar） | 28pt |
| 小アイコン（ボタン内等） | 18-20pt |

---

## 7. アニメーション

### 7.1 ボトムシートアニメーション

**スライドイン**

- 開始位置: 画面下（`Offset(0, 1)`）
- 終了位置: 通常位置（`Offset.zero`）
- 時間: 300ms
- カーブ: `easeOutCubic`

### 7.2 その他アニメーション

**遷移アニメーション**

- Material Design 3のデフォルト遷移
- ページ遷移: フェード・スライド
- ダイアログ: フェードイン

**インタラクションフィードバック**

- タップ時のリップルエフェクト
- ボタン押下時の視覚的フィードバック

---

## 8. レスポンシブデザイン

### 8.1 画面サイズ対応

**モバイル優先**

- 主要ターゲット: スマートフォン
- タブレット対応
- Web対応（将来）

**SafeArea対応**

- ノッチ・パンチホール対応
- システムUIとの干渉を回避

### 8.2 キーボード表示対応

**パディング調整**

- `MediaQuery.viewInsets.bottom`対応
- キーボード表示時にUIが隠れないよう調整
- ボトムシート内のフォーム入力に必須

---

## 9. アクセシビリティ

### 9.1 コントラスト比

**WCAG 2.1準拠**

- テキストと背景のコントラスト比を確保
- 読みやすさ重視

### 9.2 タッチターゲット

**最小サイズ**

- ボタン・タップ可能要素: 最低44x44pt
- Material Design 3の推奨サイズ準拠

### 9.3 フィードバック

**視覚的フィードバック**

- タップ時のリップルエフェクト
- ローディング表示
- 成功・エラー通知

---

## 10. デザイントークン（定数管理）

### 10.1 カラー定数

**AppThemeクラスで管理**

- `AppTheme.primaryColor`
- `AppTheme.secondaryColor`
- `AppTheme.errorColor`
- 等

### 10.2 スペーシング定数

**推奨値**

- XS: 4pt
- S: 8pt
- M: 12pt
- L: 16pt
- XL: 24pt

### 10.3 elevation値

| 用途 | elevation |
|------|----------|
| 通常時AppBar | 0 |
| スクロール時AppBar | 3 |
| NavigationBar | 3 |
| FloatingActionButton | 3 |
| Card | 1 |

---
## 11. UI統一ルール

### 11.1 選択UIの統一

**基本方針**: ユーザーにネイティブな操作感を提供するため、iOS/Android共通でCupertinoピッカーを使用

#### 選択肢から選ぶUI（プルダウン相当）

**NG**: `DropdownButton`を使用
```dart
// ❌ 使用禁止
DropdownButton<String>(
  value: selectedValue,
  items: items.map((item) => DropdownMenuItem(...)).toList(),
  onChanged: (value) { ... },
)
```

**OK**: `showModalBottomSheet` + `CupertinoPicker`を使用
```dart
// ✅ 推奨
void _showPicker() {
  showModalBottomSheet(
    context: context,
    builder: (BuildContext context) {
      return Container(
        height: 250,
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('キャンセル'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() { /* 選択を確定 */ });
                    Navigator.pop(context);
                  },
                  child: const Text('完了'),
                ),
              ],
            ),
            Expanded(
              child: CupertinoPicker(
                itemExtent: 32.0,
                onSelectedItemChanged: (int index) {
                  // 選択変更時の処理
                },
                children: items.map((item) => Center(child: Text(item))).toList(),
              ),
            ),
          ],
        ),
      );
    },
  );
}
```

**実装例**:
- `create_todo_bottom_sheet.dart`: 担当者選択（Line 223-）
- `create_recurring_todo_bottom_sheet.dart`: 繰り返しパターン選択
- `group_detail_screen.dart`: カテゴリ選択

---

#### 日付・時刻選択UI

**OK**: `showModalBottomSheet` + `CupertinoDatePicker`を使用
```dart
// ✅ 推奨
Future<void> _selectDate() async {
  DateTime tempDate = selectedDate ?? DateTime.now();

  await showModalBottomSheet(
    context: context,
    builder: (BuildContext context) {
      return Container(
        height: 250,
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('キャンセル'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      selectedDate = tempDate;
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('完了'),
                ),
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: selectedDate ?? DateTime.now(),
                minimumDate: DateTime.now(),
                onDateTimeChanged: (DateTime newDate) {
                  tempDate = newDate;
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}
```

**実装例**:
- `create_todo_bottom_sheet.dart`: 期限選択（Line 162-214）
- `create_recurring_todo_bottom_sheet.dart`: 開始日選択

---

### 11.2 モーダル表示の統一

#### フォーム入力UI

**OK**: `showModalBottomSheet`を使用
```dart
showModalBottomSheet(
  context: context,
  isScrollControlled: true,  // 高さ可変
  builder: (BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,  // キーボード対応
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // フォーム内容
          ],
        ),
      ),
    );
  },
);
```

**実装例**:
- `create_todo_bottom_sheet.dart`: TODO作成・編集
- `create_recurring_todo_bottom_sheet.dart`: 定期TODO作成・編集
- `edit_user_profile_bottom_sheet.dart`: プロフィール編集

---

#### 確認ダイアログ

**OK**: `showDialog` + `AlertDialog`を使用
```dart
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('確認'),
    content: const Text('この操作を実行しますか？'),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('キャンセル'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, true),
        child: const Text('実行'),
      ),
    ],
  ),
);
```

---

### 11.3 UI統一の理由

#### なぜCupertinoピッカーを使用するのか？

1. **ネイティブな操作感**
   - iOSユーザーに馴染みのある操作方法
   - Androidユーザーにも違和感なく使える

2. **一貫性の確保**
   - プラットフォームに関わらず同じUI
   - ユーザー学習コストの低減

3. **視認性の向上**
   - ボトムシートで大きく表示
   - 選択肢が見やすい

4. **誤操作の防止**
   - キャンセル・完了ボタンで明示的に確定
   - DropdownButtonのような誤タップが起きにくい

---

**最終更新日**: 2025-11-07
