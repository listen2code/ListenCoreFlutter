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

/// Standard Effect for controlling global loading state.
class LoadingEffect extends BaseEffect {
  final bool show;
  final String? message;

  LoadingEffect(this.show, {this.message});

  @override
  String toString() {
    return "LoadingEffect(show: $show, message: $message)";
  }
}

/// Standard Effect for navigating to a new target reactively.
class NavigationEffect extends BaseEffect {
  /// The navigation target (Route path or Object). Can be null for back operations.
  final dynamic target;
  final bool isReplace;
  final bool isBack;
  final Object? arguments;
  final bool needLogin;

  NavigationEffect({
    this.target,
    this.isReplace = false,
    this.isBack = false,
    this.arguments,
    this.needLogin = false,
  });

  /// Helper constructor for back navigation.
  factory NavigationEffect.back({Object? result}) => NavigationEffect(isBack: true, arguments: result);

  @override
  String toString() {
    return "NavigationEffect(target: $target, isReplace: $isReplace, isBack: $isBack, needLogin: $needLogin, arguments: $arguments";
  }
}

/// Effect to trigger a global logout operation.
/// Typically emitted when an [AuthFailure] (like session timeout) occurs.
class LogoutEffect extends BaseEffect {
  final String? message;

  LogoutEffect({this.message});

  @override
  String toString() {
    return "LogoutEffect(message: $message)";
  }
}
