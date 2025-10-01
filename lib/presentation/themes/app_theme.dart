import 'package:flutter/material.dart';

/// アプリ全体のテーマ定義（Material Design 3）
/// アイコンに合わせたダークブルー・グレー基調のシックなデザイン
class AppTheme {
  // カラースキーマ（グループTODOテーマカラー - ダークブルー・グレー系）
  static const Color primaryColor = Color(0xFF5A6978); // ミディアムブルーグレー（薄め）
  static const Color secondaryColor = Color(0xFF6B7A89); // ライトグレー
  static const Color tertiaryColor = Color(0xFFFF9F43); // アクセントオレンジ（チェックマーク）
  static const Color errorColor = Color(0xFFE53935);
  static const Color backgroundColor = Color(0xFFF5F7FA); // ライトグレー背景
  static const Color surfaceColor = Color(0xFFFFFFFF);

  /// ライトテーマ
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        error: errorColor,
      ),

      // AppBar設定（ヘッダー）
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 3,
        backgroundColor: primaryColor, // ヘッダー背景色
        foregroundColor: Colors.white, // ヘッダー文字色
      ),

      // ボトムナビゲーションバー設定（フッター）
      navigationBarTheme: NavigationBarThemeData(
        height: 65,
        elevation: 3,
        backgroundColor: primaryColor, // フッター背景色（ヘッダーと統一）
        indicatorColor: secondaryColor, // 選択中アイコン背景
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(size: 28, color: Colors.white);
          }
          return IconThemeData(size: 24, color: Colors.white.withOpacity(0.7));
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(fontSize: 12, color: Colors.white);
          }
          return TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7));
        }),
      ),

      // FloatingActionButton設定
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 3,
        shape: CircleBorder(),
      ),

      // Card設定
      cardTheme: const CardThemeData(
        elevation: 1,
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // Checkbox設定
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      // InputDecoration設定
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),

      // Divider設定
      dividerTheme: const DividerThemeData(thickness: 1, space: 1),
    );
  }

  /// ダークテーマ（アイコンのダークブルー基調）
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
        error: errorColor,
        surface: const Color(0xFF1C2530), // ダークブルー背景
        onSurface: const Color(0xFFE8EBF0), // ライトグレー文字
      ),

      // AppBar設定（ヘッダー）
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 3,
        backgroundColor: Color(0xFF1C2530), // ヘッダー背景色
        foregroundColor: Color(0xFFE8EBF0), // ヘッダー文字色
      ),

      // ボトムナビゲーションバー設定（フッター）
      navigationBarTheme: NavigationBarThemeData(
        height: 65,
        elevation: 3,
        backgroundColor: Color(0xFF1C2530), // フッター背景色（ヘッダーと統一）
        indicatorColor: Color(0xFF2C3A48), // 選択中アイコン背景
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(size: 28, color: Color(0xFFE8EBF0));
          }
          return const IconThemeData(size: 24, color: Color(0xFF9CA3AF));
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(fontSize: 12, color: Color(0xFFE8EBF0));
          }
          return const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF));
        }),
      ),

      // FloatingActionButton設定
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 3,
        shape: CircleBorder(),
      ),

      // Card設定
      cardTheme: const CardThemeData(
        elevation: 1,
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // Checkbox設定
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      // InputDecoration設定
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),

      // Divider設定
      dividerTheme: const DividerThemeData(thickness: 1, space: 1),
    );
  }
}
