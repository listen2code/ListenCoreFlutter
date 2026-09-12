import 'dart:async';

/// Abstract base class for all application events dispatched through [EventBus].
///
/// Encapsulates routing identity ([key]) and delivery scheduling policies ([sticky] and [autoClear]).
///
/// ### Architectural Scope:
/// While [BaseEffect] is designed strictly for 1-to-1, local ViewModel-to-View ephemeral UI actions,
/// [BaseEvent] subclasses are intended for **1-to-Many (Pub-Sub) cross-module broadcasting** across
/// decoupled architectural boundaries (e.g. system network changes, authentication session expiry,
/// deep link wakeups, or push notification payloads).
abstract class BaseEvent {
  /// Unique semantic key used to filter and categorize events (e.g. `DeepLinkManager.deepLinkEventKey`).
  final String key;

  /// Whether this event should be retained in the in-memory sticky cache.
  ///
  /// If `true`, the event is saved in [_stickyMap] and will be immediately replayed
  /// to any future subscriber that registers with `sticky: true`, bridging initialization timing gaps
  /// (e.g., cold-start deep links fired before the UI widget tree finishes building).
  final bool sticky;

  /// Whether this sticky event should be automatically purged from the cache upon first consumption.
  ///
  /// When `true`, the first subscriber that consumes this sticky event deletes it from [_stickyMap],
  /// providing **exactly-once sticky delivery** and preventing duplicate downstream actions
  /// (such as re-triggering deep link navigation when subsequent pages or rebuilds occur).
  final bool autoClear;

  const BaseEvent(this.key, {this.sticky = false, this.autoClear = false});

  @override
  String toString() => '${runtimeType.toString()}(key: $key, sticky: $sticky, autoClear: $autoClear)';
}

/// A generic, strongly-typed event wrapper that can transport arbitrary payloads.
///
/// Eliminates the boilerplate of creating concrete classes for every minor notification
/// while preserving compile-time type safety via the generic parameter [T].
///
/// **Example:**
/// ```dart
/// eventBus.fire(CommonEvent<Uri>('deep_link', data: uri, sticky: true, autoClear: true));
/// ```
class CommonEvent<T> extends BaseEvent {
  /// The optional strongly-typed payload associated with this event.
  final T? data;

  const CommonEvent(super.key, {this.data, super.sticky, super.autoClear});

  @override
  String toString() => '${super.toString()}, data: $data';
}

/// Centralized, asynchronous Publish-Subscribe event bus powered by Dart's [StreamController.broadcast].
///
/// ### Core Capabilities:
/// 1. **Cross-Module Decoupling**: Allows publishers (e.g. background services, network interceptors)
///    to notify multiple interested subscribers (e.g. active ViewModels, logging observers) without
///    maintaining direct object references.
/// 2. **Sticky Replay Buffer**: Bridges temporal gaps where an event occurs before the subscriber
///    component is mounted (essential for cold-start deep linking and push notification clicks).
/// 3. **Type and Key Filtering**: Allows subscribers to listen for specific event types ([T]),
///    specific string keys ([key]), or arbitrary predicate expressions ([where]).
/// 4. **Lifecycle Safety**: Pair with `BaseViewModel.subscribeEvent` to ensure all subscriptions
///    are automatically cancelled on ViewModel disposal, eliminating memory leaks.
class EventBus {
  // Thread-safe singleton pattern
  static final EventBus _instance = EventBus._internal();
  factory EventBus() => _instance;

  EventBus._internal();

  /// Primary broadcast stream controller delivering events to active listeners.
  final StreamController<BaseEvent> _controller = StreamController<BaseEvent>.broadcast();

  /// In-memory sticky cache indexed by [BaseEvent.key].
  final Map<String, BaseEvent> _stickyMap = {};

  /// Optional global observation hook for APM monitoring, logging, or tracing.
  void Function(BaseEvent event)? onEventFired;

  /// Initializes the EventBus with an optional global audit hook.
  void init({void Function(BaseEvent event)? onEventFired}) {
    this.onEventFired = onEventFired;
  }

  // --- Fire Methods ---

  /// Dispatches [event] to all active broadcast subscribers.
  ///
  /// If [event.sticky] is `true`, it is simultaneously stored in [_stickyMap] (replacing any
  /// prior event with the same key) to be replayed to future subscribers.
  void fire(BaseEvent event) {
    onEventFired?.call(event);
    if (event.sticky) {
      _stickyMap[event.key] = event;
    }
    _controller.add(event);
  }

  // --- Subscription Methods ---

  /// Subscribes to events of concrete type [T].
  ///
  /// - [onData]: Callback invoked whenever a matching event is received.
  /// - [key]: Optional identifier to filter events having this exact [BaseEvent.key].
  /// - [sticky]: If `true`, checks the sticky cache upon subscription and immediately yields
  ///   any matching cached event before continuing to listen for live broadcasts.
  /// - [where]: Optional predicate for fine-grained event filtering.
  ///
  /// Returns a [StreamSubscription] that **must be cancelled** when the listener is destroyed,
  /// or managed automatically via `BaseViewModel.subscribeEvent`.
  StreamSubscription<T> on<T extends BaseEvent>(
    void Function(T event) onData, {
    String? key,
    bool sticky = false,
    bool Function(T event)? where,
  }) {
    // 1. Setup the basic stream with type filtering.
    Stream<T> stream = _controller.stream.where((event) => event is T).cast<T>();

    // 2. Apply key and custom filters.
    if (key != null) stream = stream.where((event) => event.key == key);
    if (where != null) stream = stream.where(where);

    if (!sticky) return stream.listen(onData);

    // 3. Handle Sticky emission via an asynchronous generator (async*).
    Stream<T> createStickyStream() async* {
      T? stickyEvent;
      if (key != null) {
        final e = _stickyMap[key];
        if (e is T) stickyEvent = e;
      } else {
        // Fallback: Find the most recently cached event matching type T.
        try {
          stickyEvent = _stickyMap.values.lastWhere((e) => e is T) as T?;
        } catch (_) {
          stickyEvent = null;
        }
      }

      if (stickyEvent != null && (where == null || where(stickyEvent))) {
        yield stickyEvent;
        // Optimization: Auto-clear sticky event if requested (consume-once semantics).
        if (stickyEvent.autoClear) {
          _stickyMap.remove(stickyEvent.key);
        }
      }
      // Delegate all subsequent live events to the primary broadcast stream.
      yield* stream;
    }

    return createStickyStream().listen(onData);
  }

  // --- Management Methods ---

  /// Checks if a sticky event with [key] currently exists in the cache.
  bool hasSticky(String key) => _stickyMap.containsKey(key);

  /// Retrieves the cached sticky event for [key], or `null` if none exists.
  BaseEvent? getSticky(String key) => _stickyMap[key];

  /// Manually removes a specific sticky event by its [key].
  void removeSticky(String key) => _stickyMap.remove(key);

  /// Removes all sticky events that are instances of type [T].
  void removeStickyByType<T extends BaseEvent>() {
    _stickyMap.removeWhere((k, v) => v is T);
  }

  /// Clears all retained sticky events from memory.
  void clearAllSticky() => _stickyMap.clear();

  /// Disposes the EventBus, clearing the sticky cache and closing the broadcast controller.
  void dispose() {
    clearAllSticky();
    _controller.close();
  }
}

/// Global convenience singleton accessor for [EventBus].
final eventBus = EventBus();
