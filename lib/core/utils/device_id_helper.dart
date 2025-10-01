import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// デバイスID取得ヘルパークラス
class DeviceIdHelper {
  static const String _deviceIdKey = 'device_id';

  /// デバイスIDを取得（初回はデバイス固有ID、2回目以降はキャッシュ）
  static Future<String> getDeviceId() async {
    try {
      // キャッシュから取得を試行
      final prefs = await SharedPreferences.getInstance();
      final cachedDeviceId = prefs.getString(_deviceIdKey);

      if (cachedDeviceId != null && cachedDeviceId.isNotEmpty) {
        debugPrint('[DeviceIdHelper] ✅ キャッシュからデバイスID取得: $cachedDeviceId');
        return cachedDeviceId;
      }

      // プラットフォーム別にデバイスID取得
      String deviceId;
      final deviceInfo = DeviceInfoPlugin();

      if (kIsWeb) {
        // Web: UUIDを生成してキャッシュ
        deviceId = const Uuid().v4();
        debugPrint('[DeviceIdHelper] 🌐 Web用UUID生成: $deviceId');
      } else if (Platform.isIOS) {
        // iOS: identifierForVendor
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? const Uuid().v4();
        debugPrint('[DeviceIdHelper] 🍎 iOS identifierForVendor: $deviceId');
      } else if (Platform.isAndroid) {
        // Android: androidId
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
        debugPrint('[DeviceIdHelper] 🤖 Android ID: $deviceId');
      } else {
        // その他: UUID生成
        deviceId = const Uuid().v4();
        debugPrint('[DeviceIdHelper] 📱 その他プラットフォーム UUID: $deviceId');
      }

      // キャッシュに保存
      await prefs.setString(_deviceIdKey, deviceId);
      debugPrint('[DeviceIdHelper] 💾 デバイスIDをキャッシュに保存');

      return deviceId;
    } catch (e) {
      debugPrint('[DeviceIdHelper] ❌ デバイスID取得エラー: $e');
      // エラー時はUUID生成
      final fallbackId = const Uuid().v4();
      debugPrint('[DeviceIdHelper] 🆘 フォールバックUUID: $fallbackId');

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_deviceIdKey, fallbackId);
      } catch (_) {}

      return fallbackId;
    }
  }

  /// デバイスIDをクリア（主にテスト用）
  static Future<void> clearDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_deviceIdKey);
      debugPrint('[DeviceIdHelper] 🗑️ デバイスIDキャッシュをクリア');
    } catch (e) {
      debugPrint('[DeviceIdHelper] ❌ デバイスIDクリアエラー: $e');
    }
  }
}
