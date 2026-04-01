import '../core.dart';

/// A generic model for wrapping API responses with standard metadata.
class BaseResponseModel<T> {
  /// Constants for JSON keys to ensure consistency and avoid typos.
  static String resultKey = 'result';
  static String messageIdKey = 'messageId';
  static String messageKey = 'message';
  static String bodyKey = 'body';

  final String? result;
  final String? messageId;
  final String? message;
  final T? body;

  const BaseResponseModel({this.result, this.messageId, this.message, this.body});

  /// Initialize configuration
  static void initConfig(ResponseConfig config) {
    resultKey = config.resultKey;
    messageIdKey = config.messageIdKey;
    messageKey = config.messageKey;
    bodyKey = config.bodyKey;
    ApiResult.updateConfig(config);
  }

  factory BaseResponseModel.fromJson(Map<String, dynamic> json, T Function(Object? json) fromJsonT) {
    return BaseResponseModel<T>(
      result: json[resultKey] as String?,
      messageId: json[messageIdKey] as String?,
      message: json[messageKey] as String?,
      body: json[bodyKey] == null ? null : fromJsonT(json[bodyKey]),
    );
  }

  Map<String, dynamic> toJson(Object? Function(T value) toJsonT) {
    return {
      resultKey: result,
      messageIdKey: messageId,
      messageKey: message,
      bodyKey: body == null ? null : toJsonT(body as T),
    };
  }
}

class ApiResult {
  ApiResult._();

  static String success = "0";
  static String serverError = "1";
  static String sessionTimeout = "3";

  static void updateConfig(ResponseConfig config) {
    success = config.success;
    serverError = config.serverError;
    sessionTimeout = config.sessionTimeout;
  }
}
