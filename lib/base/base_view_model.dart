import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';

import '../core.dart';

/// Defines the lifecycle callbacks for page widgets.
/// 
/// This interface provides a standardized set of lifecycle methods that
/// can be implemented by page widgets to handle various states of their
/// lifecycle from initialization to disposal.
abstract class PageLifecycle {
  /// Called when the page is first initialized.
  /// 
  /// This is the first lifecycle method called and is where you should
  /// perform one-time initialization tasks that don't require BuildContext.
  void onInit() {}
  /// Called after the widget has been built and is ready.
  /// 
  /// This method is called after the widget tree has been built and
  /// can be used for operations that require the widget to be fully
  /// initialized.
  void onReady() {}
  /// Called when the page becomes visible to the user.
  /// 
  /// This is triggered when the page is displayed on screen and can
  /// be used for starting animations, loading data, or other operations
  /// that should only run when the page is visible.
  void onVisible() {}
  /// Called when the page is no longer visible to the user.
  /// 
  /// This is triggered when the page is hidden from view and can be
  /// used for pausing operations, saving state, or cleaning up resources
  /// that are only needed when the page is visible.
  void onInVisible() {}

  /// Called when the widget physically enters the viewport.
  /// 
  /// This is different from [onVisible] as it's based on the actual
  /// visibility of the widget in the viewport, useful for performance
  /// optimizations.
  void onViewVisible() {}

  /// Called when the widget physically leaves the viewport.
  /// 
  /// This is different from [onInVisible] as it's based on the actual
  /// visibility of the widget in the viewport, useful for performance
  /// optimizations.
  void onViewInVisible() {}

  /// Called when the app is resumed from background.
  /// 
  /// This method is called when the app comes to the foreground and
  /// can be used for refreshing data, restarting operations, or other
  /// tasks that should run when the app becomes active.
  void onResume() {}
  /// Called when the app is paused or sent to background.
  /// 
  /// This method is called when the app goes to the background and
  /// can be used for pausing operations, saving state, or other cleanup
  /// tasks that should run when the app becomes inactive.
  void onPause() {}
  /// Called when the app becomes inactive.
  /// 
  /// This is called when the app is no longer in the foreground but
  /// hasn't been fully paused yet. Use this for operations that should
  /// stop when the app is not actively being used.
  void onInactive() {}
  /// Called when the page is about to be disposed.
  /// 
  /// This is the last lifecycle method called and should be used for
  /// cleanup tasks like canceling subscriptions, disposing controllers,
  /// and releasing resources to prevent memory leaks.
  void onDispose() {}
}

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

/// Interface for objects that maintain reactive state.
/// 
/// This interface defines the contract for state owners in the
/// MVI architecture pattern, providing access to the current state
/// and allowing state updates.
/// 
/// [S] is the type of state being managed.
/// 
/// **See Also:**
/// - [BaseViewModel] for the primary implementation
/// - [ViewModelMixin] for the mixin implementation
abstract class IStateOwner<S> {
  /// Gets the current state.
  /// 
  /// Returns the current state object of type [S].
  S get state;

  /// Sets the current state.
  /// 
  /// This setter is required to allow the mixin to update the state.
  /// Subclasses should implement this to update their internal state.
  set state(S value);
}

/// Base interface for all ViewModels in the MVI architecture.
/// 
/// This interface defines the contract for ViewModels that handle
/// business logic, state management, and lifecycle events.
/// 
/// [I] is the type of Intent this ViewModel can handle.
/// 
/// **Example:**
/// ```dart
/// class UserViewModel extends BaseViewModel<UserIntent> {
///   @override
///   Future<void> onIntent(UserIntent intent) async {
///     if (intent is LoadUserIntent) {
///       await _loadUser(intent.userId);
///     }
///   }
/// }
/// ```
/// 
/// **See Also:**
/// - [ViewModelMixin] for the complete implementation
/// - [PageLifecycle] for lifecycle methods
/// - [BaseState] for state objects
/// - [BaseIntent] for intent objects
abstract class BaseViewModel<I> implements PageLifecycle {
  /// Cancels all pending requests for this ViewModel.
  /// 
  /// [reason] is a descriptive message for why the requests are being cancelled.
  /// This is typically called during lifecycle events like [onDispose] or
  /// when navigating away from the page.
  void cancelRequests(String reason);

