import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/announcement_model.dart';
import '../../data/models/user_model.dart';
import '../../services/data_cache_service.dart';
import '../../services/error_log_service.dart';
import '../widgets/error_dialog.dart';

/// お知らせ画面
class AnnouncementsScreen extends StatefulWidget {
  final UserModel user;

  const AnnouncementsScreen({super.key, required this.user});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final DataCacheService _cacheService = DataCacheService();
  List<AnnouncementModel> _announcements = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // キャッシュリスナー登録
    _cacheService.addListener(_updateAnnouncements);
    // 初回データ取得
    _loadAnnouncements();
  }

  @override
  void dispose() {
    // リスナー解除
    _cacheService.removeListener(_updateAnnouncements);
    super.dispose();
  }

  /// キャッシュからお知らせ取得
  void _updateAnnouncements() {
    if (mounted) {
      setState(() {
        _announcements = _cacheService.announcements;
      });
    }
  }

  /// お知らせ読み込み
  Future<void> _loadAnnouncements() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _cacheService.loadAnnouncements();
    } catch (e) {
      debugPrint('[AnnouncementsScreen] ❌ お知らせ取得エラー: $e');

      // エラーログ記録
      final errorLog = await ErrorLogService().logError(
        userId: widget.user.id,
        errorType: 'お知らせ取得エラー',
        errorMessage: 'お知らせの取得に失敗しました',
        stackTrace: '${e.toString()}\n${StackTrace.current.toString()}',
      );

      if (mounted) {
        // エラーダイアログ表示
        await ErrorDialog.show(
          context: context,
          errorId: errorLog.id,
          errorMessage: 'お知らせの取得に失敗しました',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('お知らせ'),
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadAnnouncements,
            tooltip: 'お知らせを更新',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // 初回ローディング中
    if (_isLoading && _announcements.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // お知らせがない場合
    if (_announcements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'お知らせはありません',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    // お知らせリスト表示
    return ListView.separated(
      itemCount: _announcements.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final announcement = _announcements[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          leading: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              announcement.version,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          title: Text(
            announcement.title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(announcement.content),
              const SizedBox(height: 8),
              Text(
                DateFormat('yyyy年MM月dd日').format(announcement.publishedAt),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
          isThreeLine: true,
        );
      },
    );
  }
}
