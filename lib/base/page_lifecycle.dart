/// Defines the lifecycle callbacks for page widgets.
///
/// This interface provides a standardized set of lifecycle methods that
/// can be implemented by page widgets to handle various states of their
/// lifecycle from initialization to disposal.
abstract class PageLifecycle {
  /// Called when the page is first initialized.
  ///
  /// This is the first lifecycle method called and is where you should
  /// perform one-time initialization tasks that don't require BuildContext.
  void onInit() {}

  /// Called after the widget has been built and is ready.
  ///
  /// This method is called after the widget tree has been built and
  /// can be used for operations that require the widget to be fully
  /// initialized.
  void onReady() {}

  /// Called when the page becomes visible to the user.
  ///
  /// This is triggered when the page is displayed on screen and can
  /// be used for starting animations, loading data, or other operations
  /// that should only run when the page is visible.
  void onVisible() {}

  /// Called when the page is no longer visible to the user.
  ///
  /// This is triggered when the page is hidden from view and can be
  /// used for pausing operations, saving state, or cleaning up resources
  /// that are only needed when the page is visible.
  void onInVisible() {}

  /// Called when the widget physically enters the viewport.
  ///
  /// This is different from [onVisible] as it's based on the actual
  /// visibility of the widget in the viewport, useful for performance
  /// optimizations.
  void onViewVisible() {}

  /// Called when the widget physically leaves the viewport.
  ///
  /// This is different from [onInVisible] as it's based on the actual
  /// visibility of the widget in the viewport, useful for performance
  /// optimizations.
  void onViewInVisible() {}

  /// Called when the app is resumed from background.
  ///
  /// This method is called when the app comes to the foreground and
  /// can be used for refreshing data, restarting operations, or other
  /// tasks that should run when the app becomes active.
  void onResume() {}

  /// Called when the app is paused or sent to background.
  ///
  /// This method is called when the app goes to the background and
  /// can be used for pausing operations, saving state, or other cleanup
  /// tasks that should run when the app becomes inactive.
  void onPause() {}

  /// Called when the app becomes inactive.
  ///
  /// This is called when the app is no longer in the foreground but
  /// hasn't been fully paused yet. Use this for operations that should
  /// stop when the app is not actively being used.
  void onInactive() {}

  /// Called when the page is about to be disposed.
  ///
  /// This is the last lifecycle method called and should be used for
  /// cleanup tasks like canceling subscriptions, disposing controllers,
  /// and releasing resources to prevent memory leaks.
  void onDispose() {}
}
