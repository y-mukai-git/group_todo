import '../constants/prohibited_words.dart';

/// コンテンツバリデーター
class ContentValidator {
  /// メールアドレスパターン
  static final _emailPattern = RegExp(
    r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
  );

  /// 電話番号パターン（日本）
  static final _phonePattern = RegExp(r'0\d{1,4}[-\s]?\d{1,4}[-\s]?\d{4}');

  /// コンテンツをバリデーション
  ///
  /// 戻り値:
  /// - null: 問題なし
  /// - String: エラーメッセージ
  static String? validate(String content) {
    // 個人情報チェック
    final personalInfoError = _checkPersonalInfo(content);
    if (personalInfoError != null) {
      return personalInfoError;
    }

    // NGワードチェック
    final ngWordError = _checkProhibitedWords(content);
    if (ngWordError != null) {
      return ngWordError;
    }

    return null; // OK
  }

  /// 個人情報パターンチェック
  static String? _checkPersonalInfo(String content) {
    if (_emailPattern.hasMatch(content)) {
      return '個人情報が含まれているため保存できません';
    }

    if (_phonePattern.hasMatch(content)) {
      return '個人情報が含まれているため保存できません';
    }

    return null;
  }

  /// NGワードチェック
  static String? _checkProhibitedWords(String content) {
    for (final word in ProhibitedWords.words) {
      if (content.contains(word)) {
        return '不適切な表現があるため保存できません';
      }
    }

    return null;
  }
}
