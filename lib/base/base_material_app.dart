import 'package:flutter/material.dart';
import '../core.dart';

/// A customized [MaterialApp] that automatically integrates the Core framework's
/// navigation system (AppNav) and Zone-based performance tracking.
/// Use this as a drop-in replacement for [MaterialApp] to gain framework benefits.
class BaseMaterialApp extends StatelessWidget {
  final String title;
  final Widget? home;
  final Map<String, WidgetBuilder> routes;
  final String? initialRoute;
  final RouteFactory? onUnknownRoute;
  final InitialRouteListFactory? onGenerateInitialRoutes;
  final List<NavigatorObserver> navigatorObservers;
  final TransitionBuilder? builder;
  final GenerateAppTitle? onGenerateTitle;
  final ThemeData? theme;
  final ThemeData? darkTheme;
  final ThemeData? highContrastTheme;
  final ThemeData? highContrastDarkTheme;
  final ThemeMode? themeMode;
  final Color? color;
  final Locale? locale;
  final Iterable<LocalizationsDelegate<dynamic>>? localizationsDelegates;
  final LocaleListResolutionCallback? localeListResolutionCallback;
  final LocaleResolutionCallback? localeResolutionCallback;
  final Iterable<Locale> supportedLocales;
  final bool showPerformanceOverlay;
  final bool checkerboardRasterCacheImages;
  final bool checkerboardOffscreenLayers;
  final bool showSemanticsDebugger;
  final bool debugShowCheckedModeBanner;
  final Map<ShortcutActivator, Intent>? shortcuts;
  final Map<Type, Action<Intent>>? actions;
  final String? restorationScopeId;
  final ScrollBehavior? scrollBehavior;
  final bool debugShowMaterialGrid;

  /// Custom navigator key. If null, uses AppNavConfig.navigatorKey by default.
  final GlobalKey<NavigatorState>? navigatorKey;

  /// Custom route generator. If null, uses AppNav.onGenerateRoute by default.
  final RouteFactory? onGenerateRoute;

  const BaseMaterialApp({
    super.key,
    required this.title,
    this.home,
    this.routes = const <String, WidgetBuilder>{},
    this.initialRoute,
    this.onUnknownRoute,
    this.onGenerateInitialRoutes,
    this.navigatorObservers = const <NavigatorObserver>[],
    this.builder,
    this.onGenerateTitle,
    this.theme,
    this.darkTheme,
    this.highContrastTheme,
    this.highContrastDarkTheme,
    this.themeMode = ThemeMode.system,
    this.color,
    this.locale,
    this.localizationsDelegates,
    this.localeListResolutionCallback,
    this.localeResolutionCallback,
    this.supportedLocales = const <Locale>[Locale('en', 'US')],
    this.showPerformanceOverlay = false,
    this.checkerboardRasterCacheImages = false,
    this.checkerboardOffscreenLayers = false,
    this.showSemanticsDebugger = false,
    this.debugShowCheckedModeBanner = true,
    this.shortcuts,
    this.actions,
    this.restorationScopeId,
    this.scrollBehavior,
    this.debugShowMaterialGrid = false,
    this.navigatorKey,
    this.onGenerateRoute,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // 1. Navigation Management
      // Use provided navigatorKey or fall back to Core's global navigator key
      navigatorKey: navigatorKey ?? AppNavConfig.navigatorKey,

      // Automatically inject Core's RouteObserver to track page lifecycle and arguments
      navigatorObservers: [AppNav.observer, ...navigatorObservers],

      // Use provided onGenerateRoute or fall back to Core's default for Zone & Parameter management
      onGenerateRoute: onGenerateRoute ?? AppNav.onGenerateRoute,

      // 2. Standard MaterialApp Parameters
      title: title,
      home: home,
      routes: routes,
      initialRoute: initialRoute,
      onUnknownRoute: onUnknownRoute,
      onGenerateInitialRoutes: onGenerateInitialRoutes,
      builder: builder,
      onGenerateTitle: onGenerateTitle,
      theme: theme,
      darkTheme: darkTheme,
      highContrastTheme: highContrastTheme,
      highContrastDarkTheme: highContrastDarkTheme,
      themeMode: themeMode,
      color: color,
      locale: locale,
      localizationsDelegates: localizationsDelegates,
      localeListResolutionCallback: localeListResolutionCallback,
      localeResolutionCallback: localeResolutionCallback,
      supportedLocales: supportedLocales,
      showPerformanceOverlay: showPerformanceOverlay,
      checkerboardRasterCacheImages: checkerboardRasterCacheImages,
      checkerboardOffscreenLayers: checkerboardOffscreenLayers,
      showSemanticsDebugger: showSemanticsDebugger,
      debugShowCheckedModeBanner: debugShowCheckedModeBanner,
      shortcuts: shortcuts,
      actions: actions,
      restorationScopeId: restorationScopeId,
      scrollBehavior: scrollBehavior,
      debugShowMaterialGrid: debugShowMaterialGrid,
    );
  }
}
