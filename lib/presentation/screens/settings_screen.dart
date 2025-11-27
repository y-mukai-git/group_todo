import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/constants/error_messages.dart';
import '../../data/models/user_model.dart';
import '../../services/data_cache_service.dart';
import '../../services/app_status_service.dart';
import '../../services/error_log_service.dart';
import '../../core/config/environment_config.dart';
import '../../core/utils/api_client.dart';
import '../../core/utils/snackbar_helper.dart';
import '../widgets/edit_user_profile_bottom_sheet.dart';
import '../widgets/contact_inquiry_bottom_sheet.dart';
import '../widgets/transfer_password_bottom_sheet.dart';
import '../widgets/error_dialog.dart';
import '../widgets/maintenance_dialog.dart';
import 'announcements_screen.dart';
import 'content_policy_screen.dart';

/// 設定画面
class SettingsScreen extends StatefulWidget {
  final UserModel user;

  const SettingsScreen({super.key, required this.user});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DataCacheService _cacheService = DataCacheService();
  final EnvironmentConfig _config = EnvironmentConfig.instance;
  final AppStatusService _statusService = AppStatusService();
  String? _signedAvatarUrl;
  UserModel? _currentUser;
  String _appVersion = '';
  VersionInfo? _versionInfo;

  /// キャッシュからユーザーデータ更新
  void _updateUserData() {
    if (mounted) {
      setState(() {
        _currentUser = _cacheService.currentUser;
        _signedAvatarUrl = _cacheService.signedAvatarUrl;
      });
    }
  }

  /// プロフィール編集ボトムシート表示
  void _showEditProfileBottomSheet() {
    if (_currentUser == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        // コンテンツエリアの80%を固定値として計算
        final mediaQuery = MediaQuery.of(context);
        final contentHeight =
            mediaQuery.size.height -
            mediaQuery.padding.top -
            mediaQuery.padding.bottom;

        return Container(
          height: contentHeight * 0.8,
          margin: EdgeInsets.only(top: contentHeight * 0.2),
          child: EditUserProfileBottomSheet(
            user: _currentUser!,
            currentSignedAvatarUrl: _signedAvatarUrl,
            onProfileUpdated: () {}, // notifyListenersで自動更新されるため不要
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _cacheService.addListener(_updateUserData);
    _updateUserData();
    _loadAppVersion();
  }

  /// アプリバージョン取得
  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final statusResponse = await _statusService.checkAppStatus();

      if (mounted) {
        setState(() {
          _appVersion = packageInfo.version;
          _versionInfo = statusResponse.versionInfo;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('[SettingsScreen] ❌ バージョン情報取得エラー: $e');

      // メンテナンスモード時は MaintenanceDialog を表示
      if (e is MaintenanceException) {
        if (!mounted) return;
        await MaintenanceDialog.show(
          context: context,
          message: e.message, // api_client.dartで固定メッセージを生成済み
        );
        return;
      }

      // エラーログ記録
      final errorLog = await ErrorLogService().logError(
        userId: _currentUser?.id,
        errorType: 'バージョン情報取得エラー',
        errorMessage: ErrorMessages.versionInfoFetchFailed,
        stackTrace: '${e.toString()}\n${stackTrace.toString()}',
        screenName: '設定画面',
      );

      // エラーダイアログ表示
      if (!mounted) return;
      await ErrorDialog.show(
        context: context,
        errorId: errorLog.id,
        errorMessage: '${ErrorMessages.versionInfoFetchFailed}\n${ErrorMessages.retryLater}',
      );
    }
  }

  @override
  void dispose() {
    _cacheService.removeListener(_updateUserData);
    super.dispose();
  }

  /// 引き継ぎ用パスワード設定
  Future<void> _setupTransferPassword() async {
    if (_currentUser == null) return;

    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        // コンテンツエリアの80%を固定値として計算
        final mediaQuery = MediaQuery.of(context);
        final contentHeight =
            mediaQuery.size.height -
            mediaQuery.padding.top -
            mediaQuery.padding.bottom;

        return Container(
          height: contentHeight * 0.8,
          margin: EdgeInsets.only(top: contentHeight * 0.2),
          child: TransferPasswordBottomSheet(userId: _currentUser!.id),
        );
      },
    );

    if (result != null && result is Map<String, String>) {
      _showTransferCredentialsDialog(
        result['display_id']!,
        result['password']!,
      );
    }
  }

  /// 引き継ぎ情報ダイアログ表示
  void _showTransferCredentialsDialog(String displayId, String password) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('データ引き継ぎ情報'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('以下の情報を新しい端末で入力してください', textAlign: TextAlign.center),
              const SizedBox(height: 24),
              const Text(
                'ユーザーID（8桁）',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  displayId,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'パスワード',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  password,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(
                ClipboardData(text: 'ユーザーID: $displayId\nパスワード: $password'),
              );
              _showSuccessSnackBar('引き継ぎ情報をコピーしました');
            },
            child: const Text('コピー'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  /// 成功メッセージ表示
  void _showSuccessSnackBar(String message) {
    SnackBarHelper.showSuccessSnackBar(context, message);
  }

  /// バージョンテキスト構築
  String _buildVersionText() {
    if (_appVersion.isEmpty) {
      return '取得中...';
    }

    if (_versionInfo == null) {
      return 'バージョン $_appVersion';
    }

    if (_versionInfo!.hasNewVersion) {
      return 'バージョン $_appVersion';
    }

    return 'バージョン $_appVersion(最新)';
  }

  /// 設定項目リスト構築
  List<Widget> _buildSettingsItems() {
    final items = <Widget>[
      // データ引き継ぎ設定
      ListTile(
        leading: const Icon(Icons.phone_android),
        title: const Text('データ引き継ぎ設定'),
        subtitle: const Text('他の端末にデータを移行'),
        trailing: const Icon(Icons.chevron_right),
        onTap: _setupTransferPassword,
      ),

      // お知らせ
      ListTile(
        leading: const Icon(Icons.notifications),
        title: const Text('お知らせ'),
        subtitle: const Text('アップデート情報'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AnnouncementsScreen(user: widget.user),
            ),
          );
        },
      ),

      // 入力における注意事項
      ListTile(
        leading: const Icon(Icons.policy),
        title: const Text('入力における注意事項'),
        subtitle: const Text('入力時の注意点'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ContentPolicyScreen(),
            ),
          );
        },
      ),

      // お問い合わせ
      ListTile(
        leading: const Icon(Icons.contact_support),
        title: const Text('お問い合わせ'),
        subtitle: const Text('不具合報告・機能要望'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          if (_currentUser == null) return;
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) {
              // コンテンツエリアの80%を固定値として計算
              final mediaQuery = MediaQuery.of(context);
              final contentHeight =
                  mediaQuery.size.height -
                  mediaQuery.padding.top -
                  mediaQuery.padding.bottom;

              return Container(
                height: contentHeight * 0.8,
                margin: EdgeInsets.only(top: contentHeight * 0.2),
                child: ContactInquiryBottomSheet(user: _currentUser!),
              );
            },
          );
        },
      ),

