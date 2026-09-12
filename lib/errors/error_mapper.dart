import 'failures.dart';
import '../i18n/translations.dart';

/// Utility class providing localized message mapping for domain [Failure] instances.
///
/// In modern internationalized applications, error messages delivered directly from the backend
/// or lower layers may be in a default language (e.g., English or Chinese) or contain internal
/// technical phrasing.
///
/// `ErrorMapper` implements a resilient **3-Tier Cascade Fallback Algorithm**:
/// 1. **Tier 1 (Contract Code Mapping)**: If the failure contains a non-empty [messageId]
///    (e.g., `NET_0001`, `AUTH_0300`, `VAL_0400`), it attempts translation via `messageId.tr`.
///    If the dictionary has a localized entry matching this key, that translated string is selected.
/// 2. **Tier 2 (Raw Message Mapping)**: If the [messageId] was not found in the dictionary or is absent,
///    it attempts to translate the raw message string itself (`failure.message.tr`).
/// 3. **Tier 3 (Pass-through Fallback)**: If neither the contract code nor the raw message has a translation,
///    it safely falls back to the original `failure.message` content.
///
/// Furthermore, `ErrorMapper.map` preserves the exact concrete [Failure] runtime type
/// (`ServerApiFailure`, `NetworkFailure`, `AuthFailure`, etc.) and retains any metadata like `messageId`.
class ErrorMapper {
  ErrorMapper._();

  /// Maps an incoming [Failure] to a localized [Failure] using the 3-tier cascade fallback algorithm.
  ///
  /// Preserves the failure type and any existing [messageId] while replacing the [message]
  /// with the most specific localized string available.
  static Failure map(Failure failure) {
    String translatedMessage = failure.message;
    String? messageId;

    // Extract messageId from failures that support it
    if (failure is ServerApiFailure) {
      messageId = failure.messageId;
    } else if (failure is AuthFailure) {
      messageId = failure.messageId;
    }

    if (messageId != null && messageId.isNotEmpty) {
      // Tier 1: Look up localized string by contract code (messageId)
      final translated = messageId.tr;
      if (translated != messageId) {
        translatedMessage = translated;
      } else {
        // Tier 2: Fallback to translating the raw message string
        final msgTr = failure.message.tr;
        if (msgTr != failure.message) {
          translatedMessage = msgTr;
        }
        // Tier 3: If no translation exists, retain the original failure.message
      }
    } else {
      // Tier 2: Fallback to translating the raw message string for types without messageId
      final msgTr = failure.message.tr;
      if (msgTr != failure.message) {
        translatedMessage = msgTr;
      }
      // Tier 3: Retain original failure.message
    }

    // Return a new failure instance of the same concrete type with the localized message
    if (failure is ServerApiFailure) {
      return ServerApiFailure(translatedMessage, messageId: messageId);
    } else if (failure is ServerFailure) {
      return ServerFailure(translatedMessage);
    } else if (failure is NetworkFailure) {
      return NetworkFailure(translatedMessage);
    } else if (failure is CacheFailure) {
      return CacheFailure(translatedMessage);
    } else if (failure is ValidationFailure) {
      return ValidationFailure(translatedMessage);
    } else if (failure is AuthFailure) {
      return AuthFailure(translatedMessage, messageId: messageId);
    } else if (failure is ParseFailure) {
      return ParseFailure(translatedMessage);
    } else if (failure is UnknownFailure) {
      return UnknownFailure(translatedMessage);
    } else {
      // Fallback for custom or unrecognized Failure subclasses
      return UnknownFailure(translatedMessage);
    }
  }
}
