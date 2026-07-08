## 0.0.20

- **Page-Associated Jank Diagnostics**:
    - Added `routeName` field to `FrameMetric` class to track the currently active page.
    - Integrated with global `AppNav.currentRouteName` during frame telemetry collection inside `FrameMonitor._onTimings`.

## 0.0.19

- **True Latency Calculation Refactor**:
    - Replaced `FrameTiming.totalSpan` with pure `buildDuration + rasterDuration` for the frame latency calculation (`totalUs`).
    - Excluded system-level pipeline scheduling delays and thread wait times, resolving false-positive Jank reports and preventing layout charts from pinning to the top boundary.

## 0.0.18

- **FPS Physical Timeline Refactor**:
    - Replaced `DateTime.now()` wall-clock timestamps with physical GPU `vsyncStartUs` tick offsets inside `FrameMetric`.
    - Resolved the critical divide-by-tiny-delta FPS calculation bug during Flutter's batch timing callbacks, ensuring FPS metrics remain mathematically robust and under physical limits.
- **RingBuffer Enhancement**:
    - Added `isNotEmpty` read-only getter to `RingBuffer` utility for cleaner UI state checks.

## 0.0.17

- **Frame Performance Monitoring**:
    - Created `FrameMonitor` to capture and analyze Flutter engine `FrameTiming`.
    - Implemented adaptive vsync budget detection and jank tracking (standard and severe).
    - Added real-time FPS calculation using Exponential Moving Average (EMA) for smoothing.
    - Included periodic RSS memory sampling.
- **Execution & Zone Tracing**:
    - Enhanced `ZoneManager` to broadcast `ZonePerfRecord` events upon completion of asynchronous tasks.
    - Introduced `PerfTraceStore` to maintain a capped history of structured execution timelines and milestones.
- **High-Performance Utilities**:
    - Implemented `RingBuffer`, a fixed-capacity circular buffer designed to minimize GC pressure during high-frequency telemetry collection.
- **Core Integration**:
    - Updated `lib/core.dart` to export new performance utilities: `FrameMonitor`, `PerfTraceStore`, and `RingBuffer`.
    - Integrated reactive updates using `ValueNotifier` to drive performance overlays and debugging tools.


## 0.0.16

* **AppNav: onRoutePushed, onRoutePopped**:

## 0.0.15

* **Fix: SpUtil**:

## 0.0.14

* **Upgrade Dio**:

## 0.0.13

* **Fix Bug:effectController.isClosed**:

## 0.0.12

* **MviPlaybackObserver**:

## 0.0.11

* **ViewModel Log Fix**:
    * Fix runtimeType.toString to element.provider

## 0.0.10

* **ViewModel Native Lifecycle Hook**:
    * Integrated with Riverpod's `ref.onDispose` hook to handle resource cleanup natively when the provider is unmounted, rather than relying on widget page disposals. This resolves issues when the same page is pushed multiple times onto the navigation stack.
    * Changed `onBindEffect` to return a `StreamSubscription<BaseEffect>`, allowing UI widgets to manage and cancel their own subscriptions upon disposal to prevent page-level memory leaks.
    * Added `currentArgs` visibleForTesting setter to `AppNav` to ease route parameter mocking in unit tests.

## 0.0.9

* **Push Notification Enhancements**:
    * Added `subscribeToTopic` and `unsubscribeFromTopic` to `INotificationService` interface.

## 0.0.8

* **Push Notification Service Abstraction**:
    * Added `INotificationService` interface and `NotificationPayload` class under `lib/services/notification_service.dart`.
    * Translated all code comments in the notification service module to English.

## 0.0.7

* **Route Navigation Enhancements**:
    * Refined generic type constraints (`T extends Object?`) for `AppNav` methods (`to`, `off`, `offAll`, `back`) to ensure compatibility with strict Dart type inference rules.

## 0.0.6

* **Error Codes Mapping**:
    * Integrated a unified `ErrorMapper` to automatically intercept and localize network and system failure codes into multi-lingual (Chinese & Japanese) user-friendly messages.
    * Integrated `ErrorMapper.map` inside `ViewModelMixin.handleFailure` to map all exceptions before rendering.

## 0.0.5

* **Environment Update**:
    * Upgraded environment SDK constraints to Dart `^3.12.1` to support Flutter `3.44.1`.
* **Code Quality**:
    * Fixed HTML conflict warnings in `BaseViewModel` and `SpUtil` doc comments.

## 0.0.4

* **Documentation**:
    * Added comprehensive multilingual README with English, Chinese, and Japanese support
    * Expanded usage examples from 3 to 10 sections covering all core features
    * Added detailed "Apps Using ListenCore" section featuring ListenPortfolioFlutter

* **API Documentation**:
    * Added comprehensive DartDoc comments to BaseViewModel, ViewModelMixin, and PageLifecycle
    * Documented ApiClient and IApiInterceptorDelegate for authentication and tracing
    * Added technical documentation for NetworkConfig, HttpCode, and logging infrastructure

* **Architecture Enhancements**:
    * Refined BaseViewModel structure with clearer separation of concerns
    * Improved ViewModelMixin with better event subscription and request cancellation management

## 0.0.3

* **Documentation & Architecture**:
    * Merged `core-architecture.md` into `README.md` for a unified technical overview.
    * Added a comprehensive publishing guide (`docs/publish.md`) for `pub.dev`.
* **Tooling Improvements**:
    * Optimized `LocalMockServer` path resolution logic to automatically match JSON files based on HTTP methods and versioned URL paths (e.g., `[DELETE] /v1/user` -> `json/v1/delete/user.json`).
* **Dependency Management**:
    * Resolved a version solving conflict by unifying `listen_core` as a path dependency across all local modules (`ListenUiKit` and main app).

## 0.0.2

* Fixed `dart analyze` warnings:
    * Removed unused variable in `LocalMockServer`.
    * Removed deprecated `encryptedSharedPreferences` parameter in `SecureStorageUtil`.
    * Fixed HTML conflict in `SpUtil` doc comments.
* Updated `pubspec.yaml` with repository information.
* Added `device_info_plus` and `package_info_plus` dependencies.
* Refined `README.md` and updated `LICENSE`.

## 0.0.1

* Initial release of Listen Core.
