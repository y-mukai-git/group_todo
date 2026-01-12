/// エラーメッセージ定数クラス
///
/// アプリ全体で使用するエラーメッセージを統一管理
class ErrorMessages {
  /// 再試行を促すメッセージ
  static const String retryLater = 'しばらく時間をおいてから再度お試しください';

  /// アプリ初期化失敗メッセージ
  static const String appInitializationFailed = 'アプリの初期化に失敗しました';

  /// バージョン情報取得失敗メッセージ
  static const String versionInfoFetchFailed = 'バージョン情報の取得に失敗しました';

  /// 新規ユーザー作成失敗メッセージ
  static const String userCreationFailed = 'ユーザー作成に失敗しました';

  /// データ引き継ぎ入力エラーメッセージ
  static const String transferDataInputError = 'ユーザーIDとパスワードをご確認の上、再度入力してください';

  /// データ引き継ぎシステムエラーメッセージ
  static const String transferDataSystemError = 'データ引き継ぎ処理でエラーが発生しました';

  /// 引き継ぎ用パスワード設定失敗メッセージ
  static const String transferPasswordSetFailed = 'パスワードの設定に失敗しました';

  /// プロフィール更新失敗メッセージ
  static const String profileUpdateFailed = 'プロフィールの更新に失敗しました';

  /// 招待情報取得失敗メッセージ
  static const String invitationsFetchFailed = '招待情報の取得に失敗しました';

  /// グループ作成失敗メッセージ
  static const String groupCreationFailed = 'グループの作成に失敗しました';

  /// データ更新失敗メッセージ
  static const String dataRefreshFailed = 'データの更新に失敗しました';

  /// 並び順保存失敗メッセージ
  static const String groupOrderSaveFailed = '並び順の保存に失敗しました';

  /// 招待承認失敗メッセージ
  static const String invitationAcceptFailed = '招待の承認に失敗しました';

  /// 招待承認後のグループ情報取得失敗メッセージ
  static const String invitationAcceptedButGroupFetchFailed =
      '招待は承認されましたが、グループ情報の取得に失敗しました';

  /// 招待却下失敗メッセージ
  static const String invitationRejectFailed = '招待の却下に失敗しました';

  /// 招待が見つからない場合のメッセージ
  static const String invitationNotFound = 'この招待は既に処理済みです';

  /// グループ削除失敗メッセージ
  static const String groupDeleteFailed = 'グループの削除に失敗しました';

  /// メンバーロール変更失敗メッセージ
  static const String memberRoleChangeFailed = 'ロールの変更に失敗しました';

  /// メンバー削除失敗メッセージ
  static const String memberRemoveFailed = 'メンバーの削除に失敗しました';

  /// グループ脱退失敗メッセージ
  static const String groupLeaveFailed = 'グループの脱退に失敗しました';

  /// 定期タスク削除失敗メッセージ
  static const String recurringTodoDeleteFailed = '定期タスクの削除に失敗しました';

  /// 定期タスク作成失敗メッセージ
  static const String recurringTodoCreationFailed = '定期TODOの作成に失敗しました';

  /// 定期タスク更新失敗メッセージ
  static const String recurringTodoUpdateFailed = '定期TODOの更新に失敗しました';

  /// セットTODO削除失敗メッセージ
  static const String quickActionDeleteFailed = 'セットTODOの削除に失敗しました';

  /// セットTODO作成失敗メッセージ
  static const String quickActionCreationFailed = 'セットTODOの作成に失敗しました';

  /// セットTODO更新失敗メッセージ
  static const String quickActionUpdateFailed = 'セットTODOの更新に失敗しました';

  /// セットTODO実行失敗メッセージ
  static const String quickActionExecutionFailed = 'セットTODOの実行に失敗しました';

  /// 定期タスク切り替え失敗メッセージ
  static const String recurringTodoToggleFailed = '定期タスクの切り替えに失敗しました';

  /// TODO完了状態切り替え失敗メッセージ
  static const String todoCompletionToggleFailed = 'TODO状態の変更に失敗しました';

  /// タスク作成失敗メッセージ
  static const String todoCreationFailed = 'TODOの作成に失敗しました';

  /// タスク/グループ同時作成失敗メッセージ
  static const String todoAndGroupCreationFailed = 'TODO/グループの作成に失敗しました';

  /// タスク更新失敗メッセージ
  static const String todoUpdateFailed = 'TODOの更新に失敗しました';

  /// グループ情報更新失敗メッセージ
  static const String groupUpdateFailed = 'グループ情報の更新に失敗しました';

  /// TODO削除失敗メッセージ
  static const String todoDeleteFailed = 'TODOの削除に失敗しました';

  /// ユーザー招待バリデーション失敗メッセージ
  static const String userValidationFailed = '招待に失敗しました';

  /// ユーザー招待失敗メッセージ
  static const String invitationFailed = '招待に失敗しました';

  /// お問い合わせ送信失敗メッセージ
  static const String contactInquiryFailed = 'お問い合わせの送信に失敗しました';

  /// メンテナンス中メッセージ（固定）
  static const String maintenanceInProgress = 'システムメンテナンス中です';

  /// メンテナンス終了予定時刻を含むメッセージを生成
  ///
  /// [endTime] メンテナンス終了予定時刻（nullの場合は時刻なしメッセージ）
  ///
  /// 例:
  /// - 時刻あり: 「システムメンテナンス中です\n14:00までお待ちください」
  /// - 時刻なし: 「システムメンテナンス中です\nしばらく時間をおいてから再度お試しください」
  static String buildMaintenanceMessage(DateTime? endTime) {
    if (endTime == null) {
      return '$maintenanceInProgress\n$retryLater';
    }
    final timeStr =
        '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
    return '$maintenanceInProgress\n$timeStrまでお待ちください';
  }
}
