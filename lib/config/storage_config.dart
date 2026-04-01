/// Configuration for storage operations
class StorageConfig {
  // SharedPreferences Keys
  final String envKey;
  final String rapidCrashTimestampsKey;

  // Storage Prefixes
  final String? defaultStoragePrefix;

  const StorageConfig({
    this.envKey = 'env_key',
    this.rapidCrashTimestampsKey = 'rapid_crash_timestamps',
    this.defaultStoragePrefix,
  });
}
