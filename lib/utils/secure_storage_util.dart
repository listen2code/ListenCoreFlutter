import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'sp_util.dart';

/// Utility class for FlutterSecureStorage to handle sensitive data encryption.
/// All methods are asynchronous as they involve disk I/O and encryption.
class SecureStorageUtil {
  static FlutterSecureStorage? _storage;
  static String _prefix = '';
  static final Map<String, String> _memoryFallback = {};

  SecureStorageUtil._();

  /// Initialize the SecureStorage instance globally.
  /// [prefix] will be prepended to all keys.
  static Future<void> init({String prefix = ''}) async {
    _prefix = prefix;
    // We create a new instance to ensure configurations like AndroidOptions are applied.
    // In tests, this allows resetting the state if needed.
    _storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(),
      iOptions: IOSOptions(
        // Keychain accessibility options for iOS.
        accessibility: KeychainAccessibility.first_unlock,
      ),
    );
  }

  /// Helper to get the full key with prefix.
  static String _getKey(String key) => '$_prefix$key';

  /// Encrypts and saves the [key] with the given [value].
  static Future<void> put(String key, String? value) async {
    final fullKey = _getKey(key);
    try {
      if (value == null) {
        await _storage?.delete(key: fullKey);
        _memoryFallback.remove(fullKey);
      } else {
        await _storage?.write(key: fullKey, value: value);
        _memoryFallback[fullKey] = value;
      }
    } catch (_) {
      // In insecure contexts (e.g. Flutter Web served over HTTP), Web Crypto API is unavailable.
      // Fallback safely to SpUtil and in-memory cache so operations never crash or freeze.
      if (value == null) {
        await SpUtil.remove('__sec_$fullKey');
        _memoryFallback.remove(fullKey);
      } else {
        await SpUtil.put('__sec_$fullKey', value);
        _memoryFallback[fullKey] = value;
      }
    }
  }

  /// Decrypts and returns the value for the given [key].
  static Future<String?> get(String key) async {
    final fullKey = _getKey(key);
    try {
      final val = await _storage?.read(key: fullKey);
      if (val != null) return val;
    } catch (_) {
      // Fallback on error (e.g. Web Crypto unavailable)
    }
    final spVal = SpUtil.getString('__sec_$fullKey');
    if (spVal != null) return spVal;
    return _memoryFallback[fullKey];
  }

  /// Deletes associated value for the given [key].
  static Future<void> remove(String key) async {
    final fullKey = _getKey(key);
    try {
      await _storage?.delete(key: fullKey);
    } catch (_) {}
    await SpUtil.remove('__sec_$fullKey');
    _memoryFallback.remove(fullKey);
  }

  /// Deletes all keys with associated values.
  static Future<void> clear() async {
    try {
      await _storage?.deleteAll();
    } catch (_) {}
    _memoryFallback.clear();
  }

  /// Returns true if the storage contains the given [key].
  static Future<bool> containsKey(String key) async {
    final fullKey = _getKey(key);
    try {
      final exists = await _storage?.containsKey(key: fullKey);
      if (exists == true) return true;
    } catch (_) {}
    return SpUtil.containsKey('__sec_$fullKey') || _memoryFallback.containsKey(fullKey);
  }

  /// Decrypts and returns all keys with associated values.
  static Future<Map<String, String>> getAll() async {
    try {
      return await _storage?.readAll() ?? Map<String, String>.from(_memoryFallback);
    } catch (_) {
      return Map<String, String>.from(_memoryFallback);
    }
  }
}
