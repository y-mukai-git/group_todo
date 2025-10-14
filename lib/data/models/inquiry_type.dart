/// お問い合わせ種別
enum InquiryType {
  /// 不具合報告
  bugReport('bug_report', '不具合報告'),

  /// 機能要望
  featureRequest('feature_request', '機能要望'),

  /// その他
  other('other', 'その他');

  const InquiryType(this.value, this.displayName);

  /// データベース保存用の値
  final String value;

  /// 表示名
  final String displayName;

  /// 値から InquiryType を取得
  static InquiryType fromValue(String value) {
    return InquiryType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => InquiryType.other,
    );
  }
}
