import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io' show Platform;
import '../core/utils/api_client.dart';

/// アプリ状態チェックサービス
class AppStatusService {
  final ApiClient _apiClient = ApiClient();

  /// アプリ状態チェック（メンテナンス・強制アップデート・バージョン情報）
  Future<AppStatusResponse> checkAppStatus() async {
    try {
      // アプリバージョン取得
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // プラットフォーム判定
      String platform = 'ios';
      if (!kIsWeb) {
        platform = Platform.isAndroid ? 'android' : 'ios';
      }

      // Edge Function呼び出し
      final response = await _apiClient.callFunction(
        functionName: 'check-app-status',
        body: {'current_version': currentVersion, 'platform': platform},
      );

      // Note: check-app-statusは他のAPIと異なり、success/errorフィールドを持たず、
      // 直接データを返す形式のため、successチェックは不要
      return AppStatusResponse.fromJson(response);
    } catch (e) {
      debugPrint('[AppStatusService] ❌ アプリ状態チェックエラー: $e');
      rethrow;
    }
  }
}

/// アプリ状態レスポンス
class AppStatusResponse {
  final MaintenanceInfo maintenance;
  final ForceUpdateInfo forceUpdate;
  final VersionInfo versionInfo;

  AppStatusResponse({
    required this.maintenance,
    required this.forceUpdate,
    required this.versionInfo,
  });

  factory AppStatusResponse.fromJson(Map<String, dynamic> json) {
    return AppStatusResponse(
      maintenance: MaintenanceInfo.fromJson(
        json['maintenance'] as Map<String, dynamic>,
      ),
      forceUpdate: ForceUpdateInfo.fromJson(
        json['force_update'] as Map<String, dynamic>,
      ),
      versionInfo: VersionInfo.fromJson(
        json['version_info'] as Map<String, dynamic>,
      ),
    );
  }
}

/// メンテナンス情報
class MaintenanceInfo {
  final bool isMaintenance;
  final String? message;

  MaintenanceInfo({required this.isMaintenance, this.message});

  factory MaintenanceInfo.fromJson(Map<String, dynamic> json) {
    return MaintenanceInfo(
      isMaintenance: json['is_maintenance'] as bool,
      message: json['message'] as String?,
    );
  }
}

/// 強制アップデート情報
class ForceUpdateInfo {
  final bool required;
  final String? message;
  final String? storeUrl;

  ForceUpdateInfo({required this.required, this.message, this.storeUrl});

  factory ForceUpdateInfo.fromJson(Map<String, dynamic> json) {
    return ForceUpdateInfo(
      required: json['required'] as bool,
      message: json['message'] as String?,
      storeUrl: json['store_url'] as String?,
    );
  }
}

/// バージョン情報
class VersionInfo {
  final String currentVersion;
  final String? latestVersion;
  final bool hasNewVersion;
  final NewVersionInfo? newVersionInfo;

  VersionInfo({
    required this.currentVersion,
    this.latestVersion,
    required this.hasNewVersion,
    this.newVersionInfo,
  });

  factory VersionInfo.fromJson(Map<String, dynamic> json) {
    return VersionInfo(
      currentVersion: json['current_version'] as String,
      latestVersion: json['latest_version'] as String?,
      hasNewVersion: json['has_new_version'] as bool,
      newVersionInfo: json['new_version_info'] != null
          ? NewVersionInfo.fromJson(
              json['new_version_info'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

/// 新バージョン情報
class NewVersionInfo {
  final String version;
  final String releaseNotes;
  final String releaseDate;
  final String? storeUrl;

  NewVersionInfo({
    required this.version,
    required this.releaseNotes,
    required this.releaseDate,
    this.storeUrl,
  });

  factory NewVersionInfo.fromJson(Map<String, dynamic> json) {
    return NewVersionInfo(
      version: json['version'] as String,
      releaseNotes: json['release_notes'] as String,
      releaseDate: json['release_date'] as String,
      storeUrl: json['store_url'] as String?,
    );
  }
}
