extension NullableStringExtension on String? {
  /// Returns `true` if the string is null, empty, or contains only whitespace characters.
  bool get isNullOrBlank => this == null || this!.trim().isEmpty;
}

extension StringExtension on String {
  /// Returns `true` if the string is a valid email address.
  bool get isEmail {
    return RegExp(
      r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
    ).hasMatch(this);
  }

  /// Returns `true` if the string is a valid HTTP/HTTPS URL.
  bool get isUrl {
    return RegExp(
      r"^https?://[a-zA-Z0-9\-._~:/?#\[\]@!$&'()*+,;=]+",
    ).hasMatch(this);
  }

  /// Returns `true` if the string contains only numeric characters.
  bool get isNumeric {
    return double.tryParse(this) != null;
  }

  /// Safely parses the string to an integer, returning [defaultValue] on failure.
  int toInt({int defaultValue = 0}) {
    return int.tryParse(this) ?? defaultValue;
  }

  /// Safely parses the string to a double, returning [defaultValue] on failure.
  double toDouble({double defaultValue = 0.0}) {
    return double.tryParse(this) ?? defaultValue;
  }
}
