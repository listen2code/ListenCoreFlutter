import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';

import '../core.dart';

abstract class PageLifecycle {
  void onInit() {}
  void onReady() {}
  void onVisible() {}
  void onInVisible() {}

  /// Triggered when the widget physically enters the viewport.
  void onViewVisible() {}

  /// Triggered when the widget physically leaves the viewport.
  void onViewInVisible() {}

  void onResume() {}
  void onPause() {}
  void onInactive() {}
  void onDispose() {}
}

/// Interface for states. Should only contain persistent UI data.
abstract class BaseState {
  const BaseState();
}

abstract class BaseIntent {
  const BaseIntent();
}

/// Interface for any object that maintains a reactive state.
abstract class IStateOwner<S> {
  S get state;

  /// Required setter to allow the mixin to update the state.
  set state(S value);
}

/// Base interface for all ViewModels.
/// [I] is the type of Intent this ViewModel can handle.
abstract class BaseViewModel<I> implements PageLifecycle {
  void cancelRequests(String reason);

  void emitEffect(BaseEffect effect);

  /// Handles standard UI effects (Loading, Message, Navigation).
  bool handleEffect(BaseEffect effect);

  /// Unified entry point for all UI Intents.
  /// Subclasses should implementation logic in [onIntent] instead.
  /// [useZone] can be used to manually override the default Zone policy.
  FutureOr<void> handleIntent(I intent, {bool? useZone});

  /// Registers a handler for UI effects and manages its lifecycle internally.
  void onBindEffect(void Function(BaseEffect effect) handler);
}

/// Mixin to handle common UI states, lifecycle logging, and side effects.
/// [S] is the State type, [I] is the Intent type.
mixin ViewModelMixin<S extends BaseState, I extends BaseIntent> implements BaseViewModel<I>, IStateOwner<S> {
  @override
  S get state;

  @override
  set state(S value);

  final _effectController = StreamController<BaseEffect>.broadcast();
  CancelToken _cancelToken = CancelToken();

  /// Internal list to manage event bus subscriptions and ensure they are disposed.
  final List<StreamSubscription> _eventSubscriptions = [];

  /// Internal stream for one_time UI effects.
  @protected
  Stream<BaseEffect> get effectStream => _effectController.stream;

  CancelToken get cancelToken {
    if (_cancelToken.isCancelled) {
      _cancelToken = CancelToken();
    }
    return _cancelToken;
  }

  /// Subscribes to an event from the [EventBus] and manages its lifecycle.
  /// [key]: Optional filter to listen only for events with a specific key.
  /// [sticky]: If true, it will emit the matching cached event immediately upon subscription.
  /// [where]: Additional custom filtering logic.
  /// The subscription will be automatically cancelled in [onDispose].
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
  @protected
  void updateState(S newState) {
    if (newState == state) return;
    final oldState = state;
    state = newState;
    onStateChanged(oldState, newState);
  }

  /// Hook for observing state changes.
  @protected
  void onStateChanged(S oldState, S newState) {
    appLogger.d('${runtimeType.toString()}: [STATE] $oldState -> $newState');
  }

  @override
  void emitEffect(BaseEffect effect) {
    appLogger.d('${runtimeType.toString()}: [EFFECT] -> ${effect.toString()}');
    _effectController.add(effect);
  }

  @override
  bool handleEffect(BaseEffect effect) {
    return ProviderRegistry.handle(effect);
  }

  /// Implementation of [handleIntent] that forces the use of [dispatch].
  /// The priority of Zone policy is: Parameter [useZone] > Method [shouldUseZone].
  @override
  FutureOr<void> handleIntent(I intent, {bool? useZone}) {
    final effectiveUseZone = useZone ?? shouldUseZone(intent);
    return dispatch(intent, () => onIntent(intent), useZone: effectiveUseZone);
  }

  /// Subclasses can override this to disable Zone creation for high_frequency intents.
  @protected
  bool shouldUseZone(I intent) => true;

  /// Subclasses must implement this to handle specific intent logic.
  @protected
  FutureOr<void> onIntent(I intent);

  /// Executes a single action and handles result/loading.
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

  /// Executes multiple actions concurrently using Future.wait.
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

  /// Helper to handle Either results.
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

  /// Common failure handler. Can be overridden by subclasses for custom error handling.
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

  @override
  void cancelRequests(String reason) {
    appLogger.i('${runtimeType.toString()} cancelRequests(${_cancelToken.isCancelled}) $reason');
    if (!_cancelToken.isCancelled) {
      _cancelToken.cancel(reason);
    }
  }

  @override
  void onInit() {
    appLogger.i('${runtimeType.toString()}: [LIFECYCLE] -> onInit');
  }

  @override
  void onReady() {
    appLogger.i('${runtimeType.toString()}: [LIFECYCLE] -> onReady');
  }

  @override
  void onVisible() {
    appLogger.i('${runtimeType.toString()}: [LIFECYCLE] -> onVisible');
  }

  @override
  void onInVisible() {
    appLogger.i('${runtimeType.toString()}: [LIFECYCLE] -> onInVisible');
  }

  @override
  void onViewVisible() {
    appLogger.i('${runtimeType.toString()}: [LIFECYCLE] -> onViewVisible');
  }

  @override
  void onViewInVisible() {
    appLogger.i('${runtimeType.toString()}: [LIFECYCLE] -> onViewInVisible');
  }

  @override
  void onResume() {
    appLogger.i('${runtimeType.toString()}: [LIFECYCLE] -> onResume');
  }

  @override
  void onPause() {
    appLogger.i('${runtimeType.toString()}: [LIFECYCLE] -> onPause');
  }

  @override
  void onInactive() {
    appLogger.i('${runtimeType.toString()}: [LIFECYCLE] -> onInactive');
  }

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

  /// Low_level dispatcher. standardizes intent handling with Zone and logging.
  @protected
  Future<void> dispatch(dynamic intent, FutureOr<void> Function() handler, {bool useZone = true}) {
    final tag = runtimeType.toString();

    void onStart() {
      appLogger.d('$tag: [INTENT] -> $intent');
      ZoneManager.mark('Intent [$intent] Started');
    }

    void onComplete() {
      appLogger.d('$tag: [STATE] <- $state');
      CrashManager.checkAndTriggerInjectedCrash();
      ZoneManager.mark('Intent Finished');
    }

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

    if (!useZone) {
      onStart();
      return execute();
    }

    return ZoneManager.run(() {
      onStart();
      return execute();
    }, cancelToken: cancelToken);
  }
}
