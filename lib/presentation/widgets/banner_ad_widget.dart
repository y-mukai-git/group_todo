import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../core/config/environment_config.dart';

/// バナー広告ウィジェット
/// フッター下部に固定表示する広告
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  final _config = EnvironmentConfig.instance;

  @override
  void initState() {
    super.initState();
    if (_config.enableAds) {
      _loadAd();
    }
  }

  void _loadAd() {
    final bannerId = _config.admobBannerId;

    if (bannerId.isEmpty) {
      debugPrint('[BannerAdWidget] ⚠️ 広告IDが設定されていません');
      return;
    }

    _bannerAd = BannerAd(
      adUnitId: bannerId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('[BannerAdWidget] ✅ 広告読み込み完了');
          if (mounted) {
            setState(() {
              _isAdLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('[BannerAdWidget] ❌ 広告読み込み失敗: $error');
          ad.dispose();
        },
      ),
    );

    _bannerAd!.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 広告機能が無効の場合は何も表示しない
    if (!_config.enableAds) {
      return const SizedBox.shrink();
    }

    // 広告がまだ読み込まれていない場合はプレースホルダー表示
    if (!_isAdLoaded || _bannerAd == null) {
      return Container(
        height: 50,
        color: Colors.grey[200],
        child: const Center(
          child: Text(
            '広告を読み込み中...',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity, // width 100%
      height: _bannerAd!.size.height.toDouble(),
      child: Center(
        child: AdWidget(ad: _bannerAd!),
      ),
    );
  }
}
