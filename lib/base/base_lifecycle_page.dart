import 'dart:async';

import 'package:flutter/material.dart';

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

  /// Optional callback to handle custom UI effects.
  final void Function(BaseEffect effect)? onEffect;

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
    this.loadingTimeout = const Duration(seconds: 10),
    this.onInterceptBack,
    this.viewModel,
    this.onEffect,
  });

  @override
  State<BaseLifeCyclePage> createState() => _BaseLifeCyclePageState();
}

class _BaseLifeCyclePageState extends State<BaseLifeCyclePage> {
  bool _isRouteVisible = false;
  BaseViewModel? _viewModel;
  StreamSubscription<BaseEffect>? _effectSubscription;

  // Local state to track loading based on Effects, used for canPop logic.
  final ValueNotifier<bool> _isInternalLoading = ValueNotifier<bool>(false);
  Timer? _loadingSafetyTimer;

  late final _RouteAwareProxy _routeObserver;
  late final _AppLifecycleProxy _lifecycleObserver;

  @override
  void initState() {
    super.initState();

    // Directly use the provided viewModel instance
    _viewModel = widget.viewModel;

    // Subscribe to Effects (Toast, Loading, Navigation, etc.)
    if (_viewModel != null) {
      _effectSubscription = _viewModel!.effectStream.listen(_handleEffect);
    }

    // Initialize Observers
    _routeObserver = _RouteAwareProxy(
      onVisible: () => _checkVisibilityChange(true),
      onInVisible: () => _checkVisibilityChange(false),
      onPush: () => _isRouteVisible = true,
    );

    _lifecycleObserver = _AppLifecycleProxy(
      onStateChanged: (state) {
        if (!_isRouteVisible || !widget.active) return;

        if (state == AppLifecycleState.resumed) {
          _viewModel?.onResume();
        } else if (state == AppLifecycleState.paused) {
          _viewModel?.onPause();
        } else if (state == AppLifecycleState.inactive) {
          _viewModel?.onInactive();
        }
      },
    );

    WidgetsBinding.instance.addObserver(_lifecycleObserver);

    _viewModel?.onInit();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _viewModel?.onReady();
        if (widget.active) _checkVisibilityChange(true);
      }
    });
  }

  void _handleEffect(BaseEffect effect) {
    if (!mounted) return;

    // Synchronize local loading state if a LoadingEffect is received.
    if (effect is LoadingEffect) {
      _updateLoadingState(effect.show);
    }

    // Delegate standard effect handling to the ViewModel's mixin logic
    final handled = _viewModel?.handleEffect(effect) ?? false;

    // If not handled by the framework (standard effects), pass it to the specific page logic
    if (!handled) {
      widget.onEffect?.call(effect);
    }
  }

  void _updateLoadingState(bool show) {
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
    }
  }

  @override
  void didUpdateWidget(BaseLifeCyclePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      _checkVisibilityChange(widget.active);
    }
  }

  @override
  void dispose() {
    _loadingSafetyTimer?.cancel();
    _effectSubscription?.cancel();
    _isInternalLoading.dispose();
    AppNav.observer.unsubscribe(_routeObserver);
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    _viewModel?.onDispose();
    super.dispose();
  }

  void _checkVisibilityChange(bool isVisible) {
    if (isVisible) {
      _viewModel?.onVisible();
    } else {
      _viewModel?.onInVisible();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _isInternalLoading,
      builder: (context, child) {
        // Effective canPop: user's canPop (default true) and not loading
        final effectiveCanPop = (widget.canPop ?? true) && !_isInternalLoading.value;

        return BaseScaffoldPage(
          title: widget.title,
          actions: widget.actions,
          appBar: widget.appBar,
          drawer: widget.drawer,
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
          canPop: effectiveCanPop,
          onBackInvoked: () {
            // Priority given to custom interception logic
            if (widget.onInterceptBack != null) {
              widget.onInterceptBack!();
            } else {
              _viewModel?.cancelRequests("on BackInvoked");
              // Loading is managed via effects to keep local _isInternalLoading in sync.
              _viewModel?.emitEffect(LoadingEffect(false));
            }
          },
          child: widget.body(context, child),
        );
      },
    );
  }
}

/// Dedicated class to handle RouteAware callbacks without polluting the main State class.
class _RouteAwareProxy extends RouteAware {
  final VoidCallback onVisible;
  final VoidCallback onInVisible;
  final VoidCallback onPush;

  _RouteAwareProxy({required this.onVisible, required this.onInVisible, required this.onPush});

  @override
  /// Called when the current route has been pushed.
  void didPush() => onPush();

  @override
  /// Called when the top route has been popped off, and the current route shows up.
  void didPopNext() => onVisible();

  @override
  /// Called when a new route has been pushed, and the current route is no longer visible.
  void didPushNext() => onInVisible();

  @override
  /// Called when the current route has been popped off.
  void didPop() => onInVisible();
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
