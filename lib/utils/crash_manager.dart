import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../core.dart';

/// Configuration for the Safe Mode crash protection.
class SafeModeConfig {
  final int rapidCrashThreshold;
  final Duration timeWindow;
  final Future<void> Function() onReset;

  const SafeModeConfig({
    this.rapidCrashThreshold = 3,
    this.timeWindow = const Duration(seconds: 30),
    required this.onReset,
  });
}

class CrashManager {
  CrashManager._();

  static DateTime? _scheduledCrashTime;

  static String _keyCrashTimestamps = 'rapid_crash_timestamps';

  static SafeModeConfig? _config;

  /// Initialize storage configuration
  static void initStorageConfig(StorageConfig config) {
    _keyCrashTimestamps = config.rapidCrashTimestampsKey;
  }

  /// Initializes the CrashManager with Safe Mode settings.
  static void init(SafeModeConfig config) {
    _config = config;
  }

  /// Saves current logs and error details to a local file.
  /// Also checks for rapid consecutive crashes to trigger a safety reset.
  static Future<String?> saveCrashLog(Object error, StackTrace stack) async {
    // 1. Log the crash timestamp for rapid crash detection
    await _recordCrashTimestamp();

    try {
      final directory = await getApplicationDocumentsDirectory();
      final String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final File file = File('${directory.path}/crash_$timestamp.log');

      final StringBuffer buffer = StringBuffer();
      buffer.writeln('=== CRASH REPORT ===');
      buffer.writeln('Time: ${DateTime.now()}');

      if (error is FlutterErrorDetails) {
        buffer.writeln('Summary: ${error.exceptionAsString()}');
        buffer.writeln('Context: ${error.context}');
        buffer.writeln('Library: ${error.library}');
        buffer.writeln('\n=== FLUTTER DETAILS ===\n$error');
      } else {
        buffer.writeln('Error: $error');
      }

      buffer.writeln('\n=== STACK TRACE ===\n$stack');
      buffer.writeln('\n=== RECENT LOGS ===');
      buffer.writeln(LogManager.getAllLogsAsText(reversed: true));

      await file.writeAsString(buffer.toString());

      appLogger.i('Crash log saved to: ${file.path}');
      return file.path;
    } catch (e) {
      appLogger.e('Failed to save crash log: $e');
      return null;
    }
  }

  /// Records the current crash time and checks if we need to perform a safety reset.
  static Future<void> _recordCrashTimestamp() async {
    if (_config == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final List<String> history = SpUtil.getStringList(_keyCrashTimestamps) ?? [];

    history.add(now.toString());

    final int windowStart = DateTime.now().subtract(_config!.timeWindow).millisecondsSinceEpoch;

    // Filter history to keep only crashes within the current window
    final updatedHistory = history.where((ts) {
      try {
        return int.parse(ts) > windowStart;
      } catch (_) {
        return false;
      }
    }).toList();

    await SpUtil.put(_keyCrashTimestamps, updatedHistory);

    if (updatedHistory.length >= _config!.rapidCrashThreshold) {
      await _performSafetyReset();
    }
  }

  /// Clears crash history and triggers the externally provided reset logic.
  static Future<void> _performSafetyReset() async {
    appLogger.e('RAPID CRASH DETECTED! Triggering safety reset...');

    // Clear history first to prevent recursive reset loops
    await SpUtil.remove(_keyCrashTimestamps);

    // Call the injected reset logic (e.g., clear caches, reset settings)
    await _config?.onReset();
  }

  /// Lists all saved crash logs.
  static Future<List<File>> getSavedCrashLogs() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final List<FileSystemEntity> files = directory.listSync();
      final logs = files
          .whereType<File>()
          .where((f) => f.path.contains('crash_') && f.path.endsWith('.log'))
          .toList();
      logs.sort((a, b) => b.path.compareTo(a.path));
      return logs;
    } catch (_) {
      return [];
    }
  }

  /// Deletes a crash log file.
  static Future<void> deleteCrashLog(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Deletes all crash log files.
  static Future<void> deleteAllCrashLogs() async {
    final logs = await getSavedCrashLogs();
    for (var file in logs) {
      await deleteCrashLog(file);
    }
  }

  /// Simulates an upload to the server.
  static Future<bool> uploadCrashLog(File file) async {
    await Future.delayed(const Duration(seconds: 2));
    appLogger.i('Uploaded crash log: ${file.path}');
    return true;
  }

  /// Schedules a crash to occur after 10-20 seconds.
  static void scheduleRandomCrash() {
    final random = Random();
    final delaySeconds = 10 + random.nextInt(11);
    _scheduledCrashTime = DateTime.now().add(Duration(seconds: delaySeconds));

    appLogger.w(
      'CRASH TEST: Exception scheduled to trigger during any dispatch after $delaySeconds seconds.',
    );
  }

  /// Internal: Checks if a scheduled crash is due and throws if it is.
  static void checkAndTriggerInjectedCrash() {
    if (_scheduledCrashTime != null && DateTime.now().isAfter(_scheduledCrashTime!)) {
      _scheduledCrashTime = null;

      final random = Random();
      final crashTypes = [
        () => throw Exception('Injected: UI interaction interrupted by simulated core failure'),
        () => throw StateError('Injected: viewModel state corrupted during intent processing'),
        () => throw ArgumentError('Injected: Unexpected null value in critical business logic'),
        () => throw const FormatException('Injected: Corrupted response data from simulated network'),
      ];

      crashTypes[random.nextInt(crashTypes.length)]();
    }
  }
}
