/// Base interface for all state objects.
///
/// States should only contain persistent UI data and be immutable.
/// This interface serves as a marker for state objects used in the
/// MVI (Model-View-Intent) architecture pattern.
///
/// **Example:**
/// ```dart
/// class UserState extends BaseState {
///   final User? user;
///   final bool isLoading;
///
///   const UserState({this.user, this.isLoading = false});
///
///   UserState copyWith({User? user, bool? isLoading}) {
///     return UserState(
///       user: user ?? this.user,
///       isLoading: isLoading ?? this.isLoading,
///     );
///   }
/// }
/// ```
abstract class BaseState {
  /// Creates a new base state.
  const BaseState();
}

/// Base interface for all intent objects.
///
/// Intents represent user actions or system events that should
/// trigger state changes in the MVI architecture pattern.
///
/// **Example:**
/// ```dart
/// class LoadUserIntent extends BaseIntent {
///   final String userId;
///
///   const LoadUserIntent(this.userId);
/// }
///
/// class RefreshUserIntent extends BaseIntent {
///   const RefreshUserIntent();
/// }
/// ```
abstract class BaseIntent {
  /// Creates a new base intent.
  const BaseIntent();
}
