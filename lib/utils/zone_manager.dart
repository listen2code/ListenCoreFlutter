import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import '../core.dart';
import 'package:uuid/uuid.dart';

/// Manages data stored in the current [Zone].
/// This handles distributed tracing, request cancellation, and performance profiling.
class ZoneManager {
  ZoneManager._();

  // --- Public Identifiers ---
  static const String mainTraceId = "main-zone";
  static const String mainStart = "Main Start";

  // --- Internal Zone Keys ---
  static const Symbol _traceKey = Symbol('trace_id_key');
  static const Symbol _cancelTokenKey = Symbol('dio_cancel_token_key');
  static const Symbol _perfKey = Symbol('perf_trace_key');

  // --- Default Values & Labels ---
  static const String _noTraceId = 'no-trace-id';
  static const String _labelIntent = 'Intent';
  static const String _labelTask = 'Task';
  static const String _labelPerformance = 'Performance';
  static const String _labelPageRender = 'Page Render';
  static const String _prefixPage = 'page-';
  static const int _shortIdLength = 8;
  static const int _minLogThresholdMs = 5;

  // --- Mark Names ---
  static const String markFirstFrame = 'First Frame Rendered';
  static const String _markFinalize = '[Finalize]';
  static const String _detailsPrefix = " Details: ";

  /// Gets the current Trace ID from the Zone.
  static String get currentTraceId => Zone.current[_traceKey] ?? _noTraceId;

  /// Gets the current [CancelToken] from the Zone.
  static CancelToken? get currentCancelToken => Zone.current[_cancelTokenKey];

  /// Internal helper to get performance tracker.
  static _PerfTrace? get _perf => Zone.current[_perfKey];

  /// Marks a specific stage in the current execution flow.
  /// It records the duration since the last mark.
  static void mark(String stage) => _perf?._mark(stage);

  /// Specialized runner for Page Rendering performance tracking.
  static Widget runPage(String pageName, Widget Function() builder) {
    final String id = "$_prefixPage$pageName-${const Uuid().v4().substring(0, _shortIdLength)}";
    final perf = _PerfTrace();

    return _ZonePageWrapper(id: id, perf: perf, builder: builder);
  }

  /// Runs the [body] in a new Zone with a Trace ID and performance tracking.
  static T run<T>(
    T Function() body, {
    String? traceId,
    CancelToken? cancelToken,
    Map<Object?, Object?>? zoneValues,
    bool silent = false,
  }) {
    final id = _resolveId(traceId);
    final perf = _PerfTrace();

    return runZoned(() {
      try {
        final result = body();
        if (result is Future) {
          return result.then(
                (value) {
                  if (!silent) _logSummary(id, perf, label: _labelIntent);
                  return value;
                },
                onError: (e, s) {
                  if (!silent) _logError(id, perf);
                  throw e;
                },
              )
              as T;
        }
        if (!silent) _logSummary(id, perf, label: _labelIntent);
        return result;
      } catch (e) {
        if (!silent) _logError(id, perf);
        rethrow;
      }
    }, zoneValues: {_traceKey: id, _cancelTokenKey: ?cancelToken, _perfKey: perf, ...?zoneValues});
  }

  /// Runs the [body] in a protected Zone that catches unhandled asynchronous errors.
  static Future<void> runGuarded(
    FutureOr<void> Function() body, {
    String? traceId = mainTraceId,
    String? label = mainStart,
    CancelToken? cancelToken,
    Map<Object?, Object?>? zoneValues,
    void Function(Object error, StackTrace stack)? onError,
    bool silent = false,
  }) async {
    final id = _resolveId(traceId);
    final perf = _PerfTrace();

    return runZonedGuarded(
      () async {
        try {
          await body();
          if (!silent) _logSummary(id, perf, label: label ?? _labelTask);
        } catch (e) {
          if (!silent) _logError(id, perf);
          rethrow;
        }
      },
      (error, stack) {
        appLogger.e('Unhandled error in Zone [$id]: $error', error: error, stackTrace: stack);
        onError?.call(error, stack);
      },
      zoneValues: {_traceKey: id, _cancelTokenKey: ?cancelToken, _perfKey: perf, ...?zoneValues},
    );
  }

  static String _resolveId(String? providedId) {
    if (providedId != null) return providedId;
    final String? parentId = Zone.current[_traceKey];
    if (parentId != null && parentId.isNotEmpty && parentId != mainTraceId) {
      return parentId;
    }
    return const Uuid().v4();
  }

  static void _logSummary(String id, _PerfTrace perf, {String label = _labelPerformance}) {
    final summary = perf._summary();
    if (summary.isNotEmpty) {
      // Use LogManager.summaryTag instead of hardcoded ':'
      appLogger.d('$label ${LogManager.summaryTag}: $summary');
    }
  }

  static void _logError(String id, _PerfTrace perf) {
    final summary = perf._summary();
    // Use LogManager.termTag for identifying termination due to error
    final details = summary.isNotEmpty ? "$_detailsPrefix$summary" : "";
    appLogger.d('${LogManager.termTag}.$details');
  }
}

class _ZonePageWrapper extends StatelessWidget {
  final String id;
  final _PerfTrace perf;
  final Widget Function() builder;

  const _ZonePageWrapper({required this.id, required this.perf, required this.builder});

  @override
  Widget build(BuildContext context) {
    return runZoned(() {
      final pageZone = Zone.current;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        pageZone.run(() {
          perf._mark(ZoneManager.markFirstFrame);
          ZoneManager._logSummary(id, perf, label: ZoneManager._labelPageRender);
        });
      });

      return builder();
    }, zoneValues: {ZoneManager._traceKey: id, ZoneManager._perfKey: perf});
  }
}

class _PerfTrace {
  final Stopwatch _stopwatch = Stopwatch()..start();
  final List<({String name, int duration})> _stages = [];
  int _lastMarkTime = 0;

  // --- Formatting Constants ---
  static const String _unit = 'ms';
  static const String _totalLabel = 'Total (Sum)';

  void _mark(String stage) {
    final int now = _stopwatch.elapsedMilliseconds;
    _stages.add((name: stage, duration: now - _lastMarkTime));
    _lastMarkTime = now;
  }

  String _summary() {
    if (_stopwatch.isRunning) {
      _stopwatch.stop();
    }

    // Ignore very short executions to reduce log noise
    if (_stages.isEmpty && _stopwatch.elapsedMilliseconds < ZoneManager._minLogThresholdMs) return "";

    final int now = _stopwatch.elapsedMilliseconds;
    final int finalStageDuration = now - _lastMarkTime;

    final buffer = StringBuffer();
    int totalSum = 0;

    for (final s in _stages) {
      buffer.write('\n  - ${s.name}: ${s.duration}$_unit');
      totalSum += s.duration;
    }

    if (finalStageDuration > 0) {
      buffer.write('\n  - ${ZoneManager._markFinalize}: $finalStageDuration$_unit');
      totalSum += finalStageDuration;
    }

    buffer.write('\n  => $_totalLabel: $totalSum$_unit');
    return buffer.toString();
  }
}
