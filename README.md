# Listen Core

A professional, high-performance core architecture framework for Flutter applications. Designed to provide a unified foundation for enterprise-level development with a focus on lifecycle management, robust networking, and structured logging.

## 🔗 Links

- **📦 [pub.dev](https://pub.dev/packages/listen_core)**
- **🐙 [GitHub Repository](https://github.com/listen2code/ListenCoreFlutter)**
- **🚀 [Example App](https://github.com/listen2code/ListenPortfolioFlutter)**

---

## � Language / 语言 / 言語

- [English](#english) | [中文](#中文) | [日本語](#日本語)

---

# English

## �️ Architecture Design

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
- **LogManager**: In-app floating log viewer with real-time log streaming and filtering.
- **CrashManager**: Centralized error reporting, safety mode, and automatic recovery with crash upload.

### 4. Storage & Utilities (`utils/`)
- **SpUtil**: Synchronous wrapper for `SharedPreferences` with JSON support.
- **SecureStorageUtil**: Encrypted storage for sensitive data.
- **Device & Package Info**: Quick access to hardware and app metadata.

### 5. Advanced Features (`utils/`)
- **Floating Log Viewer**: Real-time log display with floating window, search, and export capabilities.
- **Crash Reporting**: Automatic crash detection, reporting, and upload to monitoring services.
- **Event Bus**: Decoupled event communication across the application.
- **Cache Manager**: Intelligent caching with TTL and memory management.
- **Zone-based Error Tracking**: Comprehensive error tracking with trace ID correlation.

## 📦 Getting Started

Add `listen_core` to your `pubspec.yaml`:

```bash
dart pub add listen_core:0.0.3
```

Or add it manually:

```yaml
dependencies:
  listen_core: ^0.0.3
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
class GetUserUseCase extends BaseUseCase<User, String> {
  final ApiClient _apiClient;
  
  GetUserUseCase(this._apiClient);
  
  @override
  Future<Either<Failure, User>> execute(String userId) async {
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

### 5. Log Management

```dart
// Initialize log manager configuration
LogManager.initConfig(LogConfig(
  maxLogs: 1000,
  summaryTag: 'App',
  mockServerTag: 'Mock',
));

// Add logs programmatically
LogManager.addLog('User logged in successfully', level: LogLevel.info);
LogManager.addLog('API request failed', level: LogLevel.error);

// Get all logs as text
final allLogs = LogManager.getAllLogsAsText();

// Clear logs
LogManager.clear();

// Listen to log changes
LogManager.logNotifier.addListener(() {
  final logs = LogManager.logs;
  // Handle log updates
});
```

### 6. Cache Management

```dart
// Get cache size
final cacheSize = await CacheManager.getCacheSize();

// Clear all cache
await CacheManager.clearAllCache();
```

### 7. SharedPreferences Utility

```dart
// Initialize SpUtil
await SpUtil.init(prefix: 'my_app_');

// Store data
await SpUtil.setString('user_name', 'John Doe');
await SpUtil.setInt('user_age', 25);
await SpUtil.setBool('is_logged_in', true);

// Store JSON data
await SpUtil.setJson('user_profile', userProfile);

// Retrieve data
final userName = SpUtil.getString('user_name');
final userAge = SpUtil.getInt('user_age');
final isLoggedIn = SpUtil.getBool('is_logged_in');

// Retrieve JSON data
final userProfile = SpUtil.getJson<User>('user_profile');
```

### 8. Advanced Navigation & Routing

```dart
// Initialize AppNav with authentication and routes
void main() {
  AppNavConfig.register(
    isGuest: () => !AuthService.isLoggedIn(),
    onLogin: (context) async {
      // Show login page and return success/failure
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => LoginPage()),
      );
      return result ?? false;
    },
    onLoginSuccess: () {
      // Called after successful login
      appLogger.i('User logged in successfully');
    },
    onShowLoginDialog: (context) async {
      // Show confirmation dialog before login
      return await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Login Required'),
          content: Text('Please login to access this feature.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Login'),
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

// Navigate with authentication check
await AppNav.to('/profile', needLogin: true);

// Navigate with parameters
await AppNav.to('/users/123', arguments: {'userId': '123'});

// Navigate with query parameters
await AppNav.to('/users/123?tab=posts&filter=active');

// Replace current route
await AppNav.off('/home');

// Clear all routes and navigate to new page
await AppNav.offAll('/dashboard', needLogin: true);

// Go back
AppNav.back();

// Get route parameters in destination page
class UserDetailPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Get parameter from route
    final userId = AppNav.getParam<String>('id');
    
    // Get all arguments
    final args = AppNav.getArgs<Map<String, dynamic>>();
    
    return Scaffold(
      appBar: AppBar(title: Text('User $userId')),
      body: Column(
        children: [
          Text('User ID: $userId'),
          if (args != null) ...[
            Text('Tab: ${args['tab']}'),
            Text('Filter: ${args['filter']}'),
          ],
        ],
      ),
    );
  }
}

// In MaterialApp
MaterialApp(
  navigatorKey: AppNavConfig.navigatorKey,
  onGenerateRoute: AppNav.onGenerateRoute,
  navigatorObservers: [AppNav.observer],
  home: HomePage(),
)
```

### 9. Core Architecture Components

#### BaseLifeCyclePage vs BaseScaffoldPage vs BaseMaterialApp

**BaseMaterialApp:**
```dart
// App-level wrapper with framework integration
BaseMaterialApp(
  title: 'My App',
  home: HomePage(),
  // Automatically integrates:
  // - AppNav navigation system
  // - Zone-based performance tracking
  // - Route observers
)
```

**BaseLifeCyclePage:**
```dart
// Page wrapper with lifecycle management and state handling
class MyPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BaseLifeCyclePage(
      title: 'My Page',
      viewModel: ref.watch(myViewModelProvider),
      body: (context, child) => MyContent(),
      onEffect: (effect) {
        // Handle UI effects (messages, loading, etc.)
      },
      // Handles:
      // - ViewModel lifecycle (onInit, onReady, onDispose)
      // - Loading states with timeout protection
      // - Back navigation interception
      // - Effect handling
    );
  }
}
```

**BaseScaffoldPage:**
```dart
// Pure UI skeleton without lifecycle management
class MyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BaseScaffoldPage(
      title: 'My Page',
      child: MyContent(),
      // Handles:
      // - AppBar, StatusBar, BottomBar
      // - Safe area, padding
      // - Background decorations
      // - PopScope behavior
    );
  }
}
```

#### BaseEffect & ProviderRegistry

**Define Effects:**
```dart
// Custom effect for navigation
class NavigateToProfileEffect extends BaseEffect {
  final String userId;
  NavigateToProfileEffect(this.userId);
}

