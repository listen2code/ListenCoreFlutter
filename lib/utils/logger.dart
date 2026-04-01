import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import '../core.dart';

/// Global logger instance providing consistent logging and in-app log management.
/// Configured to capture logs even in Release builds for the internal UI viewer.
final appLogger = Logger(
  // Use ProductionFilter to ensure logs are processed in Release builds.
  filter: ProductionFilter(),
  printer: _TracePrinter(
    PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  ),
  output: MultiOutput([
    // Only output to system console in Debug mode to protect privacy and performance
    if (kDebugMode) ConsoleOutput(),
    // Always pipe logs to internal LogManager for the App's log viewer
    _LogManagerOutput(),
  ]),
);

/// A decorator printer that prepends the current Trace ID to every log message.
/// Note: This only affects the Console/Terminal output because of how Logger.printer works.
class _TracePrinter extends LogPrinter {
  final LogPrinter _inner;

  _TracePrinter(this._inner);

  @override
  List<String> log(LogEvent event) {
    final traceId = ZoneManager.currentTraceId;
    // Prepend traceId followed by a newline for console visibility.
    final newMessage = '[$traceId]\n${event.message}';

    return _inner.log(
      LogEvent(event.level, newMessage, error: event.error, stackTrace: event.stackTrace, time: event.time),
    );
  }
}

/// Custom output handler to populate the App's LogManager with formatted data.
class _LogManagerOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    // IMPORTANT: event.origin.message is the ORIGINAL message passed to appLogger.i/e.
    // It does NOT include modifications made by _TracePrinter.
    final rawMessage = event.origin.message.toString();
    if (rawMessage.isEmpty) return;

    // We must re-fetch the traceId here for the LogManager.
    final traceId = ZoneManager.currentTraceId;

    // Format: [traceId] Message
    // This will now show up correctly in the LogOverlayManager UI.
    final formattedMessage = '[$traceId]\n $rawMessage';

    LogManager.addLog(formattedMessage, level: _mapLevel(event.level));
  }

  // Convert external Logger levels to internal LogManager levels
  LogLevel _mapLevel(Level level) {
    if (level == Level.error || level == Level.fatal) return LogLevel.error;
    if (level == Level.warning) return LogLevel.warning;
    if (level == Level.debug || level == Level.trace) return LogLevel.debug;
    return LogLevel.info;
  }
}
