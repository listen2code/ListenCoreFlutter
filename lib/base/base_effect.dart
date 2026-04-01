/// Interface for UI Side Effects (Toast, Navigation, etc.) that occur once.
abstract class BaseEffect {}

/// Message type for NotificationEffect
enum MessageType { info, error, dialog }

/// Standard Effect for showing messages/toasts or dialogs.
class MessageEffect extends BaseEffect {
  final String message;
  final String? title;
  final MessageType type;

  MessageEffect(this.message, {this.title, this.type = MessageType.info});

  /// Factory for info messages (usually shown as Toast)
  factory MessageEffect.info(String message) => MessageEffect(message, type: MessageType.info);

  /// Factory for error messages (usually shown as Toast)
  factory MessageEffect.error(String message) => MessageEffect(message, type: MessageType.error);

  /// Factory for dialog messages
  factory MessageEffect.dialog(String message, {String? title}) =>
      MessageEffect(message, title: title, type: MessageType.dialog);

  @override
  String toString() {
    return "MessageEffect(message: $message, title: $title, type: $type)";
  }
}

enum LoadingType { dialog, page, both }

/// Standard Effect for controlling global loading state.
class LoadingEffect extends BaseEffect {
  final bool show;
  final String? message;
  final LoadingType? type;

  LoadingEffect(this.show, {this.message, this.type = LoadingType.dialog});

  @override
  String toString() {
    return "LoadingEffect(show: $show, message: $message, type: $type)";
  }
}

/// Standard Effect for controlling the display of an empty state placeholder.
class EmptyEffect extends BaseEffect {
  final bool show;
  final String? message;

  EmptyEffect(this.show, {this.message});

  @override
  String toString() {
    return "EmptyEffect(show: $show, message: $message)";
  }
}

/// Effect to trigger a global logout operation.
/// Typically emitted when an [AuthFailure] (like session timeout) occurs.
class LogoutEffect extends BaseEffect {
  final String? message;
  final String? to;

  LogoutEffect({this.message, this.to});

  @override
  String toString() {
    return "LogoutEffect(message: $message, to: $to)";
  }
}
