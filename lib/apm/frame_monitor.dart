import 'dart:async';
import 'dart:io' show ProcessInfo;
import 'dart:ui' show FramePhase, FrameTiming;
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'ring_buffer.dart';

/// Single-frame APM metrics captured from the Flutter engine pipeline.
class FrameMetric {
  final int vsyncStartUs;       // Physical vsync start timestamp in microseconds
  final int buildDurationUs;    // UI thread build duration
  final int rasterDurationUs;   // GPU rasterization duration
  final int totalDurationUs;    // Total elapsed time (build + vsyncOverhead + raster)
  final int vsyncBudgetUs;      // Adaptive vsync budget based on dynamic refresh rate
  final bool isJank;            // Whether this frame exceeded the vsync budget
  final bool isSevereJank;      // Whether this frame missed multiple vsync beats (> 2 * budget)

  FrameMetric({
    required this.vsyncStartUs,
    required this.buildDurationUs,
    required this.rasterDurationUs,
    required this.totalDurationUs,
    required this.vsyncBudgetUs,
    required this.isJank,
    required this.isSevereJank,
  });
}

/// An immutable snapshot of the performance metrics, dispatching to the UI
/// layer via [ValueNotifier] with optimized throttling.
class FrameMonitorSnapshot {
  final double fps;                     // Smoothed EMA FPS value
  final int jankCount;                  // Total accumulated Janks
  final int severeJankCount;            // Total accumulated severe Janks
  final int worstFrameUs;               // Worst rendering latency recorded
  final int memoryMB;                   // Throttled memory footprint (Dart RSS)
  final RingBuffer<FrameMetric> recentFrames; // Shared read-only ring buffer

  FrameMonitorSnapshot({
    required this.fps,
    required this.jankCount,
    required this.severeJankCount,
    required this.worstFrameUs,
    required this.memoryMB,
    required this.recentFrames,
  });
}

/// A lightweight, pure-Dart Application Performance Monitor (APM) tool.
///
/// It listens to the Flutter scheduler callbacks on-demand to compute
/// real-time frame rates, jank frequencies, and memory utilization.
class FrameMonitor {
  static final FrameMonitor _instance = FrameMonitor._();
  static FrameMonitor get instance => _instance;
  FrameMonitor._();

  // Configuration Constants
  static const int ringCapacity = 300;             // Tracks roughly 5 seconds @ 60fps
  static const int defaultBudgetUs = 16670;       // Standard 60Hz frame budget (16.67ms)
  static const int ignoreInitialFramesCount = 5;  // Ignore startup warm-up frames
  static const double emaAlpha = 0.3;             // EMA coefficient for visual smoothing

  // Thread-safe Buffers and Stats
  final RingBuffer<FrameMetric> _frames = RingBuffer(ringCapacity);
  int _jankCount = 0;
  int _severeJankCount = 0;
  int _worstFrameUs = 0;
  int _processedFramesCount = 0;

  // Lifecycle & Low-Frequency States
  bool _isRunning = false;
  bool _isCallbackRegistered = false;
  Timer? _memoryTimer;
  int _cachedMemoryMB = 0;

  // Throttled Notification Drivers
  final ValueNotifier<FrameMonitorSnapshot?> snapshot = ValueNotifier(null);
  DateTime _lastNotifyTime = DateTime.now();
  
  // Tracking dynamic Vsync interval
  Duration? _lastVsyncStart;