  /// Emits a one-time UI effect.
  /// 
  /// Effects are used for one-time events like showing dialogs,
  /// navigating to other screens, or displaying messages.
  /// 
  /// [effect] is the effect to be emitted.
  /// 
  /// **Example:**
  /// ```dart
  /// emitEffect(MessageEffect.success('User loaded successfully'));
  /// emitEffect(NavigationEffect.to('/profile'));
  /// ```
  void emitEffect(BaseEffect effect);

  /// Handles standard UI effects.
  /// 
  /// This method provides a default implementation for common effects
  /// like loading states, messages, and navigation. Subclasses can
  /// override this to handle custom effects.
  /// 
  /// [effect] is the effect to handle.
  /// Returns `true` if the effect was handled, `false` otherwise.
  bool handleEffect(BaseEffect effect);

  /// Unified entry point for all UI intents.
  /// 
  /// This method provides the main interface for sending intents to
  /// the ViewModel. Subclasses should implement their logic in [onIntent]
  /// instead of overriding this method.
  /// 
  /// [intent] is the intent to be processed.
  /// [useZone] can be used to manually override the default Zone policy.
  /// 
  /// **Example:**
  /// ```dart
  /// viewModel.handleIntent(LoadUserIntent('123'));
  /// ```
  FutureOr<void> handleIntent(I intent, {bool? useZone});

  /// Registers a handler for UI effects and manages its lifecycle.
  /// 
  /// This method allows you to subscribe to effect emissions and
  /// automatically manages the subscription lifecycle.
  /// 
  /// [handler] is the callback function that will be called when effects are emitted.
  /// The subscription will be automatically cancelled in [onDispose].
  /// 
  /// **Example:**
  /// ```dart
  /// onBindEffect((effect) {
  ///   if (effect is NavigationEffect) {
  ///     Navigator.pushNamed(context, effect.route);
  ///   }
  /// });
  /// ```
  void onBindEffect(void Function(BaseEffect effect) handler);
}

