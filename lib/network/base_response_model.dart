/// A generic model for wrapping API responses with standard metadata.
class BaseResponseModel<T> {
  /// Constants for JSON keys to ensure consistency and avoid typos.
  static const String kResult = 'result';
  static const String kMessageId = 'messageId';
  static const String kMessage = 'message';
  static const String kBody = 'body';

  final String? result;
  final String? messageId;
  final String? message;
  final T? body;

  const BaseResponseModel({this.result, this.messageId, this.message, this.body});

  factory BaseResponseModel.fromJson(Map<String, dynamic> json, T Function(Object? json) fromJsonT) {
    return BaseResponseModel<T>(
      result: json[kResult] as String?,
      messageId: json[kMessageId] as String?,
      message: json[kMessage] as String?,
      body: json[kBody] == null ? null : fromJsonT(json[kBody]),
    );
  }

  Map<String, dynamic> toJson(Object? Function(T value) toJsonT) {
    return {
      kResult: result,
      kMessageId: messageId,
      kMessage: message,
      kBody: body == null ? null : toJsonT(body as T),
    };
  }
}
