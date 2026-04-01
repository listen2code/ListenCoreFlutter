# Listen Core

A professional, high-performance core architecture framework for Flutter applications. Designed to provide a unified foundation for enterprise-level development with a focus on lifecycle management, robust networking, and structured logging.

---

## 🏗️ Architecture Design

### Design Principles
- **Zero Business Coupling**: No business logic included, completely generic and reusable.
- **High Cohesion & Low Coupling**: Modular design allows for independent extraction and publication.
- **Highly Configurable**: Flexible behavior customization via dedicated configuration classes.
- **Production Ready**: Built-in error handling, structured logging, and performance monitoring.

### Module Structure
```
lib/core/
├── base/           # Architecture Layer (ViewModel, Lifecycle, Scaffolds)
├── config/         # Configuration Management (Network, Logs, Mocking)
├── env/            # Environment & Secret Management
├── errors/         # Unified Error & Failure Handling
├── i18n/           # Internationalization Support
├── network/        # Networking (Dio, Interceptors, Mock Server)
├── route/          # Routing & Navigation Interceptors
└── utils/          # Utilities (Logging, Storage, Zones, Crash Protection)
```

---

## 🚀 Key Modules & Features

### 1. Base Architecture & Lifecycle (`base/`)
- **BaseLifeCyclePage**: A unified page wrapper handling:
  - Automatic `onInit`, `onReady`, `onResume`, `onPause`, `onVisible`, `onInVisible`.
  - Built-in **Loading**, **Empty**, and **Error** state management.
  - **Safety Timer** to prevent UI locks and automatic request cancellation.
- **BaseViewModel (MVI)**: State-driven logic with built-in side-effect management.
- **BaseMaterialApp**: Pre-configured with `NavigatorKey`, `RouteObserver`, and `ZoneManager`.

### 2. Networking & Mocking (`network/`)
- **ApiClient**: Robust HTTP client with:
  - Automatic token refresh & request queuing.
  - X-Trace-Id correlation for distributed tracing.
- **LocalMockServer**: An in-app HTTP server (port 9898) mapping API requests to local JSON assets.
  - Supports versioning (e.g., `/v1/user` -> `json/v1/get/user.json`).
  - Simulates network latency and logs request/response details.
- **UseCase Pattern**: Standardized functional error handling using `fpdart`'s `Either<Failure, T>`.

### 3. Logging & Diagnostics (`utils/`)
- **ZoneManager**: Captures unhandled exceptions and tracks async performance.
- **AppLogger**: Structured logging with severity levels and JSON formatting.
- **CrashManager**: Centralized error reporting, safety mode, and automatic recovery.

### 4. Storage & Utilities (`utils/`)
- **SpUtil**: Synchronous wrapper for `SharedPreferences` with JSON support.
- **SecureStorageUtil**: Encrypted storage for sensitive data.
- **Device & Package Info**: Quick access to hardware and app metadata.

---

## 📦 Getting Started

Add `listen_core` to your `pubspec.yaml`:

```yaml
dependencies:
  listen_core:
    path: ../ListenCore
```

---

## 🛠 Usage

### 1. Global Initialization

```dart
void main() async {
  // 1. Run in a managed Zone for error tracking
  ZoneManager.run(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    // 2. Initialize core services
    await Core.init(CoreConfig.defaultConfig());
    
    // 3. Start Mock Server in Debug Mode
    if (kDebugMode) {
      await LocalMockServer.start();
    }

    runApp(const ProviderScope(child: MyApp()));
  });
}
```

### 2. Lifecycle Managed Page

```dart
class MyPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModel = ref.watch(myViewModelProvider);
    
    return BaseLifeCyclePage(
      title: 'My Profile',
      viewModel: viewModel,
      body: (context, child) => ListView( ... ),
    );
  }
}
```

---

## 🎯 Target Use Cases
- **Enterprise Applications**: Requiring a solid, scalable architecture.
- **Fast Prototyping**: Quickly setting up a standardized infrastructure.
- **Multi-App Ecosystems**: Sharing a unified tech stack across different projects.

## 🔮 Roadmap
- [ ] Support for Web and Desktop platforms.
- [ ] Integration with more 3rd-party monitoring services (Sentry/Firebase).
- [ ] Visual configuration tool for `CoreConfig`.
- [ ] Enhanced unit test coverage for the network layer.

## 🛠 Requirements
- Flutter: `>=3.10.1`
- Dart: `^3.10.1`

## 📄 License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
