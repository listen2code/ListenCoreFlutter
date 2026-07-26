import 'dart:async';

import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../core.dart';

/// A professional, unified page wrapper that handles lifecycle management
/// and ViewModel state listening, delegating UI structure to [BaseScaffoldPage].
class BaseLifeCyclePage extends StatefulWidget {
  final TransitionBuilder body;
  final String? title;
  final List<Widget>? actions;
  final PreferredSizeWidget? appBar;
  final Widget? drawer;
  final Widget? floatingActionButton;
  final bool useSafeArea;
  final EdgeInsetsGeometry? padding;
  final bool resizeToAvoidBottomInset;
  final bool extendBodyBehindAppBar;
  final bool useStatusBar;
  final bool useBottomBar;
  final bool isEmptyTitle;
  final Color statusBarColor;
  final Color bottomBarColor;

  /// Whether to use the gradient background decoration for the Scaffold body.
  final bool useGradientBackground;

  /// Visibility flag for Tab/Page switching inside the same route.
  final bool active;

  /// Whether the page can be popped. If null, it depends on the loading state.
  final bool? canPop;

  /// Maximum duration a loading state can persist before being forcibly cleared.
  final Duration loadingTimeout;

  /// Custom logic to execute when back is intercepted (e.g., custom confirmation dialogs).
  /// If null, default behavior is to cancel requests and hide loading.
  final VoidCallback? onInterceptBack;

  /// Explicitly provided ViewModel instance.
  final BaseViewModel? viewModel;

  /// Optional UI-layer lifecycle listener.
  final PageLifecycle? lifecycle;

  /// Optional callback to handle custom UI effects.
  final void Function(BaseEffect effect)? onEffect;

  /// A widget to display when the page is in a loading state (e.g., a Skeleton screen).
  /// If provided, it will automatically replace the body when the page is loading.
  final Widget? onLoading;

  /// A widget to display when the page is in an empty state.
  final Widget? onEmpty;

  /// Whether to wrap the content in a [BaseScaffoldPage].
  /// Set to false when using this as a sub-page/tab within another page.
  final bool useScaffold;

  /// Whether the page body should expand to fill the parent container when [useScaffold] is false.
  /// Useful for tabs inside an [IndexedStack] (should be true) versus bottom sheets (should be false).
  final bool expandBody;

  /// Whether to enable viewport visibility detection (onViewVisible/onViewInVisible).
  /// Disable this for simple static pages to improve performance.
  final bool useVisibilityDetector;

  /// Whether to enable swiping to open the drawer.
  final bool drawerEnableOpenDragGesture;

  const BaseLifeCyclePage({
    super.key,
    required this.body,
    this.title,
    this.actions,
    this.appBar,
    this.drawer,
    this.floatingActionButton,
    this.useSafeArea = true,
    this.padding,
    this.resizeToAvoidBottomInset = true,
    this.extendBodyBehindAppBar = true,
    this.useStatusBar = false,
    this.useBottomBar = false,
    this.isEmptyTitle = false,
    this.statusBarColor = Colors.transparent,
    this.bottomBarColor = Colors.transparent,
    this.useGradientBackground = true,
    this.active = true,
    this.canPop,
    this.loadingTimeout = const Duration(seconds: 20),
    this.onInterceptBack,
    this.viewModel,
    this.lifecycle,
    this.onEffect,
    this.onLoading,
    this.onEmpty,
    this.useScaffold = true,
    this.expandBody = true,
    this.useVisibilityDetector = true,
    this.drawerEnableOpenDragGesture = true,
  });

  @override
  State<BaseLifeCyclePage> createState() => _BaseLifeCyclePageState();
}

class _BaseLifeCyclePageState extends State<BaseLifeCyclePage> {
  bool _isRouteVisible = false;
  bool _isActuallyVisible = false; // Tracks (Route Visible && widget.active)
  bool _isViewVisible = false; // Tracks physical visibility in viewport
  bool _isReady = false; // Tracks if onReady has been called
  BaseViewModel? _viewModel;
  StreamSubscription<BaseEffect>? _effectSubscription;

  // Added to track state transitions for filtering onInactive calls.
  AppLifecycleState? _lastAppState;

  // Local state to track loading based on Effects, used for canPop logic.
  final ValueNotifier<bool> _isInternalLoading = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isInternalEmpty = ValueNotifier<bool>(false);

  Timer? _loadingSafetyTimer;

  late final _RouteAwareProxy _routeObserver;
  late final _AppLifecycleProxy _lifecycleObserver;

