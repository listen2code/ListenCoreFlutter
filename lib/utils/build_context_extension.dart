import 'package:flutter/material.dart';

extension BuildContextExtension on BuildContext {
  /// Theme-related shortcuts
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  /// Custom shortcuts based on the app's design system
  Color get accentColor => Theme.of(this).colorScheme.primary;

  /// MediaQuery-related shortcuts
  MediaQueryData get mediaQuery => MediaQuery.of(this);
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;
  EdgeInsets get screenPadding => MediaQuery.of(this).padding;
  double get viewInsetsBottom => MediaQuery.of(this).viewInsets.bottom;
}
