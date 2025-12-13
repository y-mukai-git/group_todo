import 'package:flutter/material.dart';
import '../../services/rewarded_ad_service.dart';
import '../../services/creation_limit_service.dart';
import '../../services/data_cache_service.dart';
import '../../services/error_log_service.dart';

/// 広告視聴必須ダイアログの種別
enum AdRequiredType {
  group,
  recurringTodo,
  quickAction,
}

/// 広告視聴必須ダイアログ
/// 無料枠を超過した場合に表示し、広告視聴で作成を許可する
class AdRequiredDialog {
  /// 広告視聴ダイアログを表示
  ///
  /// [type]: 作成対象の種別
  /// [groupId]: 定期TODO・クイックアクションの場合のグループID
  /// [currentCount]: 現在の件数
  /// [limit]: 上限値
  ///
  /// 戻り値: true=広告視聴完了で作成許可、false=キャンセル
  static Future<bool> show({
    required BuildContext context,
    required AdRequiredType type,
    String? groupId,
    required int currentCount,
    required int limit,
  }) async {
    final rewardedAdService = RewardedAdService();
    final creationLimitService = CreationLimitService();

    // ダイアログのタイトルとメッセージを設定
    final (title, itemName) = switch (type) {
      AdRequiredType.group => ('グループ作成', 'グループ'),
      AdRequiredType.recurringTodo => ('定期TODO作成', '定期TODO'),
      AdRequiredType.quickAction => ('クイックアクション作成', 'クイックアクション'),
    };

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.play_circle_outline, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              Expanded(child: Text(title)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$itemNameの無料枠（$limit件）を超えています。',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                '現在の件数: $currentCount件',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '動画広告を視聴すると、1件作成できます。',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton.icon(
              onPressed: () async {
                // ローディング表示
                showDialog(
                  context: dialogContext,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                );

                // 広告表示（リトライ付き）
                final adResult = await rewardedAdService.showAdWithResult();

                // ローディング非表示
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }

                // 結果に応じた処理
                switch (adResult) {
                  case AdShowResult.rewarded:
                  case AdShowResult.skipped:
                    // 広告視聴完了またはスキップ → 一時的な作成権限を付与
                    _grantPermission(creationLimitService, type, groupId);
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop(true);
                    }

                  case AdShowResult.systemError:
                    // 広告システム障害 → エラーログ送信 + 特別に作成を許可
                    _logAdSystemError(type);
                    _grantPermission(creationLimitService, type, groupId);
                    if (dialogContext.mounted) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(
                          content: const Text(
                            '広告システムの障害により、広告SKIPします。',
                          ),
                          backgroundColor: Colors.orange.shade700,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                      Navigator.of(dialogContext).pop(true);
                    }

                  case AdShowResult.cancelled:
                    // ユーザーがキャンセル
                    if (dialogContext.mounted) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('広告の視聴がキャンセルされました。'),
                          backgroundColor: Colors.grey,
                        ),
                      );
                    }
                }
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('広告を見て作成'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  /// 一時的な作成権限を付与
  static void _grantPermission(
    CreationLimitService service,
    AdRequiredType type,
    String? groupId,
  ) {
    switch (type) {
      case AdRequiredType.group:
        service.grantTemporaryGroupPermission();
      case AdRequiredType.recurringTodo:
        if (groupId != null) {
          service.grantTemporaryRecurringTodoPermission(groupId);
        }
      case AdRequiredType.quickAction:
        if (groupId != null) {
          service.grantTemporaryQuickActionPermission(groupId);
        }
    }
  }

  /// 広告システム障害のエラーログを送信
  static void _logAdSystemError(AdRequiredType type) {
    final cacheService = DataCacheService();
    final errorLogService = ErrorLogService();

    final typeName = switch (type) {
      AdRequiredType.group => 'グループ作成',
      AdRequiredType.recurringTodo => '定期TODO作成',
      AdRequiredType.quickAction => 'クイックアクション作成',
    };

    errorLogService.logError(
      userId: cacheService.currentUser?.id,
      errorType: 'AD_SYSTEM_ERROR',
      errorMessage: '広告システム障害: リワード広告の読み込み/表示に失敗しました（$typeName時）',
      screenName: 'AdRequiredDialog',
    );
  }

  /// グループ作成チェック＆ダイアログ表示
  ///
  /// 戻り値: true=作成可能、false=キャンセルまたは広告視聴失敗
  static Future<bool> checkAndShowForGroup(BuildContext context) async {
    final limitService = CreationLimitService();
    final result = limitService.checkGroupCreation();

    if (result.canCreate) {
      return true;
    }

    if (result.needsAd) {
      return show(
        context: context,
        type: AdRequiredType.group,
        currentCount: result.currentCount,
        limit: result.limit,
      );
    }

    return false;
  }

  /// 定期TODO作成チェック＆ダイアログ表示
  ///
  /// 戻り値: true=作成可能、false=キャンセルまたは広告視聴失敗
  static Future<bool> checkAndShowForRecurringTodo(
    BuildContext context,
    String groupId,
  ) async {
    final limitService = CreationLimitService();
    final result = limitService.checkRecurringTodoCreation(groupId);

    if (result.canCreate) {
      return true;
    }

    if (result.needsAd) {
      return show(
        context: context,
        type: AdRequiredType.recurringTodo,
        groupId: groupId,
        currentCount: result.currentCount,
        limit: result.limit,
      );
    }

    return false;
  }

  /// クイックアクション作成チェック＆ダイアログ表示
  ///
  /// 戻り値: true=作成可能、false=キャンセルまたは広告視聴失敗
  static Future<bool> checkAndShowForQuickAction(
    BuildContext context,
    String groupId,
  ) async {
    final limitService = CreationLimitService();
    final result = limitService.checkQuickActionCreation(groupId);

    if (result.canCreate) {
      return true;
    }

    if (result.needsAd) {
      return show(
        context: context,
        type: AdRequiredType.quickAction,
        groupId: groupId,
        currentCount: result.currentCount,
        limit: result.limit,
      );
    }

    return false;
  }
}
