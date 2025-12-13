import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../core/config/environment_config.dart';
import 'data_cache_service.dart';

/// 広告表示結果
enum AdShowResult {
  /// 広告視聴完了（報酬獲得）
  rewarded,

  /// 広告スキップ（広告フリーユーザーまたは広告機能無効）
  skipped,

  /// 広告視聴キャンセル（ユーザーが途中で閉じた）
  cancelled,

  /// 広告システム障害（読み込み/表示失敗）
  systemError,
}

/// リワード広告管理サービス（シングルトン）
/// 動画広告の読み込み・表示を管理
class RewardedAdService {
  static final RewardedAdService _instance = RewardedAdService._internal();
  factory RewardedAdService() => _instance;
  RewardedAdService._internal();

  final EnvironmentConfig _config = EnvironmentConfig.instance;
  final DataCacheService _cacheService = DataCacheService();

  RewardedAd? _rewardedAd;
  bool _isAdLoading = false;

  /// リトライ回数
  static const int _maxRetryCount = 3;

  /// リトライ間隔（ミリ秒）
  static const int _retryDelayMs = 1000;

  /// 広告が読み込み済みか
  bool get isAdReady => _rewardedAd != null;

  /// 広告スキップ対象ユーザーか（is_ad_free=true）
  bool get isAdFreeUser => _cacheService.currentUser?.isAdFree ?? false;

  /// 広告機能が有効か
  bool get isAdsEnabled => _config.enableAds;

  /// 広告を事前読み込み
  Future<void> loadAd() async {
    // 広告機能無効または広告スキップユーザーの場合はスキップ
    if (!isAdsEnabled || isAdFreeUser) {
      debugPrint('[RewardedAdService] ⚠️ 広告読み込みスキップ（無効または広告フリーユーザー）');
      return;
    }

    // 既に読み込み済みまたは読み込み中の場合はスキップ
    if (_rewardedAd != null || _isAdLoading) {
      debugPrint('[RewardedAdService] ⚠️ 広告は既に読み込み済みまたは読み込み中');
      return;
    }

    final adUnitId = _config.admobRewardedId;
    if (adUnitId.isEmpty) {
      debugPrint('[RewardedAdService] ❌ リワード広告IDが設定されていません');
      return;
    }

    _isAdLoading = true;
    debugPrint('[RewardedAdService] 🔄 リワード広告読み込み開始');

    final completer = Completer<bool>();

    await RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('[RewardedAdService] ✅ リワード広告読み込み完了');
          _rewardedAd = ad;
          _isAdLoading = false;
          if (!completer.isCompleted) {
            completer.complete(true);
          }
        },
        onAdFailedToLoad: (error) {
          debugPrint('[RewardedAdService] ❌ リワード広告読み込み失敗: ${error.message}');
          _rewardedAd = null;
          _isAdLoading = false;
          if (!completer.isCompleted) {
            completer.complete(false);
          }
        },
      ),
    );

    // 読み込み完了を待つ（タイムアウト5秒）
    await completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        _isAdLoading = false;
        return false;
      },
    );
  }

  /// 広告をリトライ付きで読み込み
  Future<bool> loadAdWithRetry() async {
    for (int i = 0; i < _maxRetryCount; i++) {
      if (_rewardedAd != null) {
        return true;
      }

      debugPrint('[RewardedAdService] 🔄 広告読み込み試行 ${i + 1}/$_maxRetryCount');
      await loadAd();

      if (_rewardedAd != null) {
        return true;
      }

      // 最後の試行でなければ待機
      if (i < _maxRetryCount - 1) {
        await Future.delayed(const Duration(milliseconds: _retryDelayMs));
      }
    }

    debugPrint('[RewardedAdService] ❌ 広告読み込み失敗（リトライ上限到達）');
    return false;
  }

  /// 広告を表示し、視聴完了を待つ
  /// 戻り値: AdShowResult
  Future<AdShowResult> showAdWithResult() async {
    // 広告スキップユーザーの場合は即座にskipped返却
    if (isAdFreeUser) {
      debugPrint('[RewardedAdService] ✅ 広告フリーユーザー：広告スキップ');
      return AdShowResult.skipped;
    }

    // 広告機能無効の場合は即座にskipped返却
    if (!isAdsEnabled) {
      debugPrint('[RewardedAdService] ✅ 広告機能無効：広告スキップ');
      return AdShowResult.skipped;
    }

    // 広告が読み込まれていない場合はリトライ付きで読み込み
    if (_rewardedAd == null) {
      debugPrint('[RewardedAdService] ⚠️ 広告が読み込まれていません。リトライ開始...');
      final loadSuccess = await loadAdWithRetry();
      if (!loadSuccess) {
        debugPrint('[RewardedAdService] ❌ 広告の読み込みに失敗しました（システム障害）');
        return AdShowResult.systemError;
      }
    }

    final completer = Completer<AdShowResult>();

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('[RewardedAdService] 📺 広告表示開始');
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('[RewardedAdService] 🔚 広告閉じられた');
        ad.dispose();
        _rewardedAd = null;
        // 次回のために事前読み込み
        loadAd();
        // completerがまだ完了していない場合（報酬なしで閉じた場合）
        if (!completer.isCompleted) {
          completer.complete(AdShowResult.cancelled);
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('[RewardedAdService] ❌ 広告表示失敗: ${error.message}');
        ad.dispose();
        _rewardedAd = null;
        loadAd();
        if (!completer.isCompleted) {
          completer.complete(AdShowResult.systemError);
        }
      },
    );

    await _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        debugPrint('[RewardedAdService] 🎁 報酬獲得: ${reward.amount} ${reward.type}');
        if (!completer.isCompleted) {
          completer.complete(AdShowResult.rewarded);
        }
      },
    );

    return completer.future;
  }

  /// 広告を表示し、視聴完了を待つ（後方互換性のため残す）
  /// 戻り値: true=視聴完了（報酬獲得）, false=キャンセルまたは失敗
  Future<bool> showAd() async {
    final result = await showAdWithResult();
    return result == AdShowResult.rewarded || result == AdShowResult.skipped;
  }

  /// リソース解放
  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
  }
}