      // アプリバージョン
      ListTile(
        leading: const Icon(Icons.info_outline),
        title: const Text('アプリバージョン'),
        subtitle: Text(_buildVersionText()),
      ),
    ];

    // 環境表示（dev/stgのみ、prodでは非表示）
    if (_config.environment != 'prod') {
      items.add(
        ListTile(
          leading: const Icon(Icons.code),
          title: const Text('環境'),
          subtitle: Text(_config.appTitle),
        ),
      );
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final settingsItems = _buildSettingsItems();

    // 設定項目をDividerで区切ったリストを作成
    final settingsItemsWithDividers = <Widget>[];
    for (int i = 0; i < settingsItems.length; i++) {
      settingsItemsWithDividers.add(settingsItems[i]);
      if (i < settingsItems.length - 1) {
        settingsItemsWithDividers.add(const Divider(indent: 30));
      }
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(title: const Text('設定')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ユーザー情報セクション
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 140,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 32,
                              backgroundImage: _signedAvatarUrl != null
                                  ? NetworkImage(_signedAvatarUrl!)
                                  : null,
                              child: _signedAvatarUrl == null
                                  ? Text(
                                      _currentUser?.displayName.isNotEmpty ==
                                              true
                                          ? _currentUser!.displayName[0]
                                          : 'U',
                                      style: const TextStyle(fontSize: 28),
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Text(
                                _currentUser?.displayName ?? '',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                                maxLines: 1,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () {
                                final displayId = _currentUser?.displayId ?? '';
                                if (displayId.isNotEmpty) {
                                  Clipboard.setData(
                                    ClipboardData(text: displayId),
                                  );
                                  _showSuccessSnackBar('ユーザーIDをコピーしました');
                                }
                              },
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'ユーザーID: ${_currentUser?.displayId ?? ''}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.copy,
                                      size: 14,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: _showEditProfileBottomSheet,
                          tooltip: 'プロフィールを編集',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 設定項目リスト
            ...settingsItemsWithDividers,
          ],
        ),
      ),
    );
  }
}
