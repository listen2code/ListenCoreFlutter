## 0.0.38
- **API Enhancements**:
    - Added `expandBody` boolean to `BaseLifecyclePage` to determine if the body should fill the parent container.
    - Updated the constructor to include `expandBody` with a default value of `true`.
- **Layout Logic**:
    - Updated the internal `Stack` to use `StackFit.expand` if either `useScaffold` or `expandBody` is true. This ensures full-screen behavior for tabs while allowing bottom sheets to wrap content by setting `expandBody` to false.
  
## 0.0.37
- **Lifecycle & Navigation Gesture**:
    - Updated `BaseLifeCyclePage` to evaluate page active state (`widget.active`) during pop gesture handling.
    - Prevented inactive background Tab pages inside layout stacks (like `IndexedStack`) from intercepting or hijacking the system back gesture (by enforcing `canPop: true` and returning early in `onPopInvokedWithResult` when the page is inactive).

## 0.0.36
- **Intent Handling**:
    - Updated `handleIntent` to accept an optional `needLogin` parameter.
    - Introduced `checkNeedLogin(intent)` to allow subclasses to define authentication requirements per intent.
- **Authentication Integration**:
    - Added static delegates `isUserAuthenticated` and `triggerLogin` to `BaseViewModel` to provide global access to authentication state and flows.
- **Guard Logic**:
    - Implemented interception logic in `handleIntent` that checks authentication status.
    - Added support for triggering a login flow and automatically re-dispatching the original intent after a successful login.
    - Included logging for intent interception, resumption, and cases where required delegates are missing.

## 0.0.35
- **UI & Layout Adaptability**:
    - Modified `BaseLifeCyclePage`'s root `Stack` fit constraint to be dynamic based on the `useScaffold` configuration.
    - Sets the `Stack` fit to `StackFit.expand` when `useScaffold` is `true` (standard for full-screen pages), and to `StackFit.loose` when `useScaffold` is `false` (standard for embedded panels, dialogs, and bottom sheets). This allows nested/embedded MVI lifecycle views to correctly wrap their content and adapt to natural content height instead of being stretched vertically.

## 0.0.34
- **Navigation Features**:
    - Added `routeChangeNotifier` to the `AppNav` class to allow components to listen to navigation events (push, pop, or replace).
    - Updated the `currentRouteName` setter to automatically trigger notifications when the route name is updated.
- **Refactoring**:
    - Introduced a private `_updateRoute` helper method in `_AppNavObserver` to centralize the logic for updating route arguments and names.
    - Simplified `didPush`, `didPop`, and `didReplace` by using the new unified state update logic.

## 0.0.33
- **Networking Enhancements**:
    - Introduced `CacheDataSource` abstract class in `base_repository.dart` to encapsulate data persistence logic.
    - Updated `BaseRepository.safeCall` to support `CacheDataSource`, automating cache retrieval and storage while maintaining backward compatibility with manual callbacks.
- **Lifecycle & UI Management**:
    - Centralized loading state dismissal by moving `LoadingEffect(false)` emission from `BaseViewModel.onDispose` to `BaseLifecyclePage`.
    - Added explicit `ProviderRegistry` calls to stop loading animations in `BaseLifecyclePage` during navigation events and widget disposal to prevent lingering UI states.

## 0.0.32
- **Asset Generation Control**:
    - Added `.flutter_assets_generator.yaml` configuration in package root to explicitly disable automatic `assets.dart` generation, preventing pollution of the `lib/generated` directory.

## 0.0.31
- **Refactoring & Single Responsibility**:
    - Extracted the bloated `api_client.dart` into single-responsibility interceptors inside the `network/interceptors/` directory (`logging_interceptor.dart`, `network_inspector_interceptor.dart`, `zone_context_interceptor.dart`, `auth_interceptor.dart`, `error_interceptor.dart`).
    - Decoupled delegation protocols and status codes into `network/api_delegate.dart`.
- **Clarity in Logging**:
    - Standardized all interceptor outputs to print full, clean `Uri` strings instead of relative `path` strings, providing visibility into hostnames for third-party endpoints.

## 0.0.30
- **Log & Obfuscation Protection**:
    - Introduced `typeName` property across `AppException` and `Failure` hierarchies to protect class name prints from AOT compiler obfuscation in release builds.
    - Simplified `safeCall` logs in `BaseRepository` and mapping logs in `_ErrorInterceptor` to avoid printing verbose raw DioException strings.
- **Extensions & Utils**:
    - Added `NullableStringExtension` helper (`isNullOrBlank`) to check nullable strings cleanly.
## 0.0.29
- **Lifecycle & Safety**:
    - **BaseLifeCyclePage**: Configured back key gesture to prioritize canceling network requests and dismissing loading spinner when `_isInternalLoading` is active.
    - **BaseViewModel**: Introduced `_activeEffectSubscription` tracking in `onBindEffect` to cancel older page subscriptions, resolving duplicate event dialogs during route replacement.
- **Navigation & AppNav**:
    - Refactored `AppNav.to` to add `replaceIfExists` parameters and ignore redundant navigation triggers when targeting active routes.
- **Dependencies & Metadata**:
    - Bumped package version to `0.0.29` in `pubspec.yaml`.

## 0.0.28
- **Deep Link Handling**:
    - Refactored `DeepLinkManager` from static methods to a singleton pattern.
    - Decoupled navigation logic by firing a `CommonEvent` via `EventBus` instead of calling `AppNav` directly.
    - Adjusted `init` sequence to subscribe to the link stream before processing the initial cold-start URI.
