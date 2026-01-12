import 'package:flutter/material.dart';
import 'data_cache_service.dart';

/// 作成上限チェック結果
class CreationLimitResult {
  /// 作成可能か
  final bool canCreate;

  /// 広告視聴が必要か
  final bool needsAd;

  /// 現在の件数
  final int currentCount;

  /// 上限値
  final int limit;

  const CreationLimitResult({
    required this.canCreate,
    required this.needsAd,
    required this.currentCount,
    required this.limit,
  });
}

/// 作成上限管理サービス（シングルトン）
/// グループ・定期TODO・クイックアクションの無料枠管理
class CreationLimitService {
  static final CreationLimitService _instance =
      CreationLimitService._internal();
  factory CreationLimitService() => _instance;
  CreationLimitService._internal();

  final DataCacheService _cacheService = DataCacheService();

  // 無料枠の上限値
  static const int groupLimit = 5;
  static const int recurringTodoLimitPerGroup = 3;
  static const int quickActionLimitPerGroup = 3;

  // 一時的な作成権（広告視聴後に付与、アプリ終了でリセット）
  // Key: 'group' | 'recurring:{groupId}' | 'quickAction:{groupId}'
  final Set<String> _temporaryPermissions = {};

  /// 広告スキップ対象ユーザーか（is_ad_free=true）
  bool get isAdFreeUser => _cacheService.currentUser?.isAdFree ?? false;

  /// グループ作成可能かチェック
  /// 自分が作成した（オーナーである）グループのみカウント
  CreationLimitResult checkGroupCreation() {
    final userId = _cacheService.currentUser?.id;
    // 自分がオーナーのグループのみカウント
    final currentCount = _cacheService.groups
        .where((g) => g.ownerId == userId)
        .length;

    // 広告スキップユーザーは常に作成可能
    if (isAdFreeUser) {
      return CreationLimitResult(
        canCreate: true,
        needsAd: false,
        currentCount: currentCount,
        limit: groupLimit,
      );
    }

    // 無料枠内なら作成可能
    if (currentCount < groupLimit) {
      return CreationLimitResult(
        canCreate: true,
        needsAd: false,
        currentCount: currentCount,
        limit: groupLimit,
      );
    }

    // 一時的な作成権があれば作成可能
    if (_temporaryPermissions.contains('group')) {
      return CreationLimitResult(
        canCreate: true,
        needsAd: false,
        currentCount: currentCount,
        limit: groupLimit,
      );
    }

    // 上限超過、広告視聴が必要
    return CreationLimitResult(
      canCreate: false,
      needsAd: true,
      currentCount: currentCount,
      limit: groupLimit,
    );
  }

  /// 定期TODO作成可能かチェック
  CreationLimitResult checkRecurringTodoCreation(String groupId) {
    final currentCount = _cacheService
        .getRecurringTodosByGroupId(groupId)
        .length;

    // 広告スキップユーザーは常に作成可能
    if (isAdFreeUser) {
      return CreationLimitResult(
        canCreate: true,
        needsAd: false,
        currentCount: currentCount,
        limit: recurringTodoLimitPerGroup,
      );
    }

    // 無料枠内なら作成可能
    if (currentCount < recurringTodoLimitPerGroup) {
      return CreationLimitResult(
        canCreate: true,
        needsAd: false,
        currentCount: currentCount,
        limit: recurringTodoLimitPerGroup,
      );
    }

    // 一時的な作成権があれば作成可能
    if (_temporaryPermissions.contains('recurring:$groupId')) {
      return CreationLimitResult(
        canCreate: true,
        needsAd: false,
        currentCount: currentCount,
        limit: recurringTodoLimitPerGroup,
      );
    }

    // 上限超過、広告視聴が必要
    return CreationLimitResult(
      canCreate: false,
      needsAd: true,
      currentCount: currentCount,
      limit: recurringTodoLimitPerGroup,
    );
  }

  /// クイックアクション作成可能かチェック
  CreationLimitResult checkQuickActionCreation(String groupId) {
    final currentCount = _cacheService.getQuickActionsByGroupId(groupId).length;

    // 広告スキップユーザーは常に作成可能
    if (isAdFreeUser) {
      return CreationLimitResult(
        canCreate: true,
        needsAd: false,
        currentCount: currentCount,
        limit: quickActionLimitPerGroup,
      );
    }

    // 無料枠内なら作成可能
    if (currentCount < quickActionLimitPerGroup) {
      return CreationLimitResult(
        canCreate: true,
        needsAd: false,
        currentCount: currentCount,
        limit: quickActionLimitPerGroup,
      );
    }

    // 一時的な作成権があれば作成可能
    if (_temporaryPermissions.contains('quickAction:$groupId')) {
      return CreationLimitResult(
        canCreate: true,
        needsAd: false,
        currentCount: currentCount,
        limit: quickActionLimitPerGroup,
      );
    }

    // 上限超過、広告視聴が必要
    return CreationLimitResult(
      canCreate: false,
      needsAd: true,
      currentCount: currentCount,
      limit: quickActionLimitPerGroup,
    );
  }

  /// グループ作成の一時的な権限を付与
  void grantTemporaryGroupPermission() {
    _temporaryPermissions.add('group');
    debugPrint('[CreationLimitService] ✅ グループ作成の一時権限を付与');
  }

  /// 定期TODO作成の一時的な権限を付与
  void grantTemporaryRecurringTodoPermission(String groupId) {
    _temporaryPermissions.add('recurring:$groupId');
    debugPrint('[CreationLimitService] ✅ 定期TODO作成の一時権限を付与: groupId=$groupId');
  }

  /// クイックアクション作成の一時的な権限を付与
  void grantTemporaryQuickActionPermission(String groupId) {
    _temporaryPermissions.add('quickAction:$groupId');
    debugPrint(
      '[CreationLimitService] ✅ クイックアクション作成の一時権限を付与: groupId=$groupId',
    );
  }

  /// グループ作成の一時的な権限を消費（作成成功後に呼び出し）
  void consumeTemporaryGroupPermission() {
    _temporaryPermissions.remove('group');
    debugPrint('[CreationLimitService] 🔄 グループ作成の一時権限を消費');
  }

  /// 定期TODO作成の一時的な権限を消費（作成成功後に呼び出し）
  void consumeTemporaryRecurringTodoPermission(String groupId) {
    _temporaryPermissions.remove('recurring:$groupId');
    debugPrint('[CreationLimitService] 🔄 定期TODO作成の一時権限を消費: groupId=$groupId');
  }

  /// クイックアクション作成の一時的な権限を消費（作成成功後に呼び出し）
  void consumeTemporaryQuickActionPermission(String groupId) {
    _temporaryPermissions.remove('quickAction:$groupId');
    debugPrint(
      '[CreationLimitService] 🔄 クイックアクション作成の一時権限を消費: groupId=$groupId',
    );
  }

  /// 全ての一時的な権限をクリア（アプリ再起動時などに呼び出し）
  void clearAllTemporaryPermissions() {
    _temporaryPermissions.clear();
    debugPrint('[CreationLimitService] 🧹 全ての一時権限をクリア');
  }
}
