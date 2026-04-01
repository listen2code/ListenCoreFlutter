/// Configuration for API response structure and codes
class ResponseConfig {
  // JSON Field Keys
  final String resultKey;
  final String messageIdKey;
  final String messageKey;
  final String bodyKey;

  // API Result Codes
  final String success;
  final String serverError;
  final String sessionTimeout;

  const ResponseConfig({
    this.resultKey = 'result',
    this.messageIdKey = 'messageId',
    this.messageKey = 'message',
    this.bodyKey = 'body',
    this.success = "0",
    this.serverError = "1",
    this.sessionTimeout = "3",
  });
}
