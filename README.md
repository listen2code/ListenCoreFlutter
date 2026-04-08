# Listen Core

ListenCore is the reusable infrastructure layer extracted from `ListenPortfolioFlutter`.
It focuses on business-agnostic application foundations such as lifecycle management, networking, routing primitives, tracing, crash protection, and shared utilities.
It is not an app assembly layer, a reusable UI kit, or a complete cross-platform framework.

## 🔗 Links

- **📦 [pub.dev](https://pub.dev/packages/listen_core)**
- **🐙 [GitHub Repository](https://github.com/listen2code/ListenCoreFlutter)**
- **🚀 [Example App](https://github.com/listen2code/ListenPortfolioFlutter)**

---

## 🎯 Positioning

ListenCore is the reusable infrastructure layer behind `ListenPortfolioFlutter`. It is intended for **business-agnostic application foundations**, not for app-specific assembly logic, design-system widgets, or developer overlay UI.

This README prioritizes:

- **Current implemented capabilities**
- **Clear package boundaries**
- **Known limitations and target state separation**

## 🧱 Current Package Scope

### Included today

- **MVI primitives**: `BaseViewModel`, `BaseState`, `BaseEffect`, provider registry
- **Lifecycle wrappers**: `BaseLifeCyclePage`, `BaseScaffoldPage`, `BaseMaterialApp`
- **Networking**: `ApiClient`, `BaseRepository`, `BaseResponseModel`, `UseCase`, connectivity abstraction
- **Tracing & crash protection**: `ZoneManager`, `CrashManager`, `Core.run()`
- **Routing primitives**: `AppNav`, route interceptors, auth interception hooks
- **Environment & i18n**: `AppEnv`, `Translations`
- **Utilities**: logging, event bus, validators, storage, package/device info, mock server

### Not part of ListenCore's responsibility

- App-specific navigation/share effects
- Theme strategy or design tokens
- Reusable UI widget library
- App-specific debug overlays such as log floating windows

## 🔀 Boundary Comparison

| Layer | Primary responsibility | Not responsible for | Typical examples |
|-------|------------------------|---------------------|------------------|
| `ListenCore` | Application infrastructure primitives and runtime foundations | App-specific page assembly, reusable visual widget set, brand theme strategy | `BaseViewModel`, `ApiClient`, `AppNav`, `ZoneManager` |
| `ListenUiKit` | Reusable presentation, input, and feedback widgets | Lifecycle management, networking, crash protection, environment setup | `CommonButton`, `CommonDialog`, `CommonEmptyView` |
| App / shared layer | Business features, screen composition, feature-specific flows, product rules | Re-defining generic infrastructure or generic widget packages inside shared libraries | Feature pages, app-specific providers, domain workflows |

## 🏗️ Module Structure

```dart
lib/
├── base/           # ViewModel, lifecycle pages, base app wrappers
├── config/         # Network / log / storage / mock server configuration
├── env/            # Environment registration and switching
├── errors/         # Exceptions and failures
├── i18n/           # Translation registry
├── network/        # ApiClient, repository helpers, response model, use case
├── route/          # Navigation primitives and interceptors
└── utils/          # Logging, crash protection, storage, event bus, validators
```

## ✅ Current Highlights

### 1. Lifecycle & MVI foundation

- `BaseLifeCyclePage` coordinates page lifecycle callbacks such as `onInit`, `onReady`, `onVisible`, `onResume`, and `onDispose`.
- It can overlay custom loading / empty widgets when provided, and includes a loading safety timeout.
- `BaseViewModel` centralizes intent handling, effect emission, request cancellation, and event subscriptions.

### 2. Network foundation

- `ApiClient` provides a multi-interceptor Dio setup with trace propagation, auth injection, refresh retry queueing, and error mapping.
- `BaseRepository.safeCall()` standardizes repository error handling with `Either<Failure, T>`.
- `LocalMockServer` serves local mock assets for offline/mobile debug scenarios.

### 3. Runtime infrastructure

- `Core.init()` assembles storage, event bus, providers, network config, environment, i18n, navigation hooks, and logging.
- `Core.run()` wraps the app in a guarded zone and persists crash logs before delegating UI recovery.
- `ZoneManager` supports `traceId` propagation and lightweight performance marks.

### 4. Utilities

- `LogManager` stores structured log entries for in-app consumption.
- `CrashManager` provides local crash persistence and Safe Mode reset hooks.
- `SpUtil`, `SecureStorageUtil`, `eventBus`, validators, and package/device info helpers are included.

## Current Limitations

- Web / Desktop support is incomplete.
- `LocalMockServer` depends on `dart:io`, so it is not Web-compatible.
- Route parameters are not fully type-safe.
- `CacheManager` is currently a cache cleanup utility, not a full data caching framework.
- Test coverage is still far from where a mature reusable framework should be.

## Target State

- Improve platform coverage without overstating current Web / Desktop readiness.
- Strengthen test coverage around lifecycle, routing, and networking behavior.
- Continue clarifying boundaries between infrastructure primitives, UI widgets, and app-specific assembly code.

## Pending Cleanup Backup

- Older README revisions described ListenCore with stronger framework-marketing language than the current implementation supports.
- The current README intentionally narrows the narrative to exported infrastructure capabilities and known limits.

## Getting Started

Add `listen_core` to your `pubspec.yaml`:

```bash
dart pub add listen_core:0.0.4
```

Or add it manually:

```yaml
dependencies:
  listen_core: ^0.0.4
```

**🔗 [View on pub.dev](https://pub.dev/packages/listen_core)**

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

### 3. Network Request with UseCase

```dart
class GetUserUseCase extends UseCase<User, String> {
  final ApiClient _apiClient;
  
  GetUserUseCase(this._apiClient);
  
  @override
  Future<Either<Failure, User>> call({String? param}) async {
    final userId = param!;
    return await _apiClient.get('/users/$userId').then(
      (response) => Right(User.fromJson(response.data)),
      onError: (error) => Left(ServerApiFailure('Failed to get user')),
    );
  }
}
```

### 4. Event Bus Communication

```dart
// Define events
class UserUpdatedEvent extends BaseEvent {
  final User user;
  UserUpdatedEvent(this.user);
}

// Emit events
eventBus.emit(UserUpdatedEvent(updatedUser));

// Listen to events in ViewModels
class UserViewModel with ViewModelMixin<UserState, UserIntent> {
  @override
  void onInit() {
    super.onInit();
    subscribeEvent<UserUpdatedEvent>((event) {
      updateState(state.copyWith(user: event.user));
    });
  }
}
```

---

# 中文

ListenCore 是从 `ListenPortfolioFlutter` 抽离出的可复用基础设施层。
它聚焦于业务无关的应用底座能力，例如生命周期管理、网络、路由基础能力、链路追踪、崩溃保护与通用工具。
它不是 App 组装层、可复用 UI 组件库，也不是一个完整的跨平台框架。

## 🔗 链接

- **📦 [pub.dev](https://pub.dev/packages/listen_core)**
- **🐙 [GitHub 仓库](https://github.com/listen2code/ListenCoreFlutter)**
- **🚀 [示例应用](https://github.com/listen2code/ListenPortfolioFlutter)**

---

## 🎯 定位

ListenCore 是从 `ListenPortfolioFlutter` 抽离出的可复用基础设施层，面向**业务无关的应用底座能力**，而不是 App 专属组装逻辑、设计系统组件库或开发者浮窗 UI。

本 README 优先强调：

- **当前已经落地的能力**
- **清晰的包边界**
- **把现状与目标态分开描述**

## 🧱 当前包范围

### 已包含

- **MVI 基础类**：`BaseViewModel`、`BaseState`、`BaseEffect`、provider registry
- **生命周期包装**：`BaseLifeCyclePage`、`BaseScaffoldPage`、`BaseMaterialApp`
- **网络基础设施**：`ApiClient`、`BaseRepository`、`BaseResponseModel`、`UseCase`
- **链路追踪与崩溃保护**：`ZoneManager`、`CrashManager`、`Core.run()`
- **导航基础能力**：`AppNav`、route interceptors、auth interception hooks
- **环境与国际化**：`AppEnv`、`Translations`
- **通用工具**：日志、event bus、validator、存储、设备/包信息、MockServer

### 不属于 ListenCore 的职责

- App 专属的导航 / 分享 effect
- 主题策略或 design tokens
- 可复用 UI 组件库
- App 专属的调试浮窗与开发者面板 UI

## 🔀 模块边界对照

| 层级 | 主要职责 | 不负责什么 | 典型示例 |
|------|----------|------------|----------|
| `ListenCore` | 应用基础设施原语与运行时底座 | App 专属页面组装、可复用视觉组件集、品牌主题策略 | `BaseViewModel`、`ApiClient`、`AppNav`、`ZoneManager` |
| `ListenUiKit` | 可复用展示、输入、反馈组件 | 生命周期管理、网络、崩溃保护、环境初始化 | `CommonButton`、`CommonDialog`、`CommonEmptyView` |
| App / shared 层 | 业务功能、页面组装、特性流程、产品规则 | 在共享库中重新定义通用基础设施或通用组件包 | 功能页面、App 专属 provider、领域流程编排 |

## 🏗️ 模块结构

```dart
lib/
├── base/           # ViewModel、生命周期页面、基础应用包装
├── config/         # 网络 / 日志 / 存储 / MockServer 配置
├── env/            # 环境注册与切换
├── errors/         # Exceptions 与 Failures
├── i18n/           # 翻译注册
├── network/        # ApiClient、Repository 辅助、响应模型、UseCase
├── route/          # 导航原语与拦截器
└── utils/          # 日志、崩溃保护、存储、event bus、validator
```

## ✅ 当前亮点

### 1. 生命周期与 MVI 基础

- `BaseLifeCyclePage` 负责 `onInit`、`onReady`、`onVisible`、`onResume`、`onDispose` 等回调协同。
- 当调用方提供 `onLoading` / `onEmpty` 时，它可以自动叠加对应状态视图，并带有 loading safety timeout。
- `BaseViewModel` 负责 intent 处理、副作用分发、请求取消与事件订阅。

### 2. 网络基础设施

- `ApiClient` 提供多层 Dio 拦截器：trace 传播、认证注入、refresh 重试队列、错误映射。
- `BaseRepository.safeCall()` 用 `Either<Failure, T>` 收敛仓储层错误处理。
- `LocalMockServer` 支持离线 / 调试场景下的本地 mock 资源服务。

### 3. 运行时基础设施

- `Core.init()` 负责装配存储、事件总线、providers、网络配置、环境、i18n、导航 hook、日志等。
- `Core.run()` 在受保护的 Zone 中运行应用，并在交给业务层处理前先持久化崩溃日志。
- `ZoneManager` 支持 `traceId` 传播与轻量性能打点。

### 4. 通用工具

- `LogManager` 负责结构化日志存储，供应用层消费。
- `CrashManager` 提供本地 crash 持久化与 Safe Mode reset hook。
- `SpUtil`、`SecureStorageUtil`、`eventBus`、validator、设备/包信息工具均已提供。

## ⚠️ 当前限制

- Web / Desktop 支持仍不完整。
- `LocalMockServer` 依赖 `dart:io`，因此不支持 Web。
- 路由参数还不是完全类型安全。
- `CacheManager` 当前更接近缓存清理工具，而不是完整的数据缓存框架。
- 测试覆盖距离成熟可复用框架仍有明显差距。

## 🔮 目标态

- 在不夸大当前 Web / Desktop 状态的前提下，逐步提升平台覆盖。
- 补强生命周期、路由与网络行为相关的测试覆盖。
- 继续明确基础设施能力、UI 组件层与 App 组装层之间的边界。

## 🗂️ 待删除备份区

- 旧版 README 曾使用比当前实现更强的“框架型宣传口径”。
- 当前 README 刻意收窄为已导出的基础设施能力与已知限制。

## 📦 快速开始

将 `listen_core` 添加到您的 `pubspec.yaml`：

```bash
dart pub add listen_core:0.0.4
```

或手动添加：

```yaml
dependencies:
  listen_core: ^0.0.4
```

**🔗 [在 pub.dev 上查看](https://pub.dev/packages/listen_core)**

## 🛠 使用方法

### 1. 全局初始化

```dart
void main() async {
  // 1. 在受保护的 Zone 中运行以进行错误跟踪
  ZoneManager.run(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    // 2. 初始化核心服务
    await Core.init(CoreConfig.defaultConfig());
    
    // 3. 在调试模式下启动模拟服务器
    if (kDebugMode) {
      await LocalMockServer.start();
    }

    runApp(const ProviderScope(child: MyApp()));
  });
}
```

### 2. 生命周期管理页面

```dart
class MyPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModel = ref.watch(myViewModelProvider);
    
    return BaseLifeCyclePage(
      title: '我的资料',
      viewModel: viewModel,
      body: (context, child) => ListView( ... ),
    );
  }
}
```

### 3. 使用UseCase的网络请求

```dart
class GetUserUseCase extends UseCase<User, String> {
  final ApiClient _apiClient;
  
  GetUserUseCase(this._apiClient);
  
  @override
  Future<Either<Failure, User>> call({String? param}) async {
    final userId = param!;
    return await _apiClient.get('/users/$userId').then(
      (response) => Right(User.fromJson(response.data)),
      onError: (error) => Left(ServerApiFailure('获取用户失败')),
    );
  }
}
```

### 4. 事件总线通信

```dart
// 定义事件
class UserUpdatedEvent extends BaseEvent {
  final User user;
  UserUpdatedEvent(this.user);
}

// 发送事件
eventBus.emit(UserUpdatedEvent(updatedUser));

// 在ViewModel中监听事件
class UserViewModel with ViewModelMixin<UserState, UserIntent> {
  @override
  void onInit() {
    super.onInit();
    subscribeEvent<UserUpdatedEvent>((event) {
      updateState(state.copyWith(user: event.user));
    });
  }
}
```

---

# 日本語

ListenCore は `ListenPortfolioFlutter` から切り出した再利用可能な基盤レイヤーです。
主な対象は、ライフサイクル管理、ネットワーク、ルーティングの基礎機能、トレーシング、クラッシュ保護、共通ユーティリティといったビジネス非依存のアプリ基盤です。
App の組み立て層、再利用 UI キット、完全なクロスプラットフォームフレームワークではありません。

## 🔗 リンク

- **📦 [pub.dev](https://pub.dev/packages/listen_core)**
- **🐙 [GitHub リポジトリ](https://github.com/listen2code/ListenCoreFlutter)**
- **🚀 [サンプルアプリ](https://github.com/listen2code/ListenPortfolioFlutter)**

---

## 🎯 位置づけ

ListenCore は `ListenPortfolioFlutter` の背後にある再利用可能な基盤レイヤーであり、対象は**ビジネス非依存のアプリ基盤機能**です。App 固有の組み立てロジック、デザインシステム部品、開発者向けオーバーレイ UI は責務に含みません。

この README では次を優先します：

- **現在実装されている能力**
- **明確なパッケージ境界**
- **現状と目標状態の分離**

## 🧱 現在のパッケージ範囲

### 現在含まれるもの

- **MVI 基盤**：`BaseViewModel`、`BaseState`、`BaseEffect`、provider registry
- **ライフサイクル系ラッパー**：`BaseLifeCyclePage`、`BaseScaffoldPage`、`BaseMaterialApp`
- **ネットワーク基盤**：`ApiClient`、`BaseRepository`、`BaseResponseModel`、`UseCase`
- **トレーシングとクラッシュ保護**：`ZoneManager`、`CrashManager`、`Core.run()`
- **ナビゲーション基盤**：`AppNav`、route interceptors、認証介入 hook
- **環境と i18n**：`AppEnv`、`Translations`
- **共通ユーティリティ**：ログ、event bus、validator、ストレージ、端末 / パッケージ情報、MockServer

### ListenCore の責務ではないもの

- App 固有の navigation / share effect
- テーマ戦略や design tokens
- 再利用 UI ウィジェット集
- App レベルのデバッグ浮動ウィンドウ UI

## 🔀 境界比較

| レイヤー | 主な責務 | 責務ではないもの | 代表例 |
|----------|----------|------------------|--------|
| `ListenCore` | アプリ基盤のプリミティブと実行時基盤 | App 固有ページの組み立て、再利用 UI 部品集、ブランドテーマ戦略 | `BaseViewModel`、`ApiClient`、`AppNav`、`ZoneManager` |
| `ListenUiKit` | 再利用可能な表示・入力・フィードバック部品 | ライフサイクル管理、ネットワーク、クラッシュ保護、環境初期化 | `CommonButton`、`CommonDialog`、`CommonEmptyView` |
| App / shared レイヤー | ビジネス機能、画面構成、機能フロー、プロダクトルール | 共通ライブラリ内で汎用基盤や汎用 UI パッケージを再定義すること | 機能ページ、App 固有 provider、ドメインフロー |

## 🏗️ モジュール構造

```dart
lib/
├── base/           # ViewModel、ライフサイクルページ、ベースアプリラッパー
├── config/         # ネットワーク / ログ / ストレージ / MockServer 設定
├── env/            # 環境登録と切り替え
├── errors/         # Exceptions と Failures
├── i18n/           # 翻訳登録
├── network/        # ApiClient、Repository 辅助、レスポンスモデル、UseCase
├── route/          # ナビゲーション原語とインターセプター
└── utils/          # ログ、クラッシュ保護、ストレージ、event bus、validator
```

## ✅ 現在のハイライト

### 1. ライフサイクルと MVI 基盤

- `BaseLifeCyclePage` は `onInit`、`onReady`、`onVisible`、`onResume`、`onDispose` などを協調します。
- `onLoading` / `onEmpty` が渡された場合は対応する状態 UI を重ねられ、loading safety timeout も備えます。
- `BaseViewModel` は intent 処理、副作用分配、リクエスト取消、イベント購読を担います。

### 2. ネットワーク基盤

- `ApiClient` は trace 伝播、認証注入、refresh retry queue、エラー変換を含む多段 Dio インターセプターを提供します。
- `BaseRepository.safeCall()` は `Either<Failure, T>` で Repository 層のエラー処理を標準化します。
- `LocalMockServer` はオフライン / デバッグ用途のローカル mock 配信を支えます。

### 3. 実行時基盤

- `Core.init()` はストレージ、event bus、providers、ネットワーク設定、環境、i18n、ナビゲーション hook、ログ等を組み立てます。
- `Core.run()` は受保護の Zone でアプリを実行し、UI へ委譲する前にクラッシュログを永続化します。
- `ZoneManager` は `traceId` 伝播と軽量な性能マークをサポートします。

### 4. 共通ユーティリティ

- `LogManager` は構造化ログを保持し、App 層で消費されます。
- `CrashManager` はローカル crash 持久化と Safe Mode reset hook を提供します。
- `SpUtil`、`SecureStorageUtil`、`eventBus`、validator、端末 / パッケージ情報ユーティリティが含まれます。

## ⚠️ 現在の制約

- Web / Desktop サポートはまだ不完全です。
- `LocalMockServer` は `dart:io` 依存のため Web 非対応です。
- ルート引数はまだ完全な型安全ではありません。
- `CacheManager` は現在、完全なデータキャッシュ基盤というよりキャッシュ削除ユーティリティに近いです。
- テストカバレッジは成熟した再利用フレームワーク水準にはまだ届いていません。

## 🔮 目標状態

- 現在の Web / Desktop 状態を誇張せずに、段階的にプラットフォーム対応を広げる。
- ライフサイクル、ルーティング、ネットワーク挙動に関するテストカバレッジを強化する。
- 基盤機能、UI コンポーネント層、App 固有の組み立てコードの境界をさらに明確にする。

## 🗂️ 保留中のバックアップ

- 以前の README には、現在の実装以上にフレームワーク性を強く見せる表現が含まれていました。
- 現在の README は、公開されている基盤機能と既知の制約に意図的に絞っています。

## 📦 始め方

`listen_core` を `pubspec.yaml` に追加：

```bash
dart pub add listen_core:0.0.4
```

または手動で追加：

```yaml
dependencies:
  listen_core: ^0.0.4
```

**🔗 [pub.dev で見る](https://pub.dev/packages/listen_core)**

## 🛠 使用方法

### 1. グローバル初期化

```dart
void main() async {
  // 1. 受保護の Zone で実行してエラーを追跡する
  ZoneManager.run(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    // 2. コアサービスを初期化する
    await Core.init(CoreConfig.defaultConfig());
    
    // 3. デバッグモードでモックサーバーを起動する
    if (kDebugMode) {
      await LocalMockServer.start();
    }

    runApp(const ProviderScope(child: MyApp()));
  });
}
```

### 2. ライフサイクル管理ページ

```dart
class MyPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModel = ref.watch(myViewModelProvider);
    
    return BaseLifeCyclePage(
      title: 'マイプロフィール',
      viewModel: viewModel,
      body: (context, child) => ListView( ... ),
    );
  }
}
```

### 3. UseCaseを使用したネットワークリクエスト

```dart
class GetUserUseCase extends UseCase<User, String> {
  final ApiClient _apiClient;
  
  GetUserUseCase(this._apiClient);
  
  @override
  Future<Either<Failure, User>> call({String? param}) async {
    final userId = param!;
    return await _apiClient.get('/users/$userId').then(
      (response) => Right(User.fromJson(response.data)),
      onError: (error) => Left(ServerApiFailure('ユーザー取得に失敗しました')),
    );
  }
}
```

### 4. イベントバス通信

```dart
// イベントを定義する
// イベントを定義
class UserUpdatedEvent extends BaseEvent {
  final User user;
  UserUpdatedEvent(this.user);
}

// イベントを送信
eventBus.emit(UserUpdatedEvent(updatedUser));

// ViewModelでイベントをリッスン
class UserViewModel with ViewModelMixin<UserState, UserIntent> {
  @override
  void onInit() {
    super.onInit();
    subscribeEvent<UserUpdatedEvent>((event) {
      updateState(state.copyWith(user: event.user));
    });
  }
}
```

### 5. ログ管理

```dart
// ログ管理器の設定を初期化
LogManager.initConfig(LogConfig(
  maxLogs: 1000,
  summaryTag: 'App',
  mockServerTag: 'Mock',
));

// プログラムでログを追加
LogManager.addLog('ユーザーログイン成功', level: LogLevel.info);
LogManager.addLog('APIリクエスト失敗', level: LogLevel.error);

// 全ログをテキストで取得
final allLogs = LogManager.getAllLogsAsText();

// ログをクリア
LogManager.clear();

// ログ変更をリッスン
LogManager.logNotifier.addListener(() {
  final logs = LogManager.logs;
  // ログ更新を処理
});
```

### 6. キャッシュ管理

```dart
// キャッシュサイズを取得
final cacheSize = await CacheManager.getCacheSize();

// 全キャッシュをクリア
await CacheManager.clearAllCache();
```

### 7. SharedPreferences ユーティリティ

```dart
// SpUtilを初期化
await SpUtil.init(prefix: 'my_app_');

// データを保存
await SpUtil.setString('user_name', '田中太郎');
await SpUtil.setInt('user_age', 25);
await SpUtil.setBool('is_logged_in', true);

// JSONデータを保存
await SpUtil.setJson('user_profile', userProfile);

// データを取得
final userName = SpUtil.getString('user_name');
final userAge = SpUtil.getInt('user_age');
final isLoggedIn = SpUtil.getBool('is_logged_in');

// JSONデータを取得
final userProfile = SpUtil.getJson<User>('user_profile');
```

### 8. 高度なナビゲーションとルーティング

```dart
// AppNavを認証とルートで初期化
void main() {
  AppNavConfig.register(
    isGuest: () => !AuthService.isLoggedIn(),
    onLogin: (context) async {
      // ログインページを表示し、成功/失敗を返す
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => LoginPage()),
      );
      return result ?? false;
    },
    onLoginSuccess: () {
      // 正常なログイン後に呼び出される
      appLogger.i('ユーザーログイン成功');
    },
    onShowLoginDialog: (context) async {
      // ログイン前に確認ダイアログを表示
      return await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('ログインが必要です'),
          content: Text('この機能にアクセスするにはログインしてください。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('キャンセル'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('ログイン'),
            ),
          ],
        ),
      ) ?? false;
    },
    routes: {
      '/profile': () => ProfilePage(),
      '/settings': () => SettingsPage(),
      '/users/:id': () => UserDetailPage(),
    },
  );
}

// 認証チェック付きナビゲーション
await AppNav.to('/profile', needLogin: true);

// パラメータ付きナビゲーション
await AppNav.to('/users/123', arguments: {'userId': '123'});

// クエリパラメータ付きナビゲーション
await AppNav.to('/users/123?tab=posts&filter=active');

// 現在のルートを置換
await AppNav.off('/home');

// すべてのルートをクリアし、新しいページにナビゲート
await AppNav.offAll('/dashboard', needLogin: true);

// 戻る
AppNav.back();

// 宛先ページでルートパラメータを取得
class UserDetailPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // ルートからパラメータを取得
    final userId = AppNav.getParam<String>('id');
    
    // すべての引数を取得
    final args = AppNav.getArgs<Map<String, dynamic>>();
    
    return Scaffold(
      appBar: AppBar(title: Text('ユーザー $userId')),
      body: Column(
        children: [
          Text('ユーザーID: $userId'),
          if (args != null) ...[
            Text('タブ: ${args['tab']}'),
            Text('フィルター: ${args['filter']}'),
          ],
        ],
      ),
    );
  }
}

// MaterialAppでの使用
MaterialApp(
  navigatorKey: AppNavConfig.navigatorKey,
  onGenerateRoute: AppNav.onGenerateRoute,
  navigatorObservers: [AppNav.observer],
  home: HomePage(),
)
```

### 9. コアアーキテクチャコンポーネント

#### BaseLifeCyclePage vs BaseScaffoldPage vs BaseMaterialApp

**BaseMaterialApp:**
```dart
// フレームワーク機能を統合したアプリレベルラッパー
BaseMaterialApp(
  title: 'マイアプリ',
  home: HomePage(),
  // 自動統合：
  // - AppNavナビゲーションシステム
  // - Zoneベースのパフォーマンストラッキング
  // - ルートオブザーバー
)
```

**BaseLifeCyclePage:**
```dart
// ライフサイクル管理と状態処理を備えたページラッパー
class MyPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BaseLifeCyclePage(
      title: 'マイページ',
      viewModel: ref.watch(myViewModelProvider),
      body: (context, child) => MyContent(),
      onEffect: (effect) {
        // UIエフェクトを処理（メッセージ、読み込みなど）
      },
      // 処理：
      // - ViewModelライフサイクル（onInit、onReady、onDispose）
      // - タイムアウト保護付き読み込み状態
      // - 戻るナビゲーションインターセプト
      // - エフェクト処理
    );
  }
}
```

**BaseScaffoldPage:**
```dart
// ライフサイクル管理なしの純粋UIスケルトン
class MyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BaseScaffoldPage(
      title: 'マイページ',
      child: MyContent(),
      // 処理：
      // - AppBar、StatusBar、BottomBar
      // - セーフエリア、パディング
      // - 背景装飾
      // - PopScope動作
    );
  }
}
```

#### BaseEffect & ProviderRegistry

**エフェクト定義：**
```dart
// カスタムナビゲーションエフェクト
class NavigateToProfileEffect extends BaseEffect {
  final String userId;
  NavigateToProfileEffect(this.userId);
}

// 標準エフェクト（組み込み）
MessageEffect.info('成功！');
MessageEffect.error('失敗！');
MessageEffect.dialog('操作を確認');
LoadingEffect.show(true);
EmptyEffect.show(true, 'データなし');
```

**プロバイダー作成：**
```dart
class NavigationProvider extends BaseProvider<NavigateToProfileEffect> {
  @override
  void handleEffect(NavigateToProfileEffect effect) {
    AppNav.to('/profile', arguments: {'userId': effect.userId});
  }
}

class MessageProvider extends BaseProvider<MessageEffect> {
  @override
  void handleEffect(MessageEffect effect) {
    switch (effect.type) {
      case MessageType.info:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(effect.message)),
        );
        break;
      case MessageType.error:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(effect.message), backgroundColor: Colors.red),
        );
        break;
      case MessageType.dialog:
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(effect.title ?? '警告'),
            content: Text(effect.message),
          ),
        );
        break;
    }
  }
}
```

**プロバイダー登録：**
```dart
void main() {
  // プロバイダーを初期化
  ProviderRegistry.init([
    NavigationProvider(),
    MessageProvider(),
    LoadingProvider(),
    // ... その他のプロバイダー
  ]);
  
  runApp(MyApp());
}
```

**ViewModelでの使用：**
```dart
class UserViewModel extends BaseViewModel<UserState, UserIntent> {
  @override
  Future<void> onIntent(UserIntent intent) async {
    if (intent is LoadUserIntent) {
      emitEffect(LoadingEffect.show(true));
      
      final result = await getUserUseCase.execute(intent.userId);
      
      result.fold(
        (failure) => emitEffect(MessageEffect.error(failure.message)),
        (user) => emitEffect(NavigateToProfileEffect(user.id)),
      );
      
      emitEffect(LoadingEffect.show(false));
    }
  }
}
```

#### 環境設定

**環境設定定義：**
```dart
class MockConfig extends BaseEnvConfig {
  @override
  AppEnvironment get env => AppEnvironment.mock;
  
  @override
  String get baseUrl => 'http://localhost:9898';
  
  @override
  int get connectTimeout => 5000;
  
  @override
  int get receiveTimeout => 10000;
  
  @override
  int get apiTimeout => 15000;
}

class ProdConfig extends BaseEnvConfig {
  @override
  AppEnvironment get env => AppEnvironment.prod;
  
  @override
  String get baseUrl => 'https://api.myapp.com';
  
  @override
  int get connectTimeout => 30000;
  
  @override
  int get receiveTimeout => 30000;
  
  @override
  int get apiTimeout => 60000;
}
```

**環境初期化：**
```dart
void main() {
  // 環境設定を登録
  AppEnv.register({
    AppEnvironment.mock: MockConfig(),
    AppEnvironment.dev: DevConfig(),
    AppEnvironment.test: TestConfig(),
    AppEnvironment.prod: ProdConfig(),
  });
  
  // 環境はAPP_ENV環境変数から自動選択
  // デフォルト：mock
  
  runApp(MyApp());
}

// 環境固有値を使用
final config = AppEnv.config;
final apiClient = ApiClient(baseUrl: config.baseUrl);
```

#### 国際化

**翻訳設定：**
```dart
void main() {
  // 翻訳データを登録
  Translations.register(
    data: {
      'en': {
        'welcome': 'Welcome',
        'login_failed': 'Login failed',
        'hello_user': 'Hello %s',
      },
      'zh': {
        'welcome': '欢迎',
        'login_failed': '登录失败',
        'hello_user': '你好 %s',
      },
      'ja': {
        'welcome': 'ようこそ',
        'login_failed': 'ログインに失敗しました',
        'hello_user': 'こんにちは %s',
      },
    },
    languageCodeProvider: () => getCurrentLanguage(),
  );
  
  runApp(MyApp());
}
```

**コードでの使用：**
```dart
// シンプルな翻訳
Text('welcome'.tr)  // -> "Welcome" / "欢迎" / "ようこそ"

// 引数付き
Text('hello_user'.trArgs(['田中']))  // -> "Hello 田中" / "你好 田中" / "こんにちは 田中"

// ViewModelで
class UserViewModel {
  void showWelcome() {
    emitEffect(MessageEffect.info('welcome'.tr));
  }
}
```

#### Zone管理

**グローバルZone設定：**
```dart
void main() {
  // 管理Zoneでアプリ全体を実行
  ZoneManager.run(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Core.init(CoreConfig.defaultConfig());
    runApp(MyApp());
  });
}
```

**自動機能：**
```dart
// 全ての非同期操作が自動的に取得：
// 1. トレースID相関
await someAsyncOperation();  // 自動的にトレースIDを取得

// 2. リクエストキャンセル
class MyViewModel extends BaseViewModel {
  @override
  void onDispose() {
    // このZoneの全HTTPリクエストが自動的にキャンセル
    super.onDispose();
  }
}

// 3. パフォーマンストラッキング
ZoneManager.mark('ユーザーデータ読み込み');  // 手動パフォーマンスマーク

// 4. エラーハンドリング
try {
  await riskyOperation();
} catch (e, stackTrace) {
  // トレースID付きで自動記録
  appLogger.e('操作失敗', error: e, stackTrace: stackTrace);
}
```

**手動Zone操作：**
```dart
// 新しいZoneで特定の操作を実行
final result = await ZoneManager.runOperation('user-login', () async {
  return await authService.login(email, password);
});

// 現在のトレースIDを取得
final traceId = ZoneManager.currentTraceId;

// 現在のキャンセルトークンを取得
final cancelToken = ZoneManager.currentCancelToken;
```

### 10. セキュアストレージ

```dart
// 機密データを安全に保存
await SecureStorageUtil.write('auth_token', token);

// 機密データを取得
final token = await SecureStorageUtil.read('auth_token');

// 機密データを削除
await SecureStorageUtil.delete('auth_token');
```

## 🎯 対象ユースケース
- **エンタープライズアプリケーション**: 堅牢でスケーラブルなアーキテクチャを必要とする場合。
- **迅速なプロトタイピング**: 標準化されたインフラを迅速にセットアップする場合。
- **マルチアプリエコシステム**: 異なるプロジェクト間で統一技術スタックを共有する場合。

## 🔮 ロードマップ
- [ ] Webおよびデスクトッププラットフォームのサポート。
- [ ] さらなる第三者監視サービス（Sentry/Firebase）との統合。
- [ ] `CoreConfig`の視覚的設定ツール。
- [ ] ネットワーク層の強化された単体テストカバレッジ。

## 🛠 要件
- Flutter: `>=3.10.1`
- Dart: `^3.10.1`

## 🚀 ListenCore を使用するアプリ

### ListenPortfolioFlutter
ListenCore で構築された包括的なポートフォリオ管理アプリケーションで、実世界のシナリオでのフレームワークの能力を示します。

**実証される機能：**
- **MVI アーキテクチャ**: ViewModel と状態管理による関心の分離
- **ライフサイクル管理**: ページライフサイクルイベントとリソースクリーンアップの適切な処理
- **ネットワーク層**: 自動トークンリフレッシュとエラーハンドリングを備えた RESTful API 統合
- **モックサーバー**: リアルな API シミュレーションによるローカル開発
- **ログシステム**: トレース ID 相関を備えた包括的なロギング
- **国際化**: 多言語サポートと i18n 統合

**主要な実装例：**
```dart
// MVI パターンを使用した ViewModel
class PortfolioViewModel with ViewModelMixin<PortfolioState, PortfolioIntent> {
  @override
  PortfolioState get state => _state;
  @override
  set state(PortfolioState value) => _state = value;
  
  @override
  Future<void> onIntent(PortfolioIntent intent) async {
    if (intent is LoadPortfolioIntent) {
      await call(
        _getPortfolioUseCase.execute(intent.userId),
        onSuccess: (portfolio) => updateState(state.copyWith(portfolio: portfolio)),
        showLoading: true,
      );
    }
  }
}

// ライフサイクル管理されたページ
class PortfolioPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BaseLifeCyclePage(
      title: 'ポートフォリオ',
      viewModel: ref.watch(portfolioViewModelProvider),
      body: (context, child) => PortfolioContent(),
    );
  }
}
```

**🔗 [GitHub で見る](https://github.com/listen2code/ListenPortfolioFlutter)**

## 📄 ライセンス
このプロジェクトはMITライセンスの下でライセンスされています - 詳細は [LICENSE](LICENSE) ファイルを参照してください。
