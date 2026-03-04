# Listen Core

A professional, high-performance core architecture framework for Flutter applications. Designed to provide a unified foundation for enterprise-level development with a focus on lifecycle management, robust networking, and structured logging.

## 🚀 Features

### 🏗 Architecture & Lifecycle
- **BaseLifeCyclePage**: A unified page wrapper that handles:
  - Automatic `onInit`, `onReady`, `onResume`, `onPause`, `onVisible`, `onInVisible` lifecycle callbacks.
  - Built-in **Loading** and **Empty** state management with custom UI support.
  - **Safety Timer** to prevent permanent loading UI locks.
  - Automatic request cancellation on back navigation.
- **BaseMaterialApp**: A drop-in replacement for `MaterialApp` that pre-configures:
  - Global `NavigatorKey` for contextless navigation.
  - `RouteObserver` for page tracking.
  - Performance monitoring via `ZoneManager`.

### 🌐 Networking & Mocking
- **LocalMockServer**: An in-app HTTP server (port 9999) that maps API requests to local JSON assets.
  - Supports versioning (e.g., `/v1/get/user` -> `assets/mock/v1/get/user.json`).
  - Simulates network latency and logs request/response bodies.
- **UseCase Pattern**: Standardized functional error handling using `fpdart`'s `Either<Failure, T>`.
- **NetworkInfo**: Real-time connectivity monitoring.

### 📝 Logging & Diagnostics
- **ZoneManager**: Captures unhandled exceptions and tracks execution performance across async boundaries.
- **AppLogger**: Structured logging with severity levels, JSON formatting, and `X-Trace-Id` correlation for distributed tracing.
- **CrashManager**: Centralized error reporting and crash analysis.

### 💾 Storage & Utilities
- **SpUtil**: Synchronous-access wrapper for `SharedPreferences` with JSON support.
- **SecureStorageUtil**: Encrypted storage for sensitive data (Tokens, Keys).
- **Device & Package Info**: Quick access to device hardware and app version details.

## 📦 Getting Started

Add `listen_core` to your `pubspec.yaml`:

```yaml
dependencies:
  listen_core:
    git:
      url: https://github.com/listen2code/ListenCoreFlutter.git
```

## 🛠 Usage

### 1. Global Initialization

```dart
void main() async {
  // 1. Wrap the entire app in a performance & error tracking Zone
  ZoneManager.run(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    // 2. Initialize essential services
    await SpUtil.init();
    await SecureStorageUtil.init();
    
    // 3. Start Mock Server in Debug Mode
    if (kDebugMode) {
      await LocalMockServer.start();
    }

    runApp(const ProviderScope(child: MyApp()));
  });
}
```

### 2. Standardized Page Development

Inherit your UI from `BaseLifeCyclePage` to get automatic lifecycle and state handling:

```dart
class MyPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModel = ref.watch(myViewModelProvider);
    
    return BaseLifeCyclePage(
      title: 'My Profile',
      viewModel: viewModel,
      onLoading: const MySkeletonLoader(), // Automatic loading UI
      body: (context, child) => ListView(
        children: [ ... ],
      ),
    );
  }
}
```

### 3. Functional UseCases

```dart
class GetUserUseCase extends UseCase<User, String> {
  @override
  Future<Either<Failure, User>> call(String userId) async {
    // Business logic here...
  }
}
```

## 🛠 Requirements
- Flutter: `>=3.10.1`
- Dart: `^3.10.1`

## 📄 License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
