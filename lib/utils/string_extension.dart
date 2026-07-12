extension NullableStringExtension on String? {
  /// Returns `true` if the string is null, empty, or contains only whitespace characters.
  bool get isNullOrBlank => this == null || this!.trim().isEmpty;
}
