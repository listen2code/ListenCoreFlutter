# listen_core

A robust core library for Flutter applications, providing essential architecture components, network utilities, and shared services.

## Features

- **Base Architecture**: standard `BaseLifecyclePage` and `BaseProvider` for consistent state management.
- **Enhanced Logging**: Integrated `LogManager` and `Logger` for structured console output and trace tracking.
- **Global Error Handling**: `CrashManager` and `ZoneManager` to catch and report unhandled exceptions.
- **Local Storage**: Simple wrappers for `SharedPreferences` (`SpUtil`) and `FlutterSecureStorage` (`SecureStorageUtil`).
- **Network Tools**:
  - `NetworkInfo` for connectivity checks.
  - `LocalMockServer`: A built-in HTTP server to simulate API responses using local assets during development.
- **Extensions**: Useful `Ref` extensions for Riverpod.

## Getting started

Add `listen_core` to your `pubspec.yaml`:

```yaml
dependencies:
  listen_core:
    git:
      url: https://github.com/listen2code/ListenCoreFlutter.git
```

## Usage

### 1. Initialization

Initialize the core utilities in your `main()`:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize storage
  await SpUtil.init();
  await SecureStorageUtil.init();
  
  // Start mock server if in debug mode
  if (kDebugMode) {
    await LocalMockServer.start();
  }

  runApp(const ProviderScope(child: MyApp()));
}
```

### 2. Using Local Storage

```dart
// Save data
await SpUtil.put('user_token', 'abc_123');

// Get data
String? token = SpUtil.getString('user_token');
```

### 3. Mock Server

`LocalMockServer` allows you to point your API base URL to `http://localhost:9999` and serve JSON files from your `assets/mock` directory. It matches paths based on method and version (e.g., `assets/mock/v1/get/user.json`).

## Additional information

For more details on contribution or reporting issues, please visit the [repository](https://github.com/listen2code/ListenCoreFlutter).
