import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Utility class for SharedPreferences.
/// It's recommended to call [SpUtil.init()] in main() before runApp().
class SpUtil {
  static SharedPreferences? _prefs;
  static String _prefix = '';

  SpUtil._();

  /// Initialize the SharedPreferences instance globally.
  /// [prefix] will be prepended to all keys.
  static Future<void> init({String prefix = ''}) async {
    _prefix = prefix;
    // We remove ??= to ensure that in test environments,
    // calling init() multiple times correctly picks up the latest Mock instance.
    _prefs = await SharedPreferences.getInstance();
  }

  /// Internal helper to ensure _prefs is available.
  static Future<SharedPreferences> get _instance async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Helper to get the full key with prefix.
  static String _getKey(String key) => '$_prefix$key';

  /// Save a value by key.
  /// Supports String, bool, int, double, `List<String>`, and Map/Object (via JSON).
  static Future<bool> put(String key, dynamic value) async {
    final prefs = await _instance;
    final fullKey = _getKey(key);

    if (value is String) {
      return prefs.setString(fullKey, value);
    } else if (value is bool) {
      return prefs.setBool(fullKey, value);
    } else if (value is int) {
      return prefs.setInt(fullKey, value);
    } else if (value is double) {
      return prefs.setDouble(fullKey, value);
    } else if (value is List<String>) {
      return prefs.setStringList(fullKey, value);
    } else {
      // For complex objects, store as JSON string
      return prefs.setString(fullKey, jsonEncode(value));
    }
  }

  /// Get a string value.
  static String? getString(String key, {String? defaultValue}) {
    return _prefs?.getString(_getKey(key)) ?? defaultValue;
  }

  /// Get a boolean value.
  static bool getBool(String key, {bool defaultValue = false}) {
    return _prefs?.getBool(_getKey(key)) ?? defaultValue;
  }

  /// Get an integer value.
  static int? getInt(String key, {int? defaultValue}) {
    return _prefs?.getInt(_getKey(key)) ?? defaultValue;
  }

  /// Get a double value.
  static double? getDouble(String key, {double? defaultValue}) {
    return _prefs?.getDouble(_getKey(key)) ?? defaultValue;
  }

  /// Get a string list.
  static List<String>? getStringList(String key, {List<String>? defaultValue}) {
    return _prefs?.getStringList(_getKey(key)) ?? defaultValue;
  }

  /// Get a complex object parsed from JSON.
  static T? getObject<T>(String key, T Function(Map<String, dynamic>) fromJson) {
    final String? jsonStr = _prefs?.getString(_getKey(key));
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      return fromJson(jsonDecode(jsonStr));
    } catch (e) {
      return null;
    }
  }

  /// Remove a value by key.
  static Future<bool> remove(String key) async {
    final prefs = await _instance;
    return prefs.remove(_getKey(key));
  }

  /// Clear all preferences.
  static Future<bool> clear() async {
    final prefs = await _instance;
    return prefs.clear();
  }

  /// Check if a key exists.
  static bool containsKey(String key) {
    return _prefs?.containsKey(_getKey(key)) ?? false;
  }

  /// Reload preferences from disk.
  static Future<void> reload() async {
    final prefs = await _instance;
    await prefs.reload();
  }
}