// Standard effects (built-in)
MessageEffect.info('Success!');
MessageEffect.error('Failed!');
MessageEffect.dialog('Confirm action');
LoadingEffect.show(true);
EmptyEffect.show(true, 'No data available');
```

**Create Provider:**
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
            title: Text(effect.title ?? 'Alert'),
            content: Text(effect.message),
          ),
        );
        break;
    }
  }
}
```

**Register Providers:**
```dart
void main() {
  // Initialize providers
  ProviderRegistry.init([
    NavigationProvider(),
    MessageProvider(),
    LoadingProvider(),
    // ... other providers
  ]);
  
  runApp(MyApp());
}
```

**Use in ViewModel:**
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

#### Environment Configuration

**Define Environment Configs:**
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

**Initialize Environment:**
```dart
void main() {
  // Register environment configurations
  AppEnv.register({
    AppEnvironment.mock: MockConfig(),
    AppEnvironment.dev: DevConfig(),
    AppEnvironment.test: TestConfig(),
    AppEnvironment.prod: ProdConfig(),
  });
  
  // Environment is automatically selected from APP_ENV environment variable
  // Default: mock
  
  runApp(MyApp());
}

// Use environment-specific values
final config = AppEnv.config;
final apiClient = ApiClient(baseUrl: config.baseUrl);
```

#### Internationalization

**Setup Translations:**
```dart
void main() {
  // Register translation data
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

**Use in Code:**
```dart
// Simple translation
Text('welcome'.tr)  // -> "Welcome" / "欢迎" / "ようこそ"

// With arguments
Text('hello_user'.trArgs(['John']))  // -> "Hello John" / "你好 John" / "こんにちは John"

// In ViewModels
class UserViewModel {
  void showWelcome() {
    emitEffect(MessageEffect.info('welcome'.tr));
  }
}
```

#### Zone Management

**Global Zone Setup:**
```dart
void main() {
  // Run entire app in managed zone
  ZoneManager.run(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Core.init(CoreConfig.defaultConfig());
    runApp(MyApp());
  });
}
```

**Automatic Features:**
```dart
// All async operations automatically get:
// 1. Trace ID correlation
await someAsyncOperation();  // Gets trace ID automatically

