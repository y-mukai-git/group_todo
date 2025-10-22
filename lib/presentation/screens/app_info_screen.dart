import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform;
import '../../services/app_status_service.dart';

/// アプリ情報画面
class AppInfoScreen extends StatefulWidget {
  const AppInfoScreen({super.key});

  @override
  State<AppInfoScreen> createState() => _AppInfoScreenState();
}

class _AppInfoScreenState extends State<AppInfoScreen> {
  final AppStatusService _statusService = AppStatusService();
  String _currentVersion = '';
  VersionInfo? _versionInfo;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVersionInfo();
  }

  Future<void> _loadVersionInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final statusResponse = await _statusService.checkAppStatus();

      setState(() {
        _currentVersion = packageInfo.version;
        _versionInfo = statusResponse.versionInfo;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[AppInfoScreen] ❌ バージョン情報取得エラー: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// ストアURLを起動
  Future<void> _launchStore() async {
    // プラットフォームに応じたストアURLを取得
    // 実際のURLはapp_versionsテーブルから取得する必要があるため、
    // ここでは簡易的な実装
    String storeUrl = '';
    if (Platform.isIOS) {
      storeUrl = 'https://apps.apple.com/jp/app/your-app-id';
    } else if (Platform.isAndroid) {
      storeUrl =
          'https://play.google.com/store/apps/details?id=your.package.name';
    }

    final url = Uri.parse(storeUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ストアを開けませんでした'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('アプリ情報')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildInfoCard(
                  title: '現在のバージョン',
                  content: _currentVersion,
                  icon: Icons.info_outline,
                ),
                const SizedBox(height: 16),
                if (_versionInfo != null && _versionInfo!.hasNewVersion) ...[
                  _buildInfoCard(
                    title: '最新バージョン',
                    content: _versionInfo!.latestVersion ?? '',
                    icon: Icons.new_releases,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  if (_versionInfo!.newVersionInfo != null) ...[
                    _buildReleaseNotesCard(_versionInfo!.newVersionInfo!),
                    const SizedBox(height: 16),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _launchStore,
                      icon: const Icon(Icons.download),
                      label: const Text('アップデートする'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ] else ...[
                  _buildInfoCard(
                    title: 'ステータス',
                    content: '最新バージョンです',
                    icon: Icons.check_circle_outline,
                    color: Colors.green,
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String content,
    required IconData icon,
    Color? color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    content,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReleaseNotesCard(NewVersionInfo info) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.description_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'リリースノート',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              info.releaseNotes,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'リリース日: ${_formatDate(info.releaseDate)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return '${date.year}年${date.month}月${date.day}日';
    } catch (e) {
      return isoDate;
    }
  }
}