- **Navigation Enhancements**:
    - Updated `AppNav.to` to use `pushReplacement` instead of `push` if the target route is already the current route.
    - Relaxed type constraints in `getParam` and `getArgs` from `Map<String, dynamic>` to a general `Map` to improve compatibility with various data sources.
    - Added a public getter for `currentArgs`.
- **Lifecycle & Safety**:
    - **BaseViewModel**: Added `mounted` checks in `updateState` and `onComplete` logging to prevent operations on disposed view models.
    - **BaseLifecyclePage**: Introduced an `onPop` callback to `_RouteAwareProxy` to automatically cancel effect subscriptions when a page is popped.
- **Project Metadata**:
    - Bumped package version to `0.0.28` in `pubspec.yaml`.
    - Updated `CHANGELOG.md` to reflect deep link execution changes and dependency updates.
  
## 0.0.27
- **Architecture Enhancements**:
    - Introduced `DeepLinkManager` in `lib/route/deep_link_manager.dart` to manage link subscriptions and URI processing using the `app_links` package.
    - Integrated `DeepLinkManager` with `AppNav` to provide a default routing fallback for incoming URIs.
    - Added an `onLinkReceived` hook to allow the host app to intercept or pre-process links before navigation.
- **Core Library Update**:
    - Exported `deep_link_manager.dart` in `lib/core.dart` for public access.
- **Dependency Management**:
    - Added `app_links: ^6.3.3` to `pubspec.yaml` and updated `pubspec.lock`.

## 0.0.26
- **Deep Linking**:
    - Configured an `intent-filter` in `AndroidManifest.xml` to handle the `listen://` scheme.
    - Added a `schemes` list to `CoreInitializer` and `AppNavConfig` to facilitate stripping custom protocol prefixes during route resolution.
- **Navigation Enhancements**:
    - Introduced `ArgumentConverter` and a registration registry in `AppNav` to allow `getArgs<T>` to transform query parameter maps into type-safe objects.
    - Updated `AppNav.getParam` to automatically handle string-to-boolean conversion for parameters parsed from URIs.
    - Improved `_resolveRoute` logic to decode URI components and handle deep-link paths more robustly.
- **Core API**:
    - Added `registerArgumentConverter` to `AppNav` for defining custom decoding logic for route arguments.

## 0.0.25
- **Bug Fixes & Network Refinement**:
    - Corrected potential type mismatch error when processing server error messages in raw JSON payloads.
    - Standardized empty error body fallback behavior during network failure handling.
## 0.0.24
- **New Feature**:
    - Created `LaunchMonitor` in `lib/apm/launch_monitor.dart` to track specific lifecycle stages: main entry, initialization start/end, and first frame rendering.
    - Implemented `LaunchReport` data model to store timing metrics (cold boot, init, and render durations) with JSON serialization support.
- **Performance Analysis**:
    - Added regression detection logic that compares the current launch duration against the average of previous runs.
    - Integrated a `ValueNotifier` to expose the latest performance report to the UI.
- **Persistence**:
    - Added logic to store and retrieve a history of up to 50 launch records using `SpUtil`.
- **Public API**:
    - Exported `launch_monitor.dart` in `lib/core.dart` for centralized access.

## 0.0.23

- **Diagnostics**:
    - Updated `CrashManager` in `lib/utils/crash_manager.dart` to include the `Trace ID` from `ZoneManager` and the current navigation `Route` in generated crash reports.
- **Documentation**:
    - Added a new entry for version `0.0.23` in `CHANGELOG.md`.

## 0.0.22

- **Network Monitoring**:
    - Created `NetworkRequestEntry` in `lib/apm/network_inspector_store.dart` to model HTTP transaction data, including headers, payloads, timing, and error messages.
    - Implemented `NetworkInspectorStore` to manage a bounded in-memory buffer (FIFO, max 100 entries) of network transactions, utilizing `ValueNotifier` for reactive UI updates.
    - Added `_NetworkInspectorInterceptor` to `lib/network/api_client.dart` to automatically log network activity through the Dio client.
- **Core Integration**:
    - Exported `network_inspector_store.dart` in `lib/core.dart` to make the inspector store accessible throughout the application.
- **Code Maintenance**:
    - Performed minor cleanup of imports and formatting in `lib/base/base_view_model.dart`.

## 0.0.21

- **Refactoring & Single Responsibility Principles**:
    - Split the bloated `base_view_model.dart` file into four dedicated, cohesive files under `lib/base/`:
        - `page_lifecycle.dart` (containing `PageLifecycle` lifecycle callbacks).
        - `base_state.dart` (containing `BaseState` and `BaseIntent` definitions).
        - `active_view_models.dart` (containing `ActiveViewModels` registration cache and `MviPlaybackObserver`).
        - `base_view_model.dart` (containing core `IStateOwner`, `BaseViewModel` and `ViewModelMixin` orchestrator).
    - Utilized Dart export directives to ensure 100% backward compatibility for all downstream clients.

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
- **AppNav & Lifecycle Observers**:
    - Added `onRoutePushed` and `onRoutePopped` callback hooks in `AppNav` to allow view models and routers to subscribe to route push/pop lifecycle transitions.

## 0.0.15
- **Fix: SpUtil**:
    - Resolved key serialization issues in `SpUtil` when storing complex configurations.

## 0.0.14
- **Upgrade Dio**:
    - Upgraded `dio` dependency to the latest major version and refactored request options configuration to align with the new API.

## 0.0.13
- **Fix Bug: effectController.isClosed**:
    - Added a safe guard check to prevent sending events to the disposed stream controller `effectController`, resolving `StateError: Cannot add event after close`.

## 0.0.12
- **MviPlaybackObserver**:
    - Introduced `MviPlaybackObserver` to enable record-and-playback features for MVI intents and states during testing and visual debugging.

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
