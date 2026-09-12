import 'dart:async';

/// Platform-independent notification payload representing an incoming push notification.
///
/// Encapsulates visual presentation attributes ([title], [body]) as well as arbitrary
/// key-value business parameters ([data]) used for deep linking, telemetry, and routing.
///
/// ### Clean Architecture Role:
/// This entity resides in the core foundation layer (`ListenCore`), decoupled from
/// platform-specific SDK payloads (e.g. Firebase `RemoteMessage` or APNs dictionaries).
/// Concrete implementations (like `FirebaseNotificationServiceImpl`) are responsible for
/// translating vendor payloads into this normalized format.
class NotificationPayload {
  /// The user-facing title of the notification message.
  final String title;

  /// The main descriptive body text of the notification.
  final String body;

  /// Arbitrary custom key-value metadata attached to the notification.
  ///
  /// Commonly includes routing arguments, such as `link: 'listen://app/project/detail?id=1'`
  /// or tracking identifiers like `campaign_id` and `timestamp`.
  final Map<String, dynamic> data;

  /// Creates a immutable [NotificationPayload] instance.
  const NotificationPayload({
    required this.title,
    required this.body,
    this.data = const {},
  });

  /// Factory constructor to safely deserialize a raw JSON map into a [NotificationPayload].
  ///
  /// Provides defensive fallbacks (empty string / empty map) for missing or null fields.
  factory NotificationPayload.fromJson(Map<String, dynamic> json) {
    return NotificationPayload(
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      data: json['data'] as Map<String, dynamic>? ?? const {},
    );
  }

  @override
  String toString() => 'NotificationPayload(title: $title, body: $body, data: $data)';
}

/// Abstract contract defining push notification operations across the entire application.
///
/// Adheres to the Dependency Inversion Principle (DIP): UI components (like SettingsPage)
/// and domain logic interact solely through this abstraction, remaining completely agnostic
/// of whether notifications are handled by Firebase Cloud Messaging (FCM), Apple Push
/// Notification Service (APNs), Huawei Push Kit, or a local mock test driver.
abstract class INotificationService {
  /// Initializes push notification channels, credentials, and message listeners.
  ///
  /// Implementations should guarantee resilience by guarding against network timeouts
  /// (e.g., in environments where Google Play Services or Firebase endpoints are blocked).
  Future<void> initialize();

  /// Requests runtime notification display permissions from the operating system.
  ///
  /// On Android 13+ (API level 33+), this prompts for the `POST_NOTIFICATIONS` runtime permission.
  /// On iOS, this requests authorization for alert, badge, and sound presentations.
  /// Returns `true` if the user granted permission, `false` otherwise.
  Future<bool> requestPermission();

  /// Retrieves the unique device registration push token (e.g., FCM registration token).
  ///
  /// Returns `null` if registration fails, permissions are revoked, or the device is offline.
  Future<String?> getToken();

  /// Emits new registration tokens whenever the notification provider invalidates
  /// or refreshes the device token (e.g., app reinstall, backup restoration, or server rotation).
  Stream<String> get onTokenRefresh;

  /// Emits incoming notifications when the app is actively running in the foreground.
  ///
  /// Consumers typically handle this by triggering an in-app banner or updating an unread badge.
  Stream<NotificationPayload> get onMessageReceived;

  /// Emits notifications that were explicitly clicked by the user from the system notification shade.
  ///
  /// This stream handles cases where the user clicked a notification while the app was
  /// in the background or suspended, waking the app into the active state.
  Stream<NotificationPayload> get onMessageOpenedApp;

  /// Subscribes the device to a named broadcast topic (e.g. `version_updates`).
  ///
  /// Enables publish-subscribe messaging without requiring individual device token management.
  Future<void> subscribeToTopic(String topic);

  /// Unsubscribes the device from a previously subscribed broadcast topic.
  Future<void> unsubscribeFromTopic(String topic);
}
