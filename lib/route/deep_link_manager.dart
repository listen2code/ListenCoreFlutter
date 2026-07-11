import 'dart:async';

import 'package:app_links/app_links.dart';

import '../utils/event_bus.dart';
import '../utils/logger.dart';

/// Business-agnostic manager to handle incoming deep links cleanly using app_links package.
class DeepLinkManager {
  DeepLinkManager._();

  /// Singleton instance of DeepLinkManager.
  static final DeepLinkManager instance = DeepLinkManager._();

  /// The unique EventBus key for Deep Link events.
  static const String deepLinkEventKey = 'deepLinkEventKey';

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  /// Hook invoked when a deep link is received. Return true to consume the event and bypass AppNav.
  FutureOr<bool> Function(Uri uri)? onLinkReceived;

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

  void _fireEvent(Uri uri) {
    EventBus().fire(CommonEvent<Uri>(deepLinkEventKey, data: uri, sticky: true, autoClear: true));
  }

  Future<void> _handleUri(Uri uri) async {
    if (onLinkReceived != null) {
      final handled = await onLinkReceived!(uri);
      if (handled) return;
    }
    _fireEvent(uri);
  }

  /// Trigger a URI manually for testing.
  Future<void> handleUriForTesting(Uri uri) => _handleUri(uri);

  void dispose() {
    _linkSubscription?.cancel();
    _linkSubscription = null;
  }
}
