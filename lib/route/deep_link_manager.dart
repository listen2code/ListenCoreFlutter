import 'dart:async';
import 'package:app_links/app_links.dart';
import 'app_nav.dart';
import '../utils/logger.dart';

/// Business-agnostic manager to handle incoming deep links cleanly using app_links package.
class DeepLinkManager {
  DeepLinkManager._();

  static final AppLinks _appLinks = AppLinks();
  static StreamSubscription<Uri>? _linkSubscription;

  /// Hook for host app to intercept routing or execute pre-navigation actions.
  /// If it returns true, DeepLinkManager will bypass default routing to AppNav.to.
  static FutureOr<bool> Function(Uri uri)? onLinkReceived;

  /// Initializes deep link processing. Handles both cold start and hot starts.
  static Future<void> init() async {
    // 1. Handle cold start deep link (if launched via deep link)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        appLogger.i('DeepLinkManager: Cold start link detected: $initialUri');
        await _handleUri(initialUri);
      }
    } catch (e, stack) {
      appLogger.e('DeepLinkManager: Failed to parse initial link', error: e, stackTrace: stack);
    }

    // 2. Handle hot start deep links (while running or in background)
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
  }

  static Future<void> _handleUri(Uri uri) async {
    if (onLinkReceived != null) {
      final handled = await onLinkReceived!(uri);
      if (handled) return;
    }
    // Default fallback: direct route navigation via AppNav
    AppNav.to(uri.toString());
  }

  static Future<void> handleUriForTesting(Uri uri) => _handleUri(uri);

  static void dispose() {
    _linkSubscription?.cancel();
    _linkSubscription = null;
  }
}
