import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/models/user_model.dart';
import '../../services/user_service.dart';
import '../../core/config/environment_config.dart';
import '../widgets/edit_user_profile_bottom_sheet.dart';
import '../widgets/contact_inquiry_bottom_sheet.dart';
import 'announcements_screen.dart';

/// 設定画面
class SettingsScreen extends StatefulWidget {
  final UserModel user;

  const SettingsScreen({super.key, required this.user});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final UserService _userService = UserService();
  final EnvironmentConfig _config = EnvironmentConfig.instance;
  String? _signedAvatarUrl;

  /// プロフィール編集ボトムシート表示
  void _showEditProfileBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => EditUserProfileBottomSheet(
        user: widget.user,
        currentSignedAvatarUrl: _signedAvatarUrl,
        onProfileUpdated: _loadSignedAvatarUrl,
      ),
    );
  }

  /// 署名付きアバターURL読み込み
  Future<void> _loadSignedAvatarUrl() async {
    try {
      final response = await _userService.getUserByDevice();
      if (response != null && mounted) {
        setState(() {
          _signedAvatarUrl = response['signed_avatar_url'] as String?;
        });
      }
    } catch (e) {
      debugPrint('[SettingsScreen] ❌ アバターURL取得エラー: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSignedAvatarUrl();
  }

  /// 引き継ぎ用パスワード設定
  Future<void> _setupTransferPassword() async {
    final TextEditingController passwordController = TextEditingController();
    final TextEditingController confirmController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // ヘッダー
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.phone_android,
                      color: Theme.of(context).colorScheme.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '引き継ぎ用パスワード設定',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // コンテンツ
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 説明
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 20,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'データ引き継ぎについて',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '新しい端末でデータを引き継ぐには、ユーザーID（8桁）とパスワードの両方が必要です。',
                              style: TextStyle(fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'パスワード設定後に表示される情報を必ず控えておいてください。',
                              style: TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // パスワード入力
                      TextField(
                        controller: passwordController,
                        decoration: const InputDecoration(
                          labelText: 'パスワード',
                          hintText: '8文字以上',
                          prefixIcon: Icon(Icons.lock),
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                      ),

                      const SizedBox(height: 16),

                      // パスワード確認入力
                      TextField(
                        controller: confirmController,
                        decoration: const InputDecoration(
                          labelText: 'パスワード（確認）',
                          hintText: '再度入力',
                          prefixIcon: Icon(Icons.lock),
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                      ),

                      const SizedBox(height: 24),

                      // 設定ボタン
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            final password = passwordController.text;
                            final confirm = confirmController.text;

                            if (password.length < 8) {
                              _showErrorSnackBar('パスワードは8文字以上で設定してください');
                              return;
                            }

                            if (password != confirm) {
                              _showErrorSnackBar('パスワードが一致しません');
                              return;
                            }

                            Navigator.pop(context);
                            _saveTransferPassword(password);
                          },
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('設定'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    passwordController.dispose();
    confirmController.dispose();
  }

  /// 引き継ぎ用パスワード保存
  Future<void> _saveTransferPassword(String password) async {
    try {
      final credentials = await _userService.setTransferPassword(
        userId: widget.user.id,
        password: password,
      );

      if (!mounted) return;
      _showTransferCredentialsDialog(
        credentials['display_id']!,
        credentials['password']!,
      );
    } catch (e) {
      debugPrint('[SettingsScreen] ❌ 引き継ぎ用パスワード設定エラー: $e');
      _showErrorSnackBar('パスワードの設定に失敗しました');
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  /// エラーメッセージ表示
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  /// 設定項目リスト構築
  List<Widget> _buildSettingsItems() {
    final items = <Widget>[
      // データ引き継ぎ
      ListTile(
        leading: const Icon(Icons.phone_android),
        title: const Text('データ引き継ぎ'),
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
              builder: (context) => const AnnouncementsScreen(),
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
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (context) => ContactInquiryBottomSheet(user: widget.user),
          );
        },
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

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: Column(
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
                    Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundImage: _signedAvatarUrl != null
                              ? NetworkImage(_signedAvatarUrl!)
                              : null,
                          child: _signedAvatarUrl == null
                              ? Text(
                                  widget.user.displayName.isNotEmpty
                                      ? widget.user.displayName[0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(fontSize: 32),
                                )
                              : null,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.user.displayName,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'ユーザーID: ${widget.user.displayId}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
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

          // 設定項目リスト（ListView.separated使用）
          Expanded(
            child: ListView.separated(
              itemCount: settingsItems.length,
              separatorBuilder: (context, index) => const Divider(indent: 30),
              itemBuilder: (context, index) => settingsItems[index],
            ),
          ),
        ],
      ),
    );
  }
}
