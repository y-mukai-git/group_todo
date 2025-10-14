import 'package:uuid/uuid.dart';

/// エラーログモデル
class ErrorLogModel {
  final String id;
  final String? userId;
  final String errorType;
  final String errorMessage;
  final String? stackTrace;
  final String? screenName;
  final Map<String, dynamic>? deviceInfo;
  final DateTime createdAt;
  final bool isSent;

  ErrorLogModel({
    required this.id,
    this.userId,
    required this.errorType,
    required this.errorMessage,
    this.stackTrace,
    this.screenName,
    this.deviceInfo,
    required this.createdAt,
    this.isSent = false,
  });

  /// ファクトリーコンストラクタ（新規作成時）
  factory ErrorLogModel.create({
    String? userId,
    required String errorType,
    required String errorMessage,
    String? stackTrace,
    String? screenName,
    Map<String, dynamic>? deviceInfo,
  }) {
    return ErrorLogModel(
      id: const Uuid().v4(),
      userId: userId,
      errorType: errorType,
      errorMessage: errorMessage,
      stackTrace: stackTrace,
      screenName: screenName,
      deviceInfo: deviceInfo,
      createdAt: DateTime.now(),
      isSent: false,
    );
  }

  /// JSON → Model
  factory ErrorLogModel.fromJson(Map<String, dynamic> json) {
    return ErrorLogModel(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      errorType: json['error_type'] as String,
      errorMessage: json['error_message'] as String,
      stackTrace: json['stack_trace'] as String?,
      screenName: json['screen_name'] as String?,
      deviceInfo: json['device_info'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
      isSent: json['is_sent'] as bool? ?? false,
    );
  }

  /// Model → JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'error_type': errorType,
      'error_message': errorMessage,
      'stack_trace': stackTrace,
      'screen_name': screenName,
      'device_info': deviceInfo,
      'created_at': createdAt.toIso8601String(),
      'is_sent': isSent,
    };
  }

  /// 送信済みに更新
  ErrorLogModel markAsSent() {
    return ErrorLogModel(
      id: id,
      userId: userId,
      errorType: errorType,
      errorMessage: errorMessage,
      stackTrace: stackTrace,
      screenName: screenName,
      deviceInfo: deviceInfo,
      createdAt: createdAt,
      isSent: true,
    );
  }
}
