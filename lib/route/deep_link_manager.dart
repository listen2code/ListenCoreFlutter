import 'dart:async';

import 'package:app_links/app_links.dart';

import '../utils/event_bus.dart';
import '../utils/logger.dart';

/// Business-agnostic manager to handle incoming deep links cleanly using the `app_links` package.
///
/// ### Architecture & Lifecycle:
/// 1. **Cold Start (Launch from Deep Link)**:
///    When the application is launched by an external deep link, [init] queries [AppLinks.getInitialLink].
///    To avoid race conditions where the UI or async dependencies (like `SpUtil`, Riverpod providers,
///    or local databases) are not fully initialized, the URI is dispatched as a **sticky event**
///    via [EventBus]. Once the target container (e.g., `HomeViewModel`) mounts, it receives the
///    cached event and safely handles navigation without dropping or prematurely firing routes.
///
/// 2. **Warm / Hot Start (Foreground / Background Link Arrival)**:
///    When the app is already in memory or running in the foreground, [AppLinks.uriLinkStream] emits
///    the incoming URI. It is routed through [_handleUri] and dispatched via [EventBus].
///
/// 3. **Interception Hook**:
///    Host applications can register [onLinkReceived] to consume specific links (e.g., in-app web views,
///    analytics, or marketing banners) prior to global navigation routing.
class DeepLinkManager {
  DeepLinkManager._();

  /// Singleton instance of DeepLinkManager.
  static final DeepLinkManager instance = DeepLinkManager._();

  /// The unique [EventBus] key for Deep Link events.
  static const String deepLinkEventKey = 'deepLinkEventKey';

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  /// Hook invoked when a deep link is received.
  ///
  /// Return `true` to consume the event and prevent standard [EventBus] dispatching.
  /// Return `false` to allow normal routing through [deepLinkEventKey].
  FutureOr<bool> Function(Uri uri)? onLinkReceived;

  /// Initializes deep link listeners for both hot-start streams and cold-start initial links.
  /// Should be called after core dependencies and storage providers are initialized.
  Future<void> init() async {
    // 1. Handle hot start deep links (while running or in background)
    _linkSubscription?.cancel();
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) async {
        appLogger.i('DeepLinkManager: Hot start link detected: $uri');
        await _handleUri(uri);
      },
      onError: (err) {
        appLogger.e('DeepLinkManager: Link stream error', error: err);
      },
    );

    // 2. Handle cold start deep link (if launched via deep link)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        appLogger.i('DeepLinkManager: Cold start link detected: $initialUri');
        await _handleUri(initialUri);
      }
    } catch (e, stack) {
      appLogger.e('DeepLinkManager: Failed to parse initial link', error: e, stackTrace: stack);
    }
  }

  /// Dispatches the incoming [uri] through [EventBus] as a sticky, auto-clearing event.
  /// [sticky] ensures late-subscribing view models receive cold-start links.
  /// [autoClear] ensures the event is consumed only once to prevent duplicate navigations.
  void _fireEvent(Uri uri) {
    EventBus().fire(CommonEvent<Uri>(deepLinkEventKey, data: uri, sticky: true, autoClear: true));
  }

  /// Internal handler that delegates to [onLinkReceived] if provided,
  /// otherwise fires the deep link event to the [EventBus].
  Future<void> _handleUri(Uri uri) async {
    if (onLinkReceived != null) {
      final handled = await onLinkReceived!(uri);
      if (handled) return;
    }
    _fireEvent(uri);
  }

  /// Manually triggers deep link processing for integration and unit testing.
  Future<void> handleUriForTesting(Uri uri) => _handleUri(uri);

  /// Cancels active link subscriptions and releases resources.
  void dispose() {
    _linkSubscription?.cancel();
    _linkSubscription = null;
  }
}
