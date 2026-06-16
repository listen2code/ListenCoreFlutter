import 'dart:async';

/// Platform-independent notification payload
class NotificationPayload {
  final String title;
  final String body;
  final Map<String, dynamic> data; // Custom key-value pairs

  const NotificationPayload({
    required this.title,
    required this.body,
    this.data = const {},
  });

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

/// Push notification service abstraction
abstract class INotificationService {
  /// Initializes push notification service configuration (channels, credentials, etc.)
  Future<void> initialize();

  /// Requests notification permissions dynamically
  Future<bool> requestPermission();

  /// Retrieves the device push token
  Future<String?> getToken();

  /// Stream of push token refreshes
  Stream<String> get onTokenRefresh;

  /// Stream of messages received in the foreground
  Stream<NotificationPayload> get onMessageReceived;

  /// Stream of messages opened by user (which wakes app from background or terminated states)
  Stream<NotificationPayload> get onMessageOpenedApp;
}
