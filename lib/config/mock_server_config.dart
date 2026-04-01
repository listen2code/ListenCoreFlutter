/// Configuration for local mock server
class MockServerConfig {
  // Server Settings
  final int port;
  final Duration networkLatency;

  // Supported File Types
  final Map<String, String> imageExtensions;

  // Directory Structure
  final String assetsBasePath;

  const MockServerConfig({
    this.port = 9999,
    this.networkLatency = const Duration(seconds: 1),
    this.imageExtensions = const {
      '.jpg': 'image/jpeg',
      '.jpeg': 'image/jpeg',
      '.png': 'image/png',
      '.gif': 'image/gif',
      '.webp': 'image/webp',
      '.svg': 'image/svg+xml',
    },
    this.assetsBasePath = 'assets/mock',
  });
}
