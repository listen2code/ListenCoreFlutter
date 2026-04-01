/// Configuration for logging system
class LogConfig {
  // Log Limits
  final int maxLogs;

  // Log Tags
  final String summaryTag;
  final String mockServerTag;
  final String termTag;

  // Date Formatting
  final String timestampFormat;

  const LogConfig({
    this.maxLogs = 100,
    this.summaryTag = "Summary",
    this.mockServerTag = "MockServer",
    this.termTag = "Execution Terminated",
    this.timestampFormat = 'HH:mm:ss.SSS',
  });
}