// 2. Request cancellation
class MyViewModel extends BaseViewModel {
  @override
  void onDispose() {
    // All HTTP requests in this zone are automatically cancelled
    super.onDispose();
  }
}

// 3. Performance tracking
ZoneManager.mark('User data loaded');  // Manual performance marks

// 4. Error handling
try {
  await riskyOperation();
} catch (e, stackTrace) {
  // Automatically logged with trace ID
  appLogger.e('Operation failed', error: e, stackTrace: stackTrace);
}
```

**Manual Zone Operations:**
```dart
// Run specific operation in new zone
final result = await ZoneManager.runOperation('user-login', () async {
  return await authService.login(email, password);
});

// Get current trace ID
final traceId = ZoneManager.currentTraceId;

// Get current cancel token
final cancelToken = ZoneManager.currentCancelToken;
```

### 10. Secure Storage

```dart
// Store sensitive data securely
await SecureStorageUtil.write('auth_token', token);

// Retrieve sensitive data
final token = await SecureStorageUtil.read('auth_token');

// Delete sensitive data
await SecureStorageUtil.delete('auth_token');
```

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

## 🚀 Apps Using ListenCore

### ListenPortfolioFlutter
A comprehensive portfolio management application built with ListenCore that demonstrates the framework's capabilities in a real-world scenario.

**Features demonstrated:**
- **MVI Architecture**: Clean separation of concerns with ViewModels and state management
- **Lifecycle Management**: Proper handling of page lifecycle events and resource cleanup
- **Network Layer**: RESTful API integration with automatic token refresh and error handling
- **Mock Server**: Local development with realistic API simulation
- **Logging System**: Comprehensive logging with trace ID correlation
- **Internationalization**: Multi-language support with i18n integration

**Key Implementation Examples:**
```dart
// ViewModel with MVI pattern
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

// Lifecycle-managed page
class PortfolioPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BaseLifeCyclePage(
      title: 'Portfolio',
      viewModel: ref.watch(portfolioViewModelProvider),
      body: (context, child) => PortfolioContent(),
    );
  }
}
```

**🔗 [View on GitHub](https://github.com/listen2code/ListenPortfolioFlutter)**

## 📄 License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

# 中文

## 🔗 链接

- **📦 [pub.dev](https://pub.dev/packages/listen_core)**
- **🐙 [GitHub 仓库](https://github.com/listen2code/ListenCoreFlutter)**
- **🚀 [示例应用](https://github.com/listen2code/ListenPortfolioFlutter)**

---

## 🏗️ 架构设计

### 设计原则
- **零业务耦合**: 不包含业务逻辑，完全通用和可重用。
- **高内聚低耦合**: 模块化设计允许独立提取和发布。
- **高度可配置**: 通过专用配置类灵活定制行为。
- **生产就绪**: 内置错误处理、结构化日志和性能监控。

### 模块结构
```
lib/core/
├── base/           # 架构层 (ViewModel, 生命周期, 脚手架)
├── config/         # 配置管理 (网络, 日志, 模拟)
├── env/            # 环境与密钥管理
├── errors/         # 统一错误与失败处理
├── i18n/           # 国际化支持
├── network/        # 网络层 (Dio, 拦截器, 模拟服务器)
├── route/          # 路由与导航拦截器
└── utils/          # 工具类 (日志, 存储, 区域, 崩溃保护)
```

## 🚀 核心模块与功能

### 1. 基础架构与生命周期 (`base/`)
- **BaseLifeCyclePage**: 统一页面包装器，处理：
  - 自动 `onInit`, `onReady`, `onResume`, `onPause`, `onVisible`, `onInVisible`。
  - 内置 **加载**、**空** 和 **错误** 状态管理。
  - **安全定时器** 防止UI锁定和自动请求取消。
- **BaseViewModel (MVI)**: 状态驱动逻辑，内置副作用管理。
- **BaseMaterialApp**: 预配置 `NavigatorKey`、`RouteObserver` 和 `ZoneManager`。

### 2. 网络与模拟 (`network/`)
- **ApiClient**: 强大的HTTP客户端，具有：
  - 自动令牌刷新和请求队列。
  - X-Trace-Id关联用于分布式追踪。
- **LocalMockServer**: 应用内HTTP服务器（端口9898），将API请求映射到本地JSON资源。
  - 支持版本控制（例如 `/v1/user` -> `json/v1/get/user.json`）。
  - 模拟网络延迟并记录请求/响应详细信息。
- **UseCase模式**: 使用`fpdart`的`Either<Failure, T>`进行标准化函数式错误处理。

### 3. 日志与诊断 (`utils/`)
- **ZoneManager**: 捕获未处理异常并跟踪异步性能。
- **AppLogger**: 具有严重性级别和JSON格式的结构化日志。
- **LogManager**: 应用内浮动日志查看器，支持实时日志流和过滤。
- **CrashManager**: 集中错误报告、安全模式和自动恢复，支持崩溃上传。

### 4. 存储与工具 (`utils/`)
- **SpUtil**: `SharedPreferences`的同步包装器，支持JSON。
- **SecureStorageUtil**: 敏感数据的加密存储。
- **设备与包信息**: 快速访问硬件和应用元数据。

### 5. 高级功能 (`utils/`)
- **浮动日志查看器**: 实时日志显示，支持浮动窗口、搜索和导出功能。
- **崩溃报告**: 自动崩溃检测、报告和上传到监控服务。
- **事件总线**: 应用程序内的解耦事件通信。
- **缓存管理器**: 具有TTL和内存管理的智能缓存。
- **基于区域的错误跟踪**: 具有追踪ID关联的综合错误跟踪。

## 📦 快速开始

将 `listen_core` 添加到您的 `pubspec.yaml`：

```bash
dart pub add listen_core:0.0.3
```

或手动添加：

```yaml
dependencies:
  listen_core: ^0.0.3
