import 'dart:convert';
import 'package:flutter/widgets.dart';
import '../core.dart';

/// Data model representing a single application launch performance record.
class LaunchReport {
  final DateTime timestamp;
  final int coldBootMs; // initStart - mainStart
  final int initMs;     // initEnd - initStart
  final int renderMs;   // firstFrame - initEnd
  final int totalMs;    // firstFrame - mainStart
  final bool isRegression;
  final int regressionAmountMs;

  const LaunchReport({
    required this.timestamp,
    required this.coldBootMs,
    required this.initMs,
    required this.renderMs,
    required this.totalMs,
    this.isRegression = false,
    this.regressionAmountMs = 0,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'coldBootMs': coldBootMs,
        'initMs': initMs,
        'renderMs': renderMs,
        'totalMs': totalMs,
        'isRegression': isRegression,
        'regressionAmountMs': regressionAmountMs,
      };

  factory LaunchReport.fromJson(Map<String, dynamic> json) {
    return LaunchReport(
      timestamp: DateTime.parse(json['timestamp']),
      coldBootMs: json['coldBootMs'] as int,
      initMs: json['initMs'] as int,
      renderMs: json['renderMs'] as int,
      totalMs: json['totalMs'] as int,
      isRegression: json['isRegression'] as bool? ?? false,
      regressionAmountMs: json['regressionAmountMs'] as int? ?? 0,
    );
  }
}

/// A monitor class designed to capture and log application launch stages.
class LaunchMonitor {
  LaunchMonitor._();

  static int? _mainStartMs;
  static int? _initStartMs;
  static int? _initEndMs;
  static int? _firstFrameMs;

  static const String _keyLaunchHistory = 'launch_history';
  static const int _maxHistoryCount = 50;

  /// Exposes the latest launch performance report
  static final ValueNotifier<LaunchReport?> latestReport = ValueNotifier(null);

  /// Records the entry timestamp of main() execution
  static void recordMainStart() {
    _mainStartMs = DateTime.now().millisecondsSinceEpoch;
  }

  /// Records the start timestamp of initialization
  static void recordInitStart() {
    _initStartMs = DateTime.now().millisecondsSinceEpoch;
  }

  /// Records the end timestamp of initialization
  static void recordInitEnd() {
    _initEndMs = DateTime.now().millisecondsSinceEpoch;
  }

  /// Records the rendering timestamp of the first frame and compiles the report
  static void recordFirstFrame() {
    if (_firstFrameMs != null) return; // Prevent double recording
    _firstFrameMs = DateTime.now().millisecondsSinceEpoch;

    _compileAndSaveReport();
  }

  /// Clears launch metrics state (mainly for testing)
  @visibleForTesting
  static void resetState() {
    _mainStartMs = null;
    _initStartMs = null;
    _initEndMs = null;
    _firstFrameMs = null;
    latestReport.value = null;
  }

  /// Compiles metrics, detects regressions against history, and saves to SharedPreferences
  static void _compileAndSaveReport() {
    final int mainStart = _mainStartMs ?? _initStartMs ?? DateTime.now().millisecondsSinceEpoch;
    final int initStart = _initStartMs ?? mainStart;
    final int initEnd = _initEndMs ?? initStart;
    final int firstFrame = _firstFrameMs ?? initEnd;

    final int coldBootMs = initStart - mainStart;
    final int initMs = initEnd - initStart;
    final int renderMs = firstFrame - initEnd;
    final int totalMs = firstFrame - mainStart;

    final List<LaunchReport> history = getHistory();

    // Regression Detection:
    // If we have at least 3 previous runs, compute the average totalMs.
    // Trigger regression if totalMs is 25% higher than average AND is at least 150ms higher.
    bool isRegression = false;
    int regressionAmountMs = 0;

    if (history.length >= 3) {
      double sum = 0;
      for (final r in history) {
        sum += r.totalMs;
      }
      final double avg = sum / history.length;
      final double thresholdPercent = avg * 1.25;
      final double thresholdAbsolute = avg + 150;

      if (totalMs > thresholdPercent && totalMs > thresholdAbsolute) {
        isRegression = true;
        regressionAmountMs = totalMs - avg.toInt();
      }
    }

    final newReport = LaunchReport(
      timestamp: DateTime.now(),
      coldBootMs: coldBootMs < 0 ? 0 : coldBootMs,
      initMs: initMs < 0 ? 0 : initMs,
      renderMs: renderMs < 0 ? 0 : renderMs,
      totalMs: totalMs < 0 ? 0 : totalMs,
      isRegression: isRegression,
      regressionAmountMs: regressionAmountMs,
    );

    // Save to SharedPreferences
    final List<LaunchReport> updatedHistory = [newReport, ...history];
    if (updatedHistory.length > _maxHistoryCount) {
      updatedHistory.removeRange(_maxHistoryCount, updatedHistory.length);
    }

    final List<String> encodedHistory = updatedHistory.map((r) => jsonEncode(r.toJson())).toList();
    SpUtil.putStringList(_keyLaunchHistory, encodedHistory);

    latestReport.value = newReport;
    appLogger.i('LaunchMonitor: Compiled report - Total: ${newReport.totalMs}ms (Boot: ${newReport.coldBootMs}ms, Init: ${newReport.initMs}ms, Render: ${newReport.renderMs}ms). Regression: $isRegression');
  }

  /// Retrieves the history of launch reports stored in SharedPreferences
  static List<LaunchReport> getHistory() {
    try {
      final List<String>? historyStrings = SpUtil.getStringList(_keyLaunchHistory);
      if (historyStrings == null) return [];

      return historyStrings.map((s) => LaunchReport.fromJson(jsonDecode(s) as Map<String, dynamic>)).toList();
    } catch (e) {
      appLogger.e('LaunchMonitor: Failed to read launch history: $e');
      return [];
    }
  }

  /// Clears launch history from SharedPreferences
  static void clearHistory() {
    SpUtil.remove(_keyLaunchHistory);
    latestReport.value = null;
  }
}
