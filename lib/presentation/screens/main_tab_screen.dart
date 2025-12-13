import 'package:flutter/material.dart';
import '../../data/models/user_model.dart';
import '../../presentation/widgets/banner_ad_widget.dart';
import '../../services/data_cache_service.dart';
import '../widgets/app_navigation_bar.dart';
import 'home_screen.dart';
import 'groups_screen.dart';
import 'settings_screen.dart';

/// メインタブ画面（ボトムナビゲーション）
class MainTabScreen extends StatefulWidget {
  final UserModel user;

  const MainTabScreen({super.key, required this.user});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  final DataCacheService _cacheService = DataCacheService();
  int _currentIndex = 0;
  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  /// 広告スキップ対象ユーザーか（is_ad_free=true）
  bool get _isAdFreeUser => _cacheService.currentUser?.isAdFree ?? false;

  void _onTabTapped(int index) {
    if (_currentIndex == index) {
      // 同じタブをタップした場合はルートに戻る
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
    } else {
      // 別のタブに切り替える前に、現在のタブをルートに戻す
      _navigatorKeys[_currentIndex].currentState?.popUntil(
        (route) => route.isFirst,
      );
      setState(() {
        _currentIndex = index;
      });
    }
  }

  Widget _buildNavigator(int index) {
    return Navigator(
      key: _navigatorKeys[index],
      onGenerateRoute: (routeSettings) {
        return MaterialPageRoute(
          builder: (context) {
            switch (index) {
              case 0:
                return HomeScreen(user: widget.user);
              case 1:
                return GroupsScreen(user: widget.user);
              case 2:
                return SettingsScreen(user: widget.user);
              default:
                return HomeScreen(user: widget.user);
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [_buildNavigator(0), _buildNavigator(1), _buildNavigator(2)],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // バナー広告（広告スキップユーザーは非表示）
          if (!_isAdFreeUser) const BannerAdWidget(),

          // ボトムナビゲーションバー
          AppNavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: _onTabTapped,
            user: widget.user,
          ),
        ],
      ),
    );
  }
}