  /// Starts frame timing callbacks and the memory sampling timer.
  /// This operation is idempotent and safe for hot restarts.
  void start() {
    if (_isRunning) return;
    _isRunning = true;

    // Reset statistics
    _frames.clear();
    _jankCount = 0;
    _severeJankCount = 0;
    _worstFrameUs = 0;
    _processedFramesCount = 0;
    _lastVsyncStart = null;
    _cachedMemoryMB = _sampleRssMemory();

    // Setup low-frequency memory sampling timer (2-second interval to avoid system call lag)
    _memoryTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _cachedMemoryMB = _sampleRssMemory();
      _throttledNotify(force: true);
    });

    // Clean register timings callback (Safe registration guard)
    if (!_isCallbackRegistered) {
      try {
        SchedulerBinding.instance.addTimingsCallback(_onTimings);
        _isCallbackRegistered = true;
      } catch (e) {
        // Fallback for environment constraints (e.g., non-UI test environments)
        _isCallbackRegistered = false;
      }
    }

    // Immediately dispatch initial snapshot to avoid null UI states
    _throttledNotify(force: true);
  }

  /// Stops performance monitoring, releasing timers and framework listeners.
  void stop() {
    if (!_isRunning) return;
    _isRunning = false;

    if (_isCallbackRegistered) {
      try {
        SchedulerBinding.instance.removeTimingsCallback(_onTimings);
      } catch (_) {
        // Silent catch for failed framework callback removal assertions
      }
      _isCallbackRegistered = false;
    }
    _memoryTimer?.cancel();
    _memoryTimer = null;
  }

  /// Public test helper to feed simulated frame timings into the monitor.
  @visibleForTesting
  void handleTimingsForTest(List<FrameTiming> timings) {
    _onTimings(timings);
    _throttledNotify(force: true);
  }

  void _onTimings(List<FrameTiming> timings) {
    if (!_isRunning) return;

    for (final timing in timings) {
      _processedFramesCount++;
      if (_processedFramesCount <= ignoreInitialFramesCount) {
        // Bypass cold-start initial frames to prevent metric pollution
        continue;
      }

      final buildUs = timing.buildDuration.inMicroseconds;
      final rasterUs = timing.rasterDuration.inMicroseconds;
      final totalUs = timing.totalSpan.inMicroseconds; // Exact latency (Vsync start -> GPU finish)

      // Calculate adaptive vsync budget from current rendering pipeline
      final currentVsyncStart = timing.timestampInMicroseconds(FramePhase.vsyncStart);
      int budgetUs = defaultBudgetUs;

      if (_lastVsyncStart != null) {
        final intervalUs = currentVsyncStart - _lastVsyncStart!.inMicroseconds;
        if (intervalUs > 3000 && intervalUs < 100000) {
          // Calculate dynamically if interval makes physical sense (3ms to 100ms)
          // 8.3ms -> 120Hz, 11.1ms -> 90Hz, 16.6ms -> 60Hz
          budgetUs = intervalUs;
        }
      }
      _lastVsyncStart = Duration(microseconds: currentVsyncStart);

      // Jank Detection using adaptive budget
      final isJank = totalUs > budgetUs;
      final isSevereJank = totalUs > (budgetUs * 2);

      if (isJank) _jankCount++;
      if (isSevereJank) _severeJankCount++;
      if (totalUs > _worstFrameUs) _worstFrameUs = totalUs;

      final metric = FrameMetric(
        vsyncStartUs: currentVsyncStart,
        buildDurationUs: buildUs,
        rasterDurationUs: rasterUs,
        totalDurationUs: totalUs,
        vsyncBudgetUs: budgetUs,
        isJank: isJank,
        isSevereJank: isSevereJank,
      );

      _frames.add(metric);
    }

    _throttledNotify();
  }

  /// Dispatches frame updates to the UI, applying a 250ms rate limit to conserve GPU cycles.
  void _throttledNotify({bool force = false}) {
    final now = DateTime.now();
    if (!force && now.difference(_lastNotifyTime).inMilliseconds < 250) {
      return;
    }
    _lastNotifyTime = now;

    final double calculatedFps = _calculateFps();
    final double previousFps = snapshot.value?.fps ?? calculatedFps;
    
    // Apply Exponential Moving Average (EMA) filter for UI value smoothing
    final double smoothedFps = (calculatedFps * emaAlpha) + (previousFps * (1.0 - emaAlpha));

    snapshot.value = FrameMonitorSnapshot(
      fps: smoothedFps,
      jankCount: _jankCount,
      severeJankCount: _severeJankCount,
      worstFrameUs: _worstFrameUs,
      memoryMB: _cachedMemoryMB,
      recentFrames: _frames,
    );
  }

  /// Calculates the FPS over a rolling 1-second sliding physical time window.
  ///
  /// NOTE: This algorithm uses physical hardware Vsync ticks (vsyncStartUs) as the timeline,
  /// instead of DateTime.now(). This is mathematically required because Flutter engine batches
  /// frame callback dispatches. Using wall-clock DateTime on batch callbacks results in near-zero
  /// time differences (spanUs ~ 0) for consecutive frames, causing artificial FPS spikes up to thousands.
  /// Using vsyncStartUs guarantees that the delta between frames is lowerbounded by the hardware refresh rate.
  double _calculateFps() {
    if (_frames.isEmpty) return 60.0;
    
    final int len = _frames.length;
    final int lastVsync = _frames[len - 1].vsyncStartUs;
    
    // 1. Scan back to find the oldest frame that falls within the 1-second (1,000,000 us) window
    int oldestIndex = -1;
    for (int i = 0; i < len; i++) {
      if (lastVsync - _frames[i].vsyncStartUs <= 1000000) {
        oldestIndex = i;
        break;
      }
    }

    if (oldestIndex == -1 || oldestIndex == len - 1) {
      // Idle state: No frames rendered in the past 1 second
      return 60.0;
    }

    final int frameCount = len - oldestIndex;
    final int spanUs = lastVsync - _frames[oldestIndex].vsyncStartUs;
    if (spanUs == 0) return 60.0;

    return (frameCount - 1) / (spanUs / 1000000.0);
  }

  /// Safely queries the Process memory mapping (RSS) with fallback capabilities.
  int _sampleRssMemory() {
    if (kIsWeb) return 0;
    try {
      return ProcessInfo.currentRss ~/ (1024 * 1024);
    } catch (_) {
      return 0; // Return zero in case of unexpected platform failures
    }
  }
}
