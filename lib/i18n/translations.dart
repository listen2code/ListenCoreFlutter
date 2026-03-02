/// Core translation engine.
/// This class is business-agnostic and relies on data registered at runtime.
class Translations {
  Translations._();

  static Map<String, Map<String, String>> _data = {};

  static String Function()? _languageCodeProvider;

  /// Default language code to fallback when no translation is found.
  static const String _defaultLanguage = 'en';

  static void register({
    required Map<String, Map<String, String>> data,
    required String Function() languageCodeProvider,
  }) {
    _data = data;
    _languageCodeProvider = languageCodeProvider;
  }

  static String translate(String key) {
    final languageCode = _languageCodeProvider?.call() ?? _defaultLanguage;
    
    // 1. Try to find the translation in the registered data
    final translated = _data[languageCode]?[key];
    if (translated != null) return translated;

    // 2. Optimization: If the current language is English, and we use the text itself as the Key,
    // we can return the Key directly. This eliminates the need for en.dart.
    if (languageCode == _defaultLanguage) return key;

    // 3. Fallback to the key itself
    return key;
  }
}

/// Extension to provide easy translation access on strings.
extension TranslationExtension on String {
  /// Translates the string key using the current locale.
  String get tr => Translations.translate(this);

  /// Supports argument replacement: "Hello %s" -> trArgs(["Listen"]) -> "Hello Listen"
  String trArgs(List<dynamic> args) {
    String translated = tr;
    for (var arg in args) {
      translated = translated.replaceFirst('%s', arg.toString());
    }
    return translated;
  }
}
