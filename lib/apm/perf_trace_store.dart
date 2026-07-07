import 'package:flutter/foundation.dart';
import '../utils/zone_manager.dart';

/// Single-stage timing data within a performance trace.
class PerfStage {
  final String name;
  final int durationMs;

  const PerfStage({required this.name, required this.durationMs});
}

/// DTO container representing a structured execution segment trace.
class PerfTraceEntry {
  final String traceId;
  final String label; // e.g., "Intent" / "Page Render" / "Task"
  final String name; // e.g., "LoadProjectsIntent" / "page-SettingsPage"
  final List<PerfStage> stages; // Internal milestones and elapsed times
  final int totalMs; // Total trace lifetime duration
  final DateTime timestamp;

  const PerfTraceEntry({
    required this.traceId,
    required this.label,
    required this.name,
    required this.stages,
    required this.totalMs,
    required this.timestamp,
  });
}

/// In-memory storage for structured execution timelines and performance marks.
///
/// Limits historical capacity to avoid infinite memory growth and drives
/// reactive overlay updates using [ValueNotifier].
class PerfTraceStore {
  static final PerfTraceStore _instance = PerfTraceStore._();
  static PerfTraceStore get instance => _instance;

  PerfTraceStore._() {
    // Automatically subscribe to core ZoneManager performance notifications
    ZoneManager.onPerfTrace.listen((record) {
      this.record(
        traceId: record.traceId,
        label: record.label,
        name: record.name,
        stages: record.stages,
        totalMs: record.totalMs,
      );
    });
  }

  static const int maxEntries = 200;
  final List<PerfTraceEntry> _entries = [];

  /// Observable list notifier targeting rendering overlays.
  final ValueNotifier<List<PerfTraceEntry>> traces = ValueNotifier([]);

  /// Records a new performance trace.
  ///
  /// Safe for invocation across multiple isolates/zones.
  void record({
    required String traceId,
    required String label,
    required String name,
    required List<({String name, int duration})> stages,
    required int totalMs,
  }) {
    // Convert named records into structured DTO classes
    final parsedStages = stages
        .map((s) => PerfStage(name: s.name, durationMs: s.duration))
        .toList(growable: false);

    final entry = PerfTraceEntry(
      traceId: traceId,
      label: label,
      name: name,
      stages: parsedStages,
      totalMs: totalMs,
      timestamp: DateTime.now(),
    );

    _addEntry(entry);
  }

  void _addEntry(PerfTraceEntry entry) {
    if (_entries.length >= maxEntries) {
      _entries.removeAt(0); // Discard the oldest record
    }
    _entries.add(entry);

    // Force reactive UI refresh
    traces.value = List.unmodifiable(_entries);
  }

  /// Clears all stored traces.
  void clear() {
    _entries.clear();
    traces.value = [];
  }
}
