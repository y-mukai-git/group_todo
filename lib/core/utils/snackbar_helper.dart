import 'package:flutter/material.dart';

/// スナックバー表示ヘルパークラス
///
/// 同じメッセージのスナックバーが重複して表示されるのを防ぐ。
/// duration経過後に自動的に追跡から削除される。
class SnackBarHelper {
  /// 現在表示中のメッセージを追跡するSet
  static final Set<String> _activeMessages = {};

  /// スナックバーを表示する
  ///
  /// 同じメッセージが既に表示中の場合は新規表示を無視する。
  ///
  /// [context] BuildContext
  /// [message] 表示するメッセージ
  /// [backgroundColor] 背景色（省略可）
  /// [duration] 表示時間（デフォルト: 4秒）
  /// [clearPrevious] trueの場合、既存のスナックバーをクリアしてから表示
  static void showSnackBar(
    BuildContext context,
    String message, {
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 4),
    bool clearPrevious = false,
  }) {
    // 既存のスナックバーをクリアする場合
    if (clearPrevious) {
      ScaffoldMessenger.of(context).clearSnackBars();
      _activeMessages.clear();
    }

    // 同じメッセージが既に表示中なら無視
    if (_activeMessages.contains(message)) {
      return;
    }

    // メッセージを追跡に追加
    _activeMessages.add(message);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: duration,
      ),
    );

    // duration経過後にメッセージをクリア
    Future.delayed(duration, () {
      _activeMessages.remove(message);
    });
  }

  /// 成功メッセージを表示する
  ///
  /// 背景色を緑色に設定した[showSnackBar]のラッパー。
  static void showSuccessSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    bool clearPrevious = false,
  }) {
    showSnackBar(
      context,
      message,
      backgroundColor: Colors.green,
      duration: duration,
      clearPrevious: clearPrevious,
    );
  }

  /// エラーメッセージを表示する
  ///
  /// 背景色をエラー色に設定した[showSnackBar]のラッパー。
  static void showErrorSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    showSnackBar(
      context,
      message,
      backgroundColor: Theme.of(context).colorScheme.error,
      duration: duration,
    );
  }
}