```

**🔗 [在 pub.dev 上查看](https://pub.dev/packages/listen_core)**

## 🛠 使用方法

### 1. 全局初始化

```dart
void main() async {
  // 1. 在托管区域中运行以进行错误跟踪
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
class GetUserUseCase extends BaseUseCase<User, String> {
  final ApiClient _apiClient;
  
  GetUserUseCase(this._apiClient);
  
  @override
  Future<Either<Failure, User>> execute(String userId) async {
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

### 5. 日志管理

```dart
// 初始化日志管理器配置
LogManager.initConfig(LogConfig(
  maxLogs: 1000,
  summaryTag: 'App',
  mockServerTag: 'Mock',
));

// 以编程方式添加日志
LogManager.addLog('用户登录成功', level: LogLevel.info);
LogManager.addLog('API请求失败', level: LogLevel.error);

// 获取所有日志文本
final allLogs = LogManager.getAllLogsAsText();

// 清除日志
LogManager.clear();

// 监听日志变化
LogManager.logNotifier.addListener(() {
  final logs = LogManager.logs;
  // 处理日志更新
});
```

### 6. 缓存管理

```dart
// 获取缓存大小
final cacheSize = await CacheManager.getCacheSize();

// 清除所有缓存
await CacheManager.clearAllCache();
```

### 7. SharedPreferences 工具

```dart
// 初始化 SpUtil
await SpUtil.init(prefix: 'my_app_');

// 存储数据
await SpUtil.setString('user_name', '张三');
await SpUtil.setInt('user_age', 25);
await SpUtil.setBool('is_logged_in', true);

// 存储 JSON 数据
await SpUtil.setJson('user_profile', userProfile);

// 检索数据
final userName = SpUtil.getString('user_name');
final userAge = SpUtil.getInt('user_age');
final isLoggedIn = SpUtil.getBool('is_logged_in');

// 检索 JSON 数据
final userProfile = SpUtil.getJson<User>('user_profile');
```

### 8. 高级导航与路由

```dart
// 初始化 AppNav 配置身份验证和路由
void main() {
  AppNavConfig.register(
    isGuest: () => !AuthService.isLoggedIn(),
    onLogin: (context) async {
      // 显示登录页面并返回成功/失败
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => LoginPage()),
      );
      return result ?? false;
    },
    onLoginSuccess: () {
      // 成功登录后调用
      appLogger.i('用户登录成功');
    },
    onShowLoginDialog: (context) async {
      // 登录前显示确认对话框
      return await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('需要登录'),
          content: Text('请登录以访问此功能。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('登录'),
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

// 带身份验证检查的导航
await AppNav.to('/profile', needLogin: true);

// 带参数的导航
await AppNav.to('/users/123', arguments: {'userId': '123'});

// 带查询参数的导航
await AppNav.to('/users/123?tab=posts&filter=active');

// 替换当前路由
await AppNav.off('/home');

// 清除所有路由并导航到新页面
await AppNav.offAll('/dashboard', needLogin: true);

// 返回
AppNav.back();

// 在目标页面获取路由参数
class UserDetailPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // 从路由获取参数
    final userId = AppNav.getParam<String>('id');
    
    // 获取所有参数
    final args = AppNav.getArgs<Map<String, dynamic>>();
    
    return Scaffold(
      appBar: AppBar(title: Text('用户 $userId')),
      body: Column(
        children: [
          Text('用户ID: $userId'),
          if (args != null) ...[
            Text('标签: ${args['tab']}'),
            Text('过滤器: ${args['filter']}'),
          ],
        ],
      ),
    );
  }
}

// 在 MaterialApp 中使用
MaterialApp(
  navigatorKey: AppNavConfig.navigatorKey,
  onGenerateRoute: AppNav.onGenerateRoute,
  navigatorObservers: [AppNav.observer],
  home: HomePage(),
)
```

### 9. 核心架构组件

#### BaseLifeCyclePage vs BaseScaffoldPage vs BaseMaterialApp

**BaseMaterialApp:**
```dart
// 应用级包装器，集成框架功能
BaseMaterialApp(
  title: '我的应用',
  home: HomePage(),
  // 自动集成：
  // - AppNav 导航系统
  // - 基于Zone的性能跟踪
  // - 路由观察器
)
```

**BaseLifeCyclePage:**
```dart
// 页面包装器，具有生命周期管理和状态处理
class MyPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BaseLifeCyclePage(
      title: '我的页面',
      viewModel: ref.watch(myViewModelProvider),
      body: (context, child) => MyContent(),
      onEffect: (effect) {
        // 处理UI效果（消息、加载等）
      },
      // 处理：
      // - ViewModel生命周期（onInit、onReady、onDispose）
      // - 带超时保护的加载状态
      // - 返回导航拦截
      // - 效果处理
    );
  }
}
```

**BaseScaffoldPage:**
```dart
// 纯UI骨架，无生命周期管理
class MyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BaseScaffoldPage(
      title: '我的页面',
      child: MyContent(),
      // 处理：
      // - AppBar、StatusBar、BottomBar
      // - 安全区域、内边距
      // - 背景装饰
      // - PopScope行为
    );
  }
}
```

#### BaseEffect & ProviderRegistry

**定义效果：**
```dart
// 自定义导航效果
class NavigateToProfileEffect extends BaseEffect {
  final String userId;
  NavigateToProfileEffect(this.userId);
}

// 标准效果（内置）
MessageEffect.info('成功！');
MessageEffect.error('失败！');
MessageEffect.dialog('确认操作');
LoadingEffect.show(true);
EmptyEffect.show(true, '无数据');
```

**创建提供者：**
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

**注册提供者：**
```dart
void main() {
  // 初始化提供者
  ProviderRegistry.init([
    NavigationProvider(),
    MessageProvider(),
    LoadingProvider(),
    // ... 其他提供者
  ]);
  
  runApp(MyApp());
}
```

**在ViewModel中使用：**
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

#### 环境配置

**定义环境配置：**
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

**初始化环境：**
```dart
void main() {
  // 注册环境配置
  AppEnv.register({
    AppEnvironment.mock: MockConfig(),
    AppEnvironment.dev: DevConfig(),
    AppEnvironment.test: TestConfig(),
    AppEnvironment.prod: ProdConfig(),
  });
  
  // 环境从APP_ENV环境变量自动选择
  // 默认：mock
  
  runApp(MyApp());
}

// 使用环境特定值
final config = AppEnv.config;
final apiClient = ApiClient(baseUrl: config.baseUrl);
```

#### 国际化

**设置翻译：**
```dart
void main() {
  // 注册翻译数据
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

**在代码中使用：**
```dart
// 简单翻译
Text('welcome'.tr)  // -> "Welcome" / "欢迎" / "ようこそ"

// 带参数
Text('hello_user'.trArgs(['张三']))  // -> "Hello 张三" / "你好 张三" / "こんにちは 張三"

// 在ViewModel中
class UserViewModel {
  void showWelcome() {
    emitEffect(MessageEffect.info('welcome'.tr));
  }
}
```

#### Zone管理

**全局Zone设置：**
```dart
void main() {
  // 在托管Zone中运行整个应用
  ZoneManager.run(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Core.init(CoreConfig.defaultConfig());
    runApp(MyApp());
  });
}
```

**自动功能：**
```dart
// 所有异步操作自动获得：
// 1. 追踪ID关联
await someAsyncOperation();  // 自动获得追踪ID

// 2. 请求取消
class MyViewModel extends BaseViewModel {
  @override
  void onDispose() {
    // 此Zone中的所有HTTP请求自动取消
    super.onDispose();
  }
}

// 3. 性能跟踪
ZoneManager.mark('用户数据加载');  // 手动性能标记

// 4. 错误处理
try {
  await riskyOperation();
} catch (e, stackTrace) {
  // 自动记录追踪ID
  appLogger.e('操作失败', error: e, stackTrace: stackTrace);
}
```

**手动Zone操作：**
```dart
// 在新Zone中运行特定操作
final result = await ZoneManager.runOperation('user-login', () async {
  return await authService.login(email, password);
});

// 获取当前追踪ID
final traceId = ZoneManager.currentTraceId;

// 获取当前取消令牌
final cancelToken = ZoneManager.currentCancelToken;
```

### 10. 安全存储

```dart
// 安全存储敏感数据
await SecureStorageUtil.write('auth_token', token);

// 检索敏感数据
final token = await SecureStorageUtil.read('auth_token');

// 删除敏感数据
await SecureStorageUtil.delete('auth_token');
```

## 🎯 目标用例
- **企业应用**: 需要可靠、可扩展的架构。
- **快速原型**: 快速设置标准化基础设施。
- **多应用生态系统**: 在不同项目间共享统一技术栈。

## 🔮 路线图
- [ ] 支持Web和桌面平台。
- [ ] 集成更多第三方监控服务（Sentry/Firebase）。
- [ ] `CoreConfig`的可视化配置工具。
- [ ] 增强网络层的单元测试覆盖率。

## 🛠 要求
- Flutter: `>=3.10.1`
- Dart: `^3.10.1`

## � 使用 ListenCore 的应用

### ListenPortfolioFlutter
一个使用 ListenCore 构建的综合投资组合管理应用程序，展示了框架在真实场景中的能力。

**展示的功能：**
- **MVI 架构**: 通过 ViewModel 和状态管理实现关注点分离
- **生命周期管理**: 正确处理页面生命周期事件和资源清理
- **网络层**: RESTful API 集成，支持自动令牌刷新和错误处理
- **模拟服务器**: 本地开发环境下的真实 API 模拟
- **日志系统**: 具有追踪 ID 关联的综合日志记录
- **国际化**: 多语言支持和 i18n 集成

**关键实现示例：**
```dart
// 使用 MVI 模式的 ViewModel
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

// 生命周期管理的页面
class PortfolioPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BaseLifeCyclePage(
      title: '投资组合',
      viewModel: ref.watch(portfolioViewModelProvider),
      body: (context, child) => PortfolioContent(),
    );
  }
}
```

**🔗 [在 GitHub 上查看](https://github.com/listen2code/ListenPortfolioFlutter)**

## � 许可证
本项目采用MIT许可证 - 详情请参阅 [LICENSE](LICENSE) 文件。

---

# 日本語

## 🔗 リンク

- **📦 [pub.dev](https://pub.dev/packages/listen_core)**
- **🐙 [GitHub リポジトリ](https://github.com/listen2code/ListenCoreFlutter)**
- **🚀 [サンプルアプリ](https://github.com/listen2code/ListenPortfolioFlutter)**

---

## 🏗️ アーキテクチャ設計

### 設計原則
- **ゼロビジネス結合**: ビジネスロジックを含まず、完全に汎用的で再利用可能。
- **高凝集・低結合**: モジュラー設計により独立した抽出と公開が可能。
- **高設定可能性**: 専用設定クラスによる柔軟な動作カスタマイズ。
- **本番稼働準備**: 内蔵エラー処理、構造化ログ、パフォーマンス監視。

### モジュール構造
```
lib/core/
├── base/           # アーキテクチャ層 (ViewModel, ライフサイクル, スキャフォールド)
├── config/         # 設定管理 (ネットワーク, ログ, モック)
├── env/            # 環境とシークレット管理
├── errors/         # 統一エラーと失敗処理
├── i18n/           # 国際化サポート
├── network/        # ネットワーク層 (Dio, インターセプター, モックサーバー)
├── route/          # ルーティングとナビゲーションインターセプター
└── utils/          # ユーティリティ (ログ, ストレージ, ゾーン, クラッシュ保護)
```

## 🚀 主要モジュールと機能

### 1. 基本アーキテクチャとライフサイクル (`base/`)
- **BaseLifeCyclePage**: 統一ページラッパー、以下を処理：
  - 自動 `onInit`, `onReady`, `onResume`, `onPause`, `onVisible`, `onInVisible`。
  - 内蔵 **ローディング**、**空**、**エラー** 状態管理。
  - UIロックと自動リクエストキャンセルを防ぐ **セーフティタイマー**。
- **BaseViewModel (MVI)**: 状態駆動ロジック、内蔵副作用管理。
- **BaseMaterialApp**: `NavigatorKey`、`RouteObserver`、`ZoneManager` で事前設定。

### 2. ネットワークとモック (`network/`)
- **ApiClient**: 以下の機能を持つ堅牢なHTTPクライアント：
  - 自動トークン更新とリクエストキューイング。
  - 分散トレーシングのためのX-Trace-Id相関。
- **LocalMockServer**: アプリ内HTTPサーバー（ポート9898）、APIリクエストをローカルJSONアセットにマッピング。
  - バージョニングサポート（例: `/v1/user` -> `json/v1/get/user.json`）。
  - ネットワーク遅延をシミュレートし、リクエスト/レスポンス詳細をログ記録。
- **UseCaseパターン**: `fpdart`の`Either<Failure, T>`を使用した標準化関数型エラー処理。

### 3. ログと診断 (`utils/`)
- **ZoneManager**: 未処理の例外をキャプチャし、非同期パフォーマンスを追跡。
- **AppLogger**: 重大度レベルとJSONフォーマットを持つ構造化ログ。
- **LogManager**: リアルタイムログストリーミングとフィルタリングを備えたアプリ内浮動ログビューア。
- **CrashManager**: クラッシュアップロード機能を備えた集中エラーレポート、セーフティモード、自動回復。

### 4. ストレージとユーティリティ (`utils/`)
- **SpUtil**: JSONサポート付き`SharedPreferences`の同期ラッパー。
- **SecureStorageUtil**: 機密データの暗号化ストレージ。
- **デバイスとパッケージ情報**: ハードウェアとアプリメタデータへの迅速アクセス。

### 5. 高度な機能 (`utils/`)
- **浮動ログビューア**: 浮動ウィンドウ、検索、エクスポート機能を備えたリアルタイムログ表示。
- **クラッシュレポート**: 自動クラッシュ検出、レポート、監視サービスへのアップロード。
- **イベントバス**: アプリケーション全体の分離されたイベント通信。
- **キャッシュマネージャー**: TTLとメモリ管理を備えたインテリジェントキャッシュ。
- **ゾーンベースのエラートラッキング**: トレースID相関を備えた包括的なエラートラッキング。

## 📦 始め方

`listen_core` を `pubspec.yaml` に追加：

```bash
dart pub add listen_core:0.0.3
```

または手動で追加：

```yaml
dependencies:
  listen_core: ^0.0.3
```

**🔗 [pub.dev で見る](https://pub.dev/packages/listen_core)**

## 🛠 使用方法

### 1. グローバル初期化

```dart
void main() async {
  // 1. エラートラッキングのため管理ゾーンで実行
  ZoneManager.run(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    // 2. コアサービスを初期化
    await Core.init(CoreConfig.defaultConfig());
    
    // 3. デバッグモードでモックサーバーを起動
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
class GetUserUseCase extends BaseUseCase<User, String> {
  final ApiClient _apiClient;
  
  GetUserUseCase(this._apiClient);
  
  @override
  Future<Either<Failure, User>> execute(String userId) async {
    return await _apiClient.get('/users/$userId').then(
      (response) => Right(User.fromJson(response.data)),
      onError: (error) => Left(ServerApiFailure('ユーザーの取得に失敗しました')),
    );
  }
}
```

### 4. イベントバス通信

```dart
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
