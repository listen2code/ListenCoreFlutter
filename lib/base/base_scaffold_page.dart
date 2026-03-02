import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A pure UI skeleton widget that handles common page structures like
/// AppBar, StatusBar, BottomBar, and Background decorations.
class BaseScaffoldPage extends StatelessWidget {
  final Widget child;
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
  final bool useGradientBackground;

  /// Controls the PopScope and gesture behavior
  final bool canPop;
  final VoidCallback? onBackInvoked;

  const BaseScaffoldPage({
    super.key,
    required this.child,
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
    this.canPop = true,
    this.onBackInvoked,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = theme.iconTheme.color ?? theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;

    Widget content = child;
    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }

    content = Column(
      children: [
        if (useStatusBar) _createStatusBar(context),
        Expanded(child: content),
        if (useBottomBar) _createBottomBar(context),
      ],
    );

    if (useSafeArea) {
      content = SafeArea(top: !useStatusBar, bottom: !useBottomBar, child: content);
    }

    PreferredSizeWidget? effectiveAppBar = appBar;
    if (effectiveAppBar == null && (title != null || isEmptyTitle)) {
      effectiveAppBar = _createAppBar(theme);
    }

    final scaffoldWidget = Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: effectiveAppBar,
      drawer: drawer,
      floatingActionButton: floatingActionButton,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: useGradientBackground
            ? BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentColor.withValues(alpha: 0.05), theme.scaffoldBackgroundColor],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              )
            : null,
        child: content,
      ),
    );

    final systemUiOverlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: theme.scaffoldBackgroundColor,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    );

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        onBackInvoked?.call();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: systemUiOverlayStyle,
        child: GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          behavior: HitTestBehavior.translucent,
          child: scaffoldWidget,
        ),
      ),
    );
  }

  AppBar _createAppBar(ThemeData theme) {
    return AppBar(
      title: Text(
        title ?? "",
        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w300),
      ),
      centerTitle: true,
      actions: actions,
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: theme.brightness == Brightness.light ? Colors.black87 : Colors.white,
    );
  }

  Widget _createStatusBar(BuildContext context) {
    // If status bar is transparent, don't take up any height to allow immersive content
    if (statusBarColor == Colors.transparent) return const SizedBox.shrink();
    return Container(color: statusBarColor, height: MediaQuery.of(context).padding.top);
  }

  Widget _createBottomBar(BuildContext context) {
    if (bottomBarColor == Colors.transparent) return const SizedBox.shrink();
    return Container(color: bottomBarColor, height: MediaQuery.of(context).padding.bottom);
  }
}
