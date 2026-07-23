import 'failures.dart';
import '../i18n/translations.dart';

class ErrorMapper {
  ErrorMapper._();

  /// Maps a [Failure] to a localized [Failure] using messageId translation, 
  /// falling back to message translation or the original message content.
  static Failure map(Failure failure) {
    String translatedMessage = failure.message;
    String? messageId;

    if (failure is ServerApiFailure) {
      messageId = failure.messageId;
    } else if (failure is AuthFailure) {
      messageId = failure.messageId;
    }

    if (messageId != null && messageId.isNotEmpty) {
      final translated = messageId.tr;
      if (translated != messageId) {
        translatedMessage = translated;
      } else {
        // Fallback: translate the raw message
        final msgTr = failure.message.tr;
        if (msgTr != failure.message) {
          translatedMessage = msgTr;
        }
      }
    } else {
      // Fallback: translate the raw message for other failure types
      final msgTr = failure.message.tr;
      if (msgTr != failure.message) {
        translatedMessage = msgTr;
      }
    }

    // Return a new failure instance of the same type with the translated message
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
      // Fallback for custom Failure subclass
      return UnknownFailure(translatedMessage);
    }
  }
}
