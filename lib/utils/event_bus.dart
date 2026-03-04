import 'dart:async';

/// Base class for all events dispatched via [EventBus].
/// Core architecture only provides the basic scheduling properties.
abstract class BaseEvent {
  final String key;
  final bool sticky;
  final bool autoClear;

  const BaseEvent(this.key, {this.sticky = false, this.autoClear = false});

  @override
  String toString() => '${runtimeType.toString()}(key: $key, sticky: $sticky, autoClear: $autoClear)';
}

/// A generic application event that can carry any typed data.
/// This replaces specific event types to keep the core library minimal and flexible.
class CommonEvent<T> extends BaseEvent {
  final T? data;
  const CommonEvent(super.key, {this.data, super.sticky, super.autoClear});

  @override
  String toString() => '${super.toString()}, data: $data';
}

/// A universal EventBus implementation based on [StreamController].
/// Simplified to use a single Map with [BaseEvent.key] as the unique identifier for sticky events.
class EventBus {
  // Singleton pattern
  static final EventBus _instance = EventBus._internal();
  factory EventBus() => _instance;

  EventBus._internal();

  /// Main stream controller for broadcasting events.
  final StreamController<BaseEvent> _controller = StreamController<BaseEvent>.broadcast();

  /// Simple flat map to store sticky events by their unique [key].
  final Map<String, BaseEvent> _stickyMap = {};

  /// Global interceptor for logging or debugging.
  void Function(BaseEvent event)? onEventFired;

  /// Initializes the EventBus with optional configurations.
  void init({void Function(BaseEvent event)? onEventFired}) {
    this.onEventFired = onEventFired;
  }

  // --- Fire Methods ---

  /// Fires an event.
  /// If [event.sticky] is true, it replaces any existing event with the same [event.key].
  void fire(BaseEvent event) {
    onEventFired?.call(event);
    if (event.sticky) {
      _stickyMap[event.key] = event;
    }
    _controller.add(event);
  }

  // --- Subscription Methods ---

  /// Subscribes to events of type [T].
  /// [key]: If provided, filters events by key.
  /// [sticky]: If true, it will emit the matching cached event immediately.
  /// [where]: Additional custom filtering logic.
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

    // 3. Handle Sticky emission.
    Stream<T> createStickyStream() async* {
      T? stickyEvent;
      if (key != null) {
        final e = _stickyMap[key];
        if (e is T) stickyEvent = e;
      } else {
        // Fallback: Find the last added event of type T.
        try {
          stickyEvent = _stickyMap.values.lastWhere((e) => e is T) as T?;
        } catch (_) {
          stickyEvent = null;
        }
      }

      if (stickyEvent != null && (where == null || where(stickyEvent))) {
        yield stickyEvent;
        // Optimization: Auto clear the sticky event if requested (consume-once behavior).
        if (stickyEvent.autoClear) {
          _stickyMap.remove(stickyEvent.key);
        }
      }
      yield* stream;
    }

    return createStickyStream().listen(onData);
  }

  // --- Management Methods ---

  /// Checks if a sticky event with [key] exists.
  bool hasSticky(String key) => _stickyMap.containsKey(key);

  /// Retrieves a sticky event by [key].
  BaseEvent? getSticky(String key) => _stickyMap[key];

  /// Removes a specific sticky event by [key].
  void removeSticky(String key) => _stickyMap.remove(key);

  /// Removes all sticky events that are instances of [T].
  void removeStickyByType<T extends BaseEvent>() {
    _stickyMap.removeWhere((k, v) => v is T);
  }

  /// Clears all stored sticky events.
  void clearAllSticky() => _stickyMap.clear();

  /// Closes the EventBus.
  void dispose() {
    clearAllSticky();
    _controller.close();
  }
}

/// Global convenience instance.
final eventBus = EventBus();
