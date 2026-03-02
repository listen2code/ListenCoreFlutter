import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Utility class for FlutterSecureStorage to handle sensitive data encryption.
/// All methods are asynchronous as they involve disk I/O and encryption.
class SecureStorageUtil {
  static FlutterSecureStorage? _storage;
  static String _prefix = '';

  SecureStorageUtil._();

  /// Initialize the SecureStorage instance globally.
  /// [prefix] will be prepended to all keys.
  static Future<void> init({String prefix = ''}) async {
    _prefix = prefix;
    // We create a new instance to ensure configurations like AndroidOptions are applied.
    // In tests, this allows resetting the state if needed.
    _storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(
        // encryptedSharedPreferences is deprecated and will be removed in v11.
        // The library now automatically handles migration to custom ciphers.
      ),
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
    await _storage?.write(key: _getKey(key), value: value);
  }

  /// Decrypts and returns the value for the given [key].
  static Future<String?> get(String key) async {
    return await _storage?.read(key: _getKey(key));
  }

  /// Deletes associated value for the given [key].
  static Future<void> remove(String key) async {
    await _storage?.delete(key: _getKey(key));
  }

  /// Deletes all keys with associated values.
  static Future<void> clear() async {
    await _storage?.deleteAll();
  }

  /// Returns true if the storage contains the given [key].
  static Future<bool> containsKey(String key) async {
    return await _storage?.containsKey(key: _getKey(key)) ?? false;
  }

  /// Decrypts and returns all keys with associated values.
  static Future<Map<String, String>> getAll() async {
    return await _storage?.readAll() ?? {};
  }
}