  @override
  void initState() {
    super.initState();

    // Initialize the last known app state.
    _lastAppState = WidgetsBinding.instance.lifecycleState;

    // Directly use the provided viewModel instance
    _viewModel = widget.viewModel;

    // Bind effects: ViewModel manages the subscription lifecycle internally.
    if (_viewModel != null) {
      _effectSubscription = _viewModel!.onBindEffect(_handleEffect);
    }

    _routeObserver = _RouteAwareProxy(
      onVisible: () {
        _isRouteVisible = true;
        _evaluateVisibility();
      },
      onInVisible: () {
        _isRouteVisible = false;
        _evaluateVisibility();
      },
      onPop: () {
        // Synchronously cancel the subscription when popped or replaced.
        // During pop or pushReplacement, the exiting page widget is not immediately disposed
        // until the transition animation completes (takes ~300ms). Since Riverpod's auto-dispose
        // ref count doesn't drop to 0 instantly during transition, the VM is reused, and the old page
        // remains an active listener of the effectStream. Canceling here immediately ensures the exiting
        // page does not receive and process duplicate VM side-effects (e.g. showing dialogs twice).
        _effectSubscription?.cancel();
        _effectSubscription = null;
        ProviderRegistry.handle(LoadingEffect(false));
      },
    );

    _lifecycleObserver = _AppLifecycleProxy(
      onStateChanged: (state) {
        // Strict visibility check before triggering lifecycle
        if (!_isActuallyVisible) return;

        if (state == AppLifecycleState.resumed) {
          _trigger((l) => l.onResume());
        } else if (state == AppLifecycleState.paused) {
          _trigger((l) => l.onPause());
        } else if (state == AppLifecycleState.inactive) {
          // Trigger onInactive ONLY when moving from resumed (going towards background/loss of focus).
          // Skip when moving from paused (coming back to foreground).
          if (_lastAppState == AppLifecycleState.resumed) {
            _trigger((l) => l.onInactive());
          }
        }
        _lastAppState = state;
      },
    );

    WidgetsBinding.instance.addObserver(_lifecycleObserver);

    _trigger((l) => l.onInit());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _trigger((l) => l.onReady());
        _isReady = true;
        _evaluateVisibility();
      }
    });
  }

  /// Helper to dispatch lifecycle events to both ViewModel and widget.lifecycle.
  void _trigger(void Function(PageLifecycle lifecycle) action) {
    if (_viewModel != null) action(_viewModel!);
    if (widget.lifecycle != null) action(widget.lifecycle!);
  }

  /// Evaluates and triggers ViewModel lifecycle methods based on the current
  /// combination of Route visibility and the [widget.active] flag.
  void _evaluateVisibility() {
    // Block onVisible until the component is ready (onReady called)
    if (!_isReady) return;

    final bool currentlyVisible = _isRouteVisible && widget.active;
    if (currentlyVisible != _isActuallyVisible) {
      _isActuallyVisible = currentlyVisible;
      if (_isActuallyVisible) {
        _trigger((l) => l.onVisible());
      } else {
        _trigger((l) => l.onInVisible());
      }
    }
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    final bool currentlyVisible = info.visibleFraction > 0;
    if (currentlyVisible != _isViewVisible) {
      _isViewVisible = currentlyVisible;
      if (_isViewVisible) {
        _trigger((l) => l.onViewVisible());
      } else {
        _trigger((l) => l.onViewInVisible());
      }
    }
  }

  void _handleEffect(BaseEffect effect) {
    if (!mounted) return;

    // Synchronize local loading state if a LoadingEffect is received.
    if (effect is LoadingEffect) {
      _updateLoadingState(effect.show);
    } else if (effect is EmptyEffect) {
      _isInternalEmpty.value = effect.show;
    }

    // Delegate standard effect handling to the ViewModel's mixin logic
    final handled = _viewModel?.handleEffect(effect) ?? false;

    // If not handled by the framework (standard effects), pass it to the specific page logic
    if (!handled) widget.onEffect?.call(effect);
  }

  void _updateLoadingState(bool show) {
    if (_isInternalLoading.value == show) return;
    _isInternalLoading.value = show;
    _loadingSafetyTimer?.cancel();
    if (show) {
      // Robustness: Start a safety timer to prevent UI from being permanently locked
      _loadingSafetyTimer = Timer(widget.loadingTimeout, () {
        if (mounted && _isInternalLoading.value) {
          appLogger.w("${widget.title ?? runtimeType}: Loading safety timeout reached. Forcing unlock.");
          _isInternalLoading.value = false;
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      AppNav.observer.subscribe(_routeObserver, route);
      // Initialize the correct visibility state: if the route is not current, it's covered.
      _isRouteVisible = route.isCurrent;
    }
  }

  @override
  void didUpdateWidget(BaseLifeCyclePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      _evaluateVisibility();
    }
    // Fix: When the parent widget passes a new ViewModel instance (e.g. after logout and re-login,
    // where the auto-disposed Riverpod provider is recreated), we must cancel the old effect
    // subscription and bind to the new instance's effect stream. Otherwise, the UI remains
    // listening to the disposed ViewModel and fails to receive new effects (e.g., photo options).
    if (oldWidget.viewModel != widget.viewModel) {
      _effectSubscription?.cancel();
      _viewModel = widget.viewModel;
      if (_viewModel != null) {
        _effectSubscription = _viewModel!.onBindEffect(_handleEffect);
      } else {
        _effectSubscription = null;
      }
    }
  }

  @override
  void dispose() {
    _effectSubscription?.cancel();
    _loadingSafetyTimer?.cancel();
    _isInternalLoading.dispose();
    _isInternalEmpty.dispose();
    AppNav.observer.unsubscribe(_routeObserver);
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    _trigger((l) => l.onDispose());
    ProviderRegistry.handle(LoadingEffect(false));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_isInternalLoading, _isInternalEmpty]),
      builder: (context, child) {
        // Use a Stack instead of conditional returning to keep the 'body'
        // widget tree (and its ViewModel state) alive during loading toggles.
        Widget content = Stack(
          fit: (widget.useScaffold || widget.expandBody)
              ? StackFit.expand
              : StackFit.loose, // Ensures full screen for pages/tabs, wrap content for sheets
          children: [
            // Normal content is always present to preserve State/ViewModel continuity.
            widget.body(context, child),

            // Loading Overlay (e.g., Skeleton)
            if (_isInternalLoading.value && widget.onLoading != null)
              Positioned.fill(
                child: ColoredBox(color: Theme.of(context).scaffoldBackgroundColor, child: widget.onLoading!),
              ),

            // Empty State Overlay
            if (!_isInternalLoading.value && _isInternalEmpty.value && widget.onEmpty != null)
              Positioned.fill(
                child: ColoredBox(color: Theme.of(context).scaffoldBackgroundColor, child: widget.onEmpty!),
              ),
          ],
        );

        if (widget.useVisibilityDetector) {
          content = VisibilityDetector(
            // FIX: Use a stable key that doesn't depend on title to prevent rebuilds on title changes.
            key: ValueKey('visibility-${_viewModel?.runtimeType ?? runtimeType}'),
            onVisibilityChanged: _onVisibilityChanged,
            child: content,
          );
        }

        Widget result = content;
        if (widget.useScaffold) {
          result = BaseScaffoldPage(
            title: widget.title,
            actions: widget.actions,
            appBar: widget.appBar,
            drawer: widget.drawer,
            drawerEnableOpenDragGesture: widget.drawerEnableOpenDragGesture,
            floatingActionButton: widget.floatingActionButton,
            useSafeArea: widget.useSafeArea,
            padding: widget.padding,
            resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
            extendBodyBehindAppBar: widget.extendBodyBehindAppBar,
            useStatusBar: widget.useStatusBar,
            useBottomBar: widget.useBottomBar,
            isEmptyTitle: widget.isEmptyTitle,
            statusBarColor: widget.statusBarColor,
            bottomBarColor: widget.bottomBarColor,
            useGradientBackground: widget.useGradientBackground,
            child: content,
          );
        }

        return PopScope(
          canPop: !widget.active || ((widget.canPop ?? true) && !_isInternalLoading.value),
          onPopInvokedWithResult: (didPop, resultVal) {
            if (!widget.active) return;
            if (didPop) {
              // Page successfully popped. Cancel pending requests immediately to release network resources.
              _viewModel?.cancelRequests("onBackInvoked");
            } else if (_isInternalLoading.value) {
              // If page is currently loading internally, intercept back gesture to cancel requests and dismiss loading spinner first.
              _viewModel?.cancelRequests("onBackInvoked");
              _viewModel?.emitEffect(LoadingEffect(false));
            } else if (widget.onInterceptBack != null) {
              // Back gesture blocked/intercepted. Trigger custom intercept callback if provided.
              widget.onInterceptBack!();
            }
          },
          child: result,
        );
      },
    );
  }
}

/// Dedicated class to handle RouteAware callbacks without polluting the main State class.
class _RouteAwareProxy extends RouteAware {
  final VoidCallback onVisible;
  final VoidCallback onInVisible;

  /// Callback invoked synchronously when the route is popped or replaced.
  final VoidCallback? onPop;

  _RouteAwareProxy({required this.onVisible, required this.onInVisible, this.onPop});

  @override
  /// Called when the current route has been pushed.
  void didPush() => onVisible();

  @override
  /// Called when the top route has been popped off, and the current route shows up.
  void didPopNext() => onVisible();

  @override
  /// Called when a new route has been pushed, and the current route is no longer visible.
  void didPushNext() => onInVisible();

  @override
  /// Called when the current route has been popped off (permanently exiting).
  void didPop() {
    onInVisible();
    onPop?.call();
  }
}

/// Dedicated class to handle WidgetsBindingObserver callbacks.
class _AppLifecycleProxy extends WidgetsBindingObserver {
  final ValueChanged<AppLifecycleState> onStateChanged;

  _AppLifecycleProxy({required this.onStateChanged});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    onStateChanged(state);
  }
}
