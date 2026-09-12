/// Base interface for all transient, one-time UI side effects in the MVI architecture.
///
/// ### Architectural Role & Comparison with State:
/// - **State ([BaseState])**: Represents persistent data that survives widget rebuilds and screen rotations
///   (e.g., loaded lists, form input values, current user details). Consumed continuously via reactive builders.
/// - **Effect ([BaseEffect])**: Represents ephemeral, one-shot instructions that must be executed
///   **exactly once** and should never be replayed on widget rebuilds (e.g., displaying a Toast message,
///   opening a modal dialog, triggering haptic feedback, or requesting page navigation).
///
/// ### Scope and Consumption:
/// While [EventBus] broadcasts 1-to-Many events across the entire application without lifecycle bounds,
/// [BaseEffect] is **strictly 1-to-1 and local to a single page's lifecycle**.
/// In `BaseLifecyclePage`, the page's effect subscription is automatically managed via `onBindEffect`,
/// ensuring that when a page exits (e.g. during a 300ms pop/replacement transition), its effect channel
/// is synchronously unregistered to prevent "ghost dialogs" or duplicate side-effect execution.
abstract class BaseEffect {}

/// Categorization of message presentation styles for [MessageEffect].
enum MessageType {
  /// Light-weight, self-dismissing snackbar or toast notification.
  info,

  /// Error-styled toast or floating alert banner.
  error,

  /// Modal alert dialog requiring explicit user dismissal or action.
  dialog,
}

/// Standard effect for displaying user-facing messages, toasts, or modal alert dialogs.
///
/// Supported by `BaseViewModel.handleFailure` and default UI presentation binders.
class MessageEffect extends BaseEffect {
  /// The localized or technical text content to be displayed.
  final String message;

  /// Optional title for modal dialog representations.
  final String? title;

  /// Presentation tier (toast, error toast, or modal dialog).
  final MessageType type;

  MessageEffect(this.message, {this.title, this.type = MessageType.info});

  /// Convenience factory for informational toasts/snackbars.
  factory MessageEffect.info(String message) => MessageEffect(message, type: MessageType.info);

  /// Convenience factory for error-styled toasts/snackbars.
  factory MessageEffect.error(String message) => MessageEffect(message, type: MessageType.error);

  /// Convenience factory for modal alert dialogs.
  factory MessageEffect.dialog(String message, {String? title}) =>
      MessageEffect(message, title: title, type: MessageType.dialog);

  @override
  String toString() {
    return "MessageEffect(message: $message, title: $title, type: $type)";
  }
}

/// Rendering modes for [LoadingEffect].
enum LoadingType {
  /// Fullscreen or centered modal loading dialog blocking user interaction.
  dialog,

  /// In-page placeholder or skeleton shimmer loading.
  page,

  /// Both dialog overlay and inline page loading indicator.
  both,
}

/// Standard effect for showing or dismissing loading overlays during asynchronous operations.
class LoadingEffect extends BaseEffect {
  /// `true` to display the loading indicator, `false` to dismiss it.
  final bool show;

  /// Optional message to display alongside the spinner (e.g. "Saving changes...").
  final String? message;

  /// Visual presentation style for the loading state.
  final LoadingType? type;

  LoadingEffect(this.show, {this.message, this.type = LoadingType.dialog});

  @override
  String toString() {
    return "LoadingEffect(show: $show, message: $message, type: $type)";
  }
}

/// Standard effect for toggling empty state illustrations or placeholders when query results are empty.
class EmptyEffect extends BaseEffect {
  /// Whether to display the empty placeholder.
  final bool show;

  /// Optional hint message for the empty state view.
  final String? message;

  EmptyEffect(this.show, {this.message});

  @override
  String toString() {
    return "EmptyEffect(show: $show, message: $message)";
  }
}

/// Standard effect emitted to initiate a global session logout and redirect.
///
/// Typically dispatched by `BaseViewModel.handleFailure` upon catching an [AuthFailure],
/// or manually triggered when the user taps "Log Out".
/// Handled by `LogoutProviderImpl` to clear secure credentials and reset navigation stacks.
class LogoutEffect extends BaseEffect {
  /// Optional alert message describing why the session ended (e.g. "Session expired").
  final String? message;

  /// Optional target route to navigate to after credentials are wiped.
  final String? to;

  LogoutEffect({this.message, this.to});

  @override
  String toString() {
    return "LogoutEffect(message: $message, to: $to)";
  }
}