/// Mixin that provides the complete implementation for ViewModels.
/// 
/// This mixin handles common UI states, lifecycle logging, side effects,
/// and provides utilities for state management, event handling, and
/// request cancellation.
/// 
/// [S] is the State type that extends [BaseState].
/// [I] is the Intent type that extends [BaseIntent].
/// 
/// **Example:**
/// ```dart
/// class UserViewModel with ViewModelMixin<UserState, UserIntent> {
///   @override
///   UserState get state => _state;
///   @override
///   set state(UserState value) => _state = value;
///   
///   @override
///   Future<void> onIntent(UserIntent intent) async {
///     if (intent is LoadUserIntent) {
///       await call(
///         _userRepository.getUser(intent.userId),
///         onSuccess: (user) => updateState(state.copyWith(user: user)),
///         showLoading: true,
///       );
///     }
///   }
/// }
/// ```
/// 
/// **See Also:**
/// - [BaseViewModel] for the interface definition
/// - [PageLifecycle] for lifecycle methods
/// - [BaseState] for state objects
/// - [BaseIntent] for intent objects
mixin ViewModelMixin<S extends BaseState, I extends BaseIntent> implements BaseViewModel<I>, IStateOwner<S> {
  /// Gets the current state.
  /// 
  /// This getter must be implemented by the class using this mixin.
  /// It provides access to the current state object.
  @override
  S get state;

  /// Sets the current state.
  /// 
  /// This setter must be implemented by the class using this mixin.
  /// It allows the mixin to update the state when needed.
  @override
  set state(S value);

  /// Internal controller for managing effect streams.
  /// 
  /// This broadcast stream controller emits one-time UI effects
  /// like loading states, messages, and navigation events.
  final _effectController = StreamController<BaseEffect>.broadcast();
  
  /// Cancel token for managing HTTP requests.
  /// 
  /// This token is used to cancel all pending requests when the
  /// ViewModel is disposed or when manually calling [cancelRequests].
  CancelToken _cancelToken = CancelToken();

  /// Internal list to manage event bus subscriptions.
  /// 
  /// This list tracks all active subscriptions to ensure they are
  /// properly disposed when the ViewModel is destroyed, preventing
  /// memory leaks.
  final List<StreamSubscription> _eventSubscriptions = [];

  /// Internal stream for one-time UI effects.
  /// 
  /// This protected stream allows subclasses to listen to effect
  /// emissions if needed. Generally, effects should be handled through
  /// [onBindEffect] or [handleEffect].
  @protected
  Stream<BaseEffect> get effectStream => _effectController.stream;

  /// Gets the current cancel token for HTTP requests.
  /// 
  /// This property automatically creates a new cancel token if the
  /// current one has been cancelled, ensuring that subsequent requests
  /// can still be made.
  /// 
  /// Returns a [CancelToken] that can be used with Dio HTTP requests.
  CancelToken get cancelToken {
    if (_cancelToken.isCancelled) {
      _cancelToken = CancelToken();
    }
    return _cancelToken;
  }

  /// Subscribes to an event from the [EventBus] and manages its lifecycle.
  /// 
  /// This method provides a convenient way to subscribe to events
  /// without having to manually manage the subscription lifecycle.
  /// The subscription will be automatically cancelled in [onDispose].
  /// 
  /// [onData] is the callback function that handles the event.
  /// [key] is an optional filter to listen only for events with a specific key.
  /// [sticky] if true, emits the matching cached event immediately upon subscription.
  /// [where] is additional custom filtering logic.
  /// 
  /// **Example:**
  /// ```dart
  /// subscribeEvent<UserUpdatedEvent>((event) {
  ///   updateState(state.copyWith(user: event.user));
  /// });
  /// 
  /// subscribeEvent<SystemEvent>((event) {
  ///   if (event.type == SystemEventType.logout) {
  ///     emitEffect(LogoutEffect());
  ///   }
  /// }, key: 'system_events');
  /// ```
  @protected
  void subscribeEvent<T extends BaseEvent>(
    void Function(T event) onData, {
    String? key,
    bool sticky = false,
    bool Function(T event)? where,
  }) {
    final sub = eventBus.on<T>(onData, key: key, sticky: sticky, where: where);
    _eventSubscriptions.add(sub);
  }

  @override
  void onBindEffect(void Function(BaseEffect effect) handler) {
    _eventSubscriptions.add(effectStream.listen(handler));
  }

  /// Centralized state update method.
  /// 
  /// This method provides a safe way to update the state while
  /// logging the change and calling the state change hook.
  /// 
  /// [newState] is the new state to set.
  /// If the new state is the same as the current state, no update occurs.
  /// 
  /// **Example:**
  /// ```dart
  /// updateState(state.copyWith(isLoading: true));
  /// updateState(state.copyWith(user: user, isLoading: false));
  /// ```
  @protected
  void updateState(S newState) {
    if (newState == state) return;
    final oldState = state;
    state = newState;
    onStateChanged(oldState, newState);
  }

  /// Hook for observing state changes.
  /// 
  /// This method is called every time the state changes and can be
  /// overridden by subclasses to perform additional logic like
  /// persisting state, analytics, or debugging.
  /// 
  /// [oldState] is the previous state before the change.
  /// [newState] is the new state after the change.
  /// 
  /// **Example:**
  /// ```dart
  /// @override
  /// void onStateChanged(UserState oldState, UserState newState) {
  ///   super.onStateChanged(oldState, newState);
  ///   
  ///   // Log state changes for debugging
  ///   if (oldState.user != newState.user) {
  ///     appLogger.i('User changed from ${oldState.user?.id} to ${newState.user?.id}');
  ///   }
  /// }
  /// ```
  @protected
  void onStateChanged(S oldState, S newState) {
    appLogger.d('${runtimeType.toString()}: [STATE] $oldState -> $newState');
  }

  /// Emits a one-time UI effect.
  /// 
  /// This method sends an effect through the effect stream, which can
  /// be listened to by UI components or handled through [handleEffect].
  /// The effect emission is logged for debugging purposes.
  /// 
  /// [effect] is the effect to be emitted.
  /// 
  /// **Example:**
  /// ```dart
  /// emitEffect(LoadingEffect(true));
  /// emitEffect(MessageEffect.success('Operation completed'));
  /// emitEffect(NavigationEffect.to('/home'));
  /// ```
  @override
  void emitEffect(BaseEffect effect) {
    appLogger.d('${runtimeType.toString()}: [EFFECT] -> ${effect.toString()}');
    _effectController.add(effect);
  }

  /// Handles standard UI effects.
  /// 
  /// This method provides a default implementation for common effects
  /// by delegating to the [ProviderRegistry]. Subclasses can override
  /// this to handle custom effects or provide different behavior.
  /// 
  /// [effect] is the effect to handle.
  /// Returns `true` if the effect was handled, `false` otherwise.
  @override
  bool handleEffect(BaseEffect effect) {
    return ProviderRegistry.handle(effect);
  }

  /// Implementation of [handleIntent] that forces the use of [dispatch].
  /// 
  /// This method determines whether to use Zone execution based on
  /// the [useZone] parameter and the [shouldUseZone] method.
  /// The priority is: parameter [useZone] > method [shouldUseZone].
  /// 
  /// [intent] is the intent to be handled.
  /// [useZone] can manually override the default Zone policy.
  @override
  FutureOr<void> handleIntent(I intent, {bool? useZone}) {
    final effectiveUseZone = useZone ?? shouldUseZone(intent);
    return dispatch(intent, () => onIntent(intent), useZone: effectiveUseZone);
  }

  /// Determines whether to use Zone execution for a given intent.
  /// 
  /// Subclasses can override this method to disable Zone creation for
  /// high-frequency intents where Zone overhead might be undesirable.
  /// 
  /// [intent] is the intent being processed.
  /// Returns `true` if Zone execution should be used, `false` otherwise.
  /// 
  /// **Example:**
  /// ```dart
  /// @override
  /// bool shouldUseZone(UserIntent intent) {
  ///   // Don't use Zone for high-frequency intents like typing
  ///   if (intent is SearchTextChangedIntent) return false;
  ///   return super.shouldUseZone(intent);
  /// }
  /// ```
  @protected
  bool shouldUseZone(I intent) => true;

  /// Subclasses must implement this to handle specific intent logic.
  /// 
  /// This is the main method where business logic should be implemented.
  /// Each intent type should be handled appropriately with state updates
  /// and effect emissions as needed.
  /// 
  /// [intent] is the intent to be processed.
  /// 
  /// **Example:**
  /// ```dart
  /// @override
  /// Future<void> onIntent(UserIntent intent) async {
  ///   if (intent is LoadUserIntent) {
  ///     await _loadUser(intent.userId);
  ///   } else if (intent is UpdateUserIntent) {
  ///     await _updateUser(intent.user);
  ///   } else if (intent is DeleteUserIntent) {
  ///     await _deleteUser(intent.userId);
  ///   }
  /// }
  /// ```
  @protected
  FutureOr<void> onIntent(I intent);

  /// Executes a single action with automatic loading and error handling.
  /// 
  /// This method provides a convenient way to execute asynchronous actions
  /// with built-in loading states, error handling, and result processing.
  /// It's the preferred way to handle API calls and other async operations.
  /// 
  /// [T] is the success type.
  /// [action] is the asynchronous action to execute, returning an Either.
  /// [onFailure] is an optional callback for handling failures.
  /// [onSuccess] is the callback for handling successful results.
  /// [showLoading] controls whether to show a loading effect.
  /// [loadingType] determines the type of loading effect to show.
  /// [loadingMessage] is an optional custom loading message.
  /// 
  /// **Example:**
  /// ```dart
  /// await call(
  ///   _userRepository.getUser(userId),
  ///   onSuccess: (user) => updateState(state.copyWith(user: user)),
  ///   onFailure: (failure) => emitEffect(MessageEffect.error(failure.message)),
  ///   showLoading: true,
  ///   loadingMessage: 'Loading user...',
  /// );
  /// ```
  Future<void> call<T>(
    Future<Either<Failure, T>> action, {
    FutureOr<void> Function(Failure failure)? onFailure,
    required FutureOr<void> Function(T data) onSuccess,
    bool showLoading = false,
    LoadingType loadingType = LoadingType.both,
    String? loadingMessage,
  }) async {
    if (showLoading) emitEffect(LoadingEffect(true, message: loadingMessage, type: loadingType));
    try {
      final result = await action;
      await handleResult(result, onSuccess: onSuccess, onFailure: onFailure);
    } finally {
      if (showLoading) emitEffect(LoadingEffect(false));
    }
  }

  /// Executes multiple actions concurrently with automatic loading and error handling.
  /// 
  /// This method runs multiple actions in parallel using Future.wait and
  /// provides unified loading states and error handling. If any action fails,
  /// the first failure is reported.
  /// 
  /// [actions] is the list of asynchronous actions to execute.
  /// [onFailure] is an optional callback for handling failures.
  /// [onSuccess] is the callback for handling successful results.
  /// [showLoading] controls whether to show a loading effect.
  /// [loadingType] determines the type of loading effect to show.
  /// [loadingMessage] is an optional custom loading message.
  /// 
  /// **Example:**
  /// ```dart
  /// await callAll(
  ///   [_userRepository.getUser(userId), _userRepository.getProfile(userId)],
  ///   onSuccess: (results) {
  ///     final user = results[0] as User;
  ///     final profile = results[1] as Profile;
  ///     updateState(state.copyWith(user: user, profile: profile));
  ///   },
  ///   showLoading: true,
  /// );
  /// ```
  Future<void> callAll(
    List<Future<Either<Failure, dynamic>>> actions, {
    FutureOr<void> Function(Failure failure)? onFailure,
    required FutureOr<void> Function(List<dynamic> results) onSuccess,
    bool showLoading = false,
    LoadingType loadingType = LoadingType.both,
    String? loadingMessage,
  }) async {
    if (showLoading) emitEffect(LoadingEffect(true, message: loadingMessage, type: loadingType));
    try {
      final results = await Future.wait(actions);

      Failure? firstFailure;
      for (final r in results) {
        r.fold((f) => firstFailure ??= f, (_) {});
      }

      if (firstFailure != null) {
        if (onFailure != null) {
          await onFailure(firstFailure!);
        } else {
          handleFailure(firstFailure!);
        }
      } else {
        final dataList = results.map((r) => r.getOrElse((_) => throw Exception())).toList();
        await onSuccess(dataList);
      }
    } finally {
      if (showLoading) emitEffect(LoadingEffect(false));
    }
  }

  /// Helper method to handle Either results.
  /// 
  /// This method provides a convenient way to process Either results
  /// from use cases or other operations that return Either<Failure, T>.
  /// 
  /// [T] is the success type.
  /// [result] is the Either result to handle.
  /// [onFailure] is an optional callback for handling failures.
  /// [onSuccess] is the callback for handling successful results.
  /// 
  /// **Example:**
  /// ```dart
  /// final result = await _getUserUseCase.execute(userId);
  /// await handleResult(
  ///   result,
  ///   onSuccess: (user) => updateState(state.copyWith(user: user)),
  ///   onFailure: (failure) => emitEffect(MessageEffect.error(failure.message)),
  /// );
  /// ```
  FutureOr<void> handleResult<T>(
    Either<Failure, T> result, {
    FutureOr<void> Function(Failure failure)? onFailure,
    required FutureOr<void> Function(T data) onSuccess,
  }) async {
    await result.fold((failure) async {
      if (onFailure != null) {
        await onFailure(failure);
      } else {
        handleFailure(failure);
      }
    }, (data) async => await onSuccess(data));
  }

  /// Common failure handler with default behavior.
  /// 
  /// This method provides default handling for common failure types.
  /// Subclasses can override this to provide custom error handling
  /// or to handle additional failure types.
  /// 
  /// [failure] is the failure to handle.
  /// 
  /// Default behavior:
  /// - [AuthFailure]: Emits logout effect
  /// - [ServerApiFailure]: Shows error dialog
  /// - Other failures: Shows error message
  @protected
  void handleFailure(Failure failure) {
    if (failure is AuthFailure) {
      emitEffect(LogoutEffect(message: failure.message));
    } else if (failure is ServerApiFailure) {
      emitEffect(MessageEffect.dialog(failure.message, title: "API Error"));
    } else {
      emitEffect(MessageEffect.error(failure.message));
    }
  }

  /// Cancels all pending HTTP requests for this ViewModel.
  /// 
  /// This method cancels the current cancel token, which will cancel
  /// all HTTP requests that were made with this token. This is typically
  /// called during lifecycle events like [onDispose] or when navigating
  /// away from the page.
  /// 
  /// [reason] is a descriptive message for why the requests are being cancelled.
  /// 
  /// **Example:**
  /// ```dart
  /// // Called automatically in onDispose
  /// @override
  /// void onDispose() {
  ///   cancelRequests('ViewModel disposed');
  ///   super.onDispose();
  /// }
  /// ```
  @override
  void cancelRequests(String reason) {
    appLogger.i('${runtimeType.toString()} cancelRequests(${_cancelToken.isCancelled}) $reason');
    if (!_cancelToken.isCancelled) {
      _cancelToken.cancel(reason);
    }
  }

  /// Called when the page is first initialized.
  /// 
  /// This is the first lifecycle method called and is where you should
  /// perform one-time initialization tasks that don't require BuildContext.
  /// The method is logged for debugging purposes.
  @override
  void onInit() {
    appLogger.i('${runtimeType.toString()}: [LIFECYCLE] -> onInit');
  }

  /// Called after the widget has been built and is ready.
  /// 
  /// This method is called after the widget tree has been built and
  /// can be used for operations that require the widget to be fully
  /// initialized. The method is logged for debugging purposes.
  @override
  void onReady() {
    appLogger.i('${runtimeType.toString()}: [LIFECYCLE] -> onReady');
  }

  /// Called when the page becomes visible to the user.
  /// 
  /// This is triggered when the page is displayed on screen and can
  /// be used for starting animations, loading data, or other operations
  /// that should only run when the page is visible. The method is logged.
  @override
  void onVisible() {
    appLogger.i('${runtimeType.toString()}: [LIFECYCLE] -> onVisible');
  }

  /// Called when the page is no longer visible to the user.
  /// 
  /// This is triggered when the page is hidden from view and can
  /// be used for pausing operations, saving state, or cleaning up resources
  /// that are only needed when the page is visible. The method is logged.
  @override
  void onInVisible() {
    appLogger.i('${runtimeType.toString()}: [LIFECYCLE] -> onInVisible');
  }

  /// Called when the widget physically enters the viewport.
  /// 
  /// This is different from [onVisible] as it's based on the actual
  /// visibility of the widget in the viewport, useful for performance
  /// optimizations. The method is logged for debugging purposes.
  @override
  void onViewVisible() {
    appLogger.i('${runtimeType.toString()}: [LIFECYCLE] -> onViewVisible');
  }

  /// Called when the widget physically leaves the viewport.
  /// 
  /// This is different from [onInVisible] as it's based on the actual
  /// visibility of the widget in the viewport, useful for performance
  /// optimizations. The method is logged for debugging purposes.
  @override
  void onViewInVisible() {
    appLogger.i('${runtimeType.toString()}: [LIFECYCLE] -> onViewInVisible');
  }

  /// Called when the app is resumed from background.
  /// 
  /// This method is called when the app comes to the foreground and
  /// can be used for refreshing data, restarting operations, or other
  /// tasks that should run when the app becomes active. The method is logged.
  @override
  void onResume() {
    appLogger.i('${runtimeType.toString()}: [LIFECYCLE] -> onResume');
  }

  /// Called when the app is paused or sent to background.
  /// 
  /// This method is called when the app goes to the background and
  /// can be used for pausing operations, saving state, or other cleanup
  /// tasks that should run when the app becomes inactive. The method is logged.
  @override
  void onPause() {
    appLogger.i('${runtimeType.toString()}: [LIFECYCLE] -> onPause');
  }

  /// Called when the app becomes inactive.
  /// 
  /// This is called when the app is no longer in the foreground but
  /// hasn't been fully paused yet. Use this for operations that should
  /// stop when the app is not actively being used. The method is logged.
  @override
  void onInactive() {
    appLogger.i('${runtimeType.toString()}: [LIFECYCLE] -> onInactive');
  }

  /// Called when the page is about to be disposed.
  /// 
  /// This is the last lifecycle method called and should be used for
  /// cleanup tasks like canceling subscriptions, disposing controllers,
  /// and releasing resources to prevent memory leaks. This implementation
  /// automatically cancels requests and event subscriptions.
  /// 
  /// **Note:** This method is marked with `@mustCallSuper` to ensure
  /// subclasses call super.onDispose() to maintain proper cleanup.
  @override
  @mustCallSuper
  void onDispose() {
    appLogger.i('${runtimeType.toString()}: [LIFECYCLE] -> onDispose');
    cancelRequests('onDispose');

    // Automatically cancel all event bus subscriptions to prevent memory leaks.
    for (var sub in _eventSubscriptions) {
      sub.cancel();
    }
    _eventSubscriptions.clear();

    _effectController.close();
  }

  /// Low-level dispatcher that standardizes intent handling with Zone and logging.
  /// 
  /// This method provides the core intent processing infrastructure,
  /// including Zone management, performance tracking, and error handling.
  /// 
  /// [intent] is the intent being processed.
  /// [handler] is the function that contains the actual intent logic.
  /// [useZone] controls whether to execute within a Zone.
  /// 
  /// Returns a Future that completes when the intent processing is done.
  @protected
  Future<void> dispatch(dynamic intent, FutureOr<void> Function() handler, {bool useZone = true}) {
    final tag = runtimeType.toString();

    /// Called when intent processing starts.
    /// 
    /// Logs the intent and marks the start time for performance tracking.
    void onStart() {
      appLogger.d('$tag: [INTENT] -> $intent');
      ZoneManager.mark('Intent [$intent] Started');
    }

    /// Called when intent processing completes.
    /// 
    /// Logs the final state and marks the completion time for performance tracking.
    /// Also checks for injected crashes for testing purposes.
    void onComplete() {
      appLogger.d('$tag: [STATE] <- $state');
      CrashManager.checkAndTriggerInjectedCrash();
      ZoneManager.mark('Intent Finished');
    }

    /// Executes the intent handler with proper error handling.
    /// 
    /// This function wraps the handler execution with error handling
    /// and completion callbacks.
    Future<void> execute() {
      try {
        final result = handler();
        if (result is Future) {
          return result.then((_) => onComplete(), onError: (e, s) => throw e);
        } else {
          onComplete();
          return Future.value();
        }
      } catch (e) {
        rethrow;
      }
    }

    /// Execute without Zone if useZone is false.
    /// 
    /// This path is used for high-frequency intents where Zone overhead
    /// might be undesirable. Still performs logging and tracking.
    if (!useZone) {
      onStart();
      return execute();
    }

    /// Execute within Zone for proper error handling and tracking.
    /// 
    /// This is the default path that provides comprehensive error handling,
    /// performance tracking, and crash detection.
    return ZoneManager.run(() {
      onStart();
      return execute();
    }, cancelToken: cancelToken);
  }
}
