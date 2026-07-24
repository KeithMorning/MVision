import 'package:platform_api/platform_api.dart';

/// Baidu OAuth 2.0 authentication handler.
///
/// See FR-SOURCE-003 in mvision-development-requirements.md
class BaiduOAuth {
  final SecureStorage secureStorage;
  final String clientId;
  final String redirectUri;

  String? _accessToken;
  String? _refreshToken;
  DateTime? _expiresAt;
  String? _userId;

  BaiduOAuth({
    required this.secureStorage,
    required this.clientId,
    required this.redirectUri,
  });

  String? get userId => _userId;

  /// Get the authorization URL for OAuth flow.
  String getAuthorizationUrl() {
    return 'https://openapi.baidu.com/oauth/2.0/authorize'
        '?response_type=code'
        '&client_id=$clientId'
        '&redirect_uri=${Uri.encodeComponent(redirectUri)}'
        '&scope=basic,netdisk'
        '&display=popup';
  }

  /// Exchange authorization code for access token.
  Future<bool> exchangeCode(String code) async {
    // TODO: Implement in Phase 2
    // This will make HTTP request to Baidu OAuth endpoint
    return false;
  }

  /// Get a valid access token, refreshing if necessary.
  Future<String?> getValidToken() async {
    if (_accessToken != null && _expiresAt != null) {
      if (DateTime.now().isBefore(_expiresAt!)) {
        return _accessToken;
      }
      // Token expired, try to refresh
      await refreshToken();
    }
    return _accessToken;
  }

  /// Refresh the access token.
  Future<bool> refreshToken() async {
    if (_refreshToken == null) return false;
    // TODO: Implement in Phase 2
    return false;
  }

  /// Load tokens from secure storage.
  Future<void> loadTokens() async {
    _accessToken = await secureStorage.read(SecureStorageKeys.baiduAccessToken);
    _refreshToken = await secureStorage.read(SecureStorageKeys.baiduRefreshToken);
  }

  /// Save tokens to secure storage.
  Future<void> saveTokens() async {
    if (_accessToken != null) {
      await secureStorage.write(SecureStorageKeys.baiduAccessToken, _accessToken!);
    }
    if (_refreshToken != null) {
      await secureStorage.write(SecureStorageKeys.baiduRefreshToken, _refreshToken!);
    }
  }

  /// Clear all tokens (logout).
  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    _expiresAt = null;
    _userId = null;
    await secureStorage.delete(SecureStorageKeys.baiduAccessToken);
    await secureStorage.delete(SecureStorageKeys.baiduRefreshToken);
  }
}
