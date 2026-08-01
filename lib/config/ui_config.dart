/// Configuration for default UI texts and strings in the Core library
class CoreUiConfig {
  /// Default title for API failure dialogs
  final String apiErrorTitle;

  /// Default message when session expires
  final String sessionExpiredMessage;

  /// Default message for loading screens/toasts
  final String loadingDefaultMessage;

  /// Default text for confirmation button
  final String okText;

  /// Default text for cancellation button
  final String cancelText;

  const CoreUiConfig({
    this.apiErrorTitle = 'API Error',
    this.sessionExpiredMessage = 'Session expired',
    this.loadingDefaultMessage = 'loading',
    this.okText = 'OK',
    this.cancelText = 'Cancel',
  });
}
