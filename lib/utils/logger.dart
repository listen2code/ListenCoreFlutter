import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import '../core.dart';

/// Global logger instance providing consistent logging and in-app log management.
/// 
/// This logger is configured to capture logs in both debug and release builds,
/// ensuring comprehensive logging for the internal log viewer while controlling
/// console output based on build mode.
/// 
/// Features:
/// - Structured logging with severity levels
/// - JSON formatting for log processing
/// - Trace ID correlation for distributed tracing
/// - In-app log viewer integration
/// - Console output only in debug mode
/// 
/// **Example:**
/// ```dart
/// // Basic logging
/// appLogger.i('User logged in successfully');
/// appLogger.e('Failed to load user data', error: error);
/// 
/// // Structured logging
/// appLogger.d('Processing request', time: DateTime.now(), userId: '123');
/// ```
/// 
/// **See Also:**
/// - [LogManager] for in-app log management
/// - [ZoneManager] for trace ID management
final appLogger = Logger(
  /// Use ProductionFilter to ensure logs are processed in Release builds.
  /// 
  /// This allows logs to be captured by the in-app log viewer even when
  /// console output is disabled in production.
  filter: ProductionFilter(),
  
  /// Custom printer that adds trace ID correlation to log messages.
  /// 
  /// The printer wraps a PrettyPrinter to provide formatted output with
  /// trace ID prefixing for distributed tracing.
  printer: _TracePrinter(
    /// Inner PrettyPrinter configuration for log formatting.
    /// 
    /// Configures the visual appearance of log messages with:
    /// - Method count for stack traces
    /// - Error method count for exception details
    /// - Line length for terminal output
    /// - Colors and emojis for visual clarity
    /// - Time format for performance tracking
    PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  ),
  /// Multi-output configuration for log routing.
  /// 
  /// Logs are routed to multiple outputs:
  /// - ConsoleOutput: Only in debug mode for privacy and performance
  /// - _LogManagerOutput: Always for in-app log viewer
  output: MultiOutput([
    /// Console output only in Debug mode to protect privacy and performance.
    /// 
    /// In release builds, console output is disabled to prevent sensitive
    /// information from being exposed in production logs.
    if (kDebugMode) ConsoleOutput(),
    
    /// Always pipe logs to internal LogManager for the App's log viewer.
    /// 
    /// This ensures all logs are available in the in-app log viewer
    /// regardless of build mode.
    _LogManagerOutput(),
  ]),
);

/// A decorator printer that prepends the current Trace ID to every log message.
/// 
/// This printer enables distributed tracing by automatically adding the current
/// trace ID from ZoneManager to all log messages. The trace ID appears as a
/// prefix in the format: `[trace-id]\n[original message]`.
/// 
/// **Note:** This only affects the Console/Terminal output because of how
/// Logger.printer works. The in-app log viewer receives the trace ID through
/// other means.
/// 
/// **Example Output:**
/// ```
/// [abc123-def456]
/// 💡 User logged in successfully
/// ```
class _TracePrinter extends LogPrinter {
  /// The inner printer that handles the actual log formatting.
  /// 
  /// This is typically a PrettyPrinter or other LogPrinter implementation
  /// that provides the base formatting for log messages.
  final LogPrinter _inner;

  /// Creates a new trace printer with the specified inner printer.
  /// 
  /// [_inner] is the printer that will be wrapped with trace ID functionality.
  _TracePrinter(this._inner);

  @override
  List<String> log(LogEvent event) {
    /// Get the current trace ID from ZoneManager.
    /// 
    /// If no trace ID is available, an empty string is used.
    final traceId = ZoneManager.currentTraceId;
    
    /// Prepend traceId followed by a newline for console visibility.
    /// 
    /// This format makes the trace ID clearly visible in terminal output
    /// while maintaining the original log message structure.
    final newMessage = '[$traceId]\n${event.message}';

    /// Forward the modified event to the inner printer.
    /// 
    /// The inner printer handles the actual formatting of the log message
    /// with colors, emojis, and other visual elements.
    return _inner.log(
      LogEvent(event.level, newMessage, error: event.error, stackTrace: event.stackTrace, time: event.time),
    );
  }
}

/// Custom output handler to populate the App's LogManager with formatted data.
/// 
/// This output handler ensures that all log messages are captured by the
/// in-app log viewer, providing a comprehensive log history for users and
/// developers. It formats log events into the expected structure for
/// LogManager storage.
/// 
/// **Features:**
/// - Captures all log levels and messages
/// - Preserves error information and stack traces
/// - Maintains chronological order
/// - Integrates with in-app log viewer
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
