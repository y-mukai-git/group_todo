import 'package:flutter/material.dart';
import '../../data/models/user_model.dart';
import '../../presentation/widgets/banner_ad_widget.dart';
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
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(user: widget.user),
      GroupsScreen(user: widget.user),
      SettingsScreen(user: widget.user),
    ];
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // バナー広告
          const BannerAdWidget(),

          // ボトムナビゲーションバー
          NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: _onTabTapped,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'ホーム',
              ),
              NavigationDestination(
                icon: Icon(Icons.group_outlined),
                selectedIcon: Icon(Icons.group),
                label: 'グループ',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: '設定',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
