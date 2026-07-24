import 'dart:async';

/// Abstract interface for secure credential storage.
///
/// Implementations must use platform-specific secure storage:
/// - iOS: Keychain
/// - Android: Keystore
/// - macOS: Keychain
/// - Windows: Credential Manager
/// - HarmonyOS: Secure Storage
abstract interface class SecureStorage {
  /// Read a value by [key].
  Future<String?> read(String key);

  /// Write [value] by [key].
  Future<void> write(String key, String value);

  /// Delete a value by [key].
  Future<void> delete(String key);

  /// Check if [key] exists.
  Future<bool> containsKey(String key);
}

/// Keys used in secure storage.
class SecureStorageKeys {
  const SecureStorageKeys._();

  static const String llmApiKey = 'llm_api_key';
  static const String llmBaseUrl = 'llm_base_url';
  static const String llmModel = 'llm_model';
  static const String baiduAccessToken = 'baidu_access_token';
  static const String baiduRefreshToken = 'baidu_refresh_token';
  static const String webdavPassword = 'webdav_password';
  static const String webdavToken = 'webdav_token';
}
