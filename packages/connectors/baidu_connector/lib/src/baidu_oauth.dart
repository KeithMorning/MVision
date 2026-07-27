import 'package:dio/dio.dart';
import 'package:platform_api/platform_api.dart';

/// Baidu OAuth 2.0 authentication handler.
///
/// Implements the authorization code flow for Baidu Netdisk access.
/// See FR-SOURCE-003 in mvision-development-requirements.md
class BaiduOAuth {
  final SecureStorage secureStorage;
  final String clientId;
  final String clientSecret;
  final String redirectUri;
  final Dio _dio;

  String? _accessToken;
  String? _refreshToken;
  DateTime? _expiresAt;
  String? _userId;

  static const _authEndpoint = 'https://openapi.baidu.com/oauth/2.0/authorize';
  static const _tokenEndpoint = 'https://openapi.baidu.com/oauth/2.0/token';

  BaiduOAuth({
    required this.secureStorage,
    required this.clientId,
    required this.clientSecret,
    required this.redirectUri,
    Dio? dio,
  }) : _dio = dio ?? Dio();

  String? get userId => _userId;
  bool get isAuthenticated => _accessToken != null && _expiresAt != null && DateTime.now().isBefore(_expiresAt!);

  /// Get the authorization URL for OAuth flow.
  ///
  /// User opens this in a browser, authorizes, and gets redirected
  /// to [redirectUri] with a `code` parameter.
  String getAuthorizationUrl() {
    return '$_authEndpoint'
        '?response_type=code'
        '&client_id=$clientId'
        '&redirect_uri=${Uri.encodeComponent(redirectUri)}'
        '&scope=basic,netdisk'
        '&display=popup';
  }

  /// Exchange authorization code for access token.
  Future<bool> exchangeCode(String code) async {
    try {
      final response = await _dio.get(_tokenEndpoint, queryParameters: {
        'grant_type': 'authorization_code',
        'code': code,
        'client_id': clientId,
        'client_secret': clientSecret,
        'redirect_uri': redirectUri,
      });

      if (response.statusCode == 200) {
        final data = response.data;
        _accessToken = data['access_token'] as String?;
        _refreshToken = data['refresh_token'] as String?;
        final expiresIn = data['expires_in'] as int? ?? 2592000; // 30 days default
        _expiresAt = DateTime.now().add(Duration(seconds: expiresIn - 60));

        await saveTokens();
        return _accessToken != null;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Get a valid access token, refreshing if necessary.
  Future<String?> getValidToken() async {
    if (_accessToken != null && _expiresAt != null) {
      if (DateTime.now().isBefore(_expiresAt!)) {
        return _accessToken;
      }
      // Token expired, try to refresh
      final refreshed = await refreshToken();
      if (refreshed) return _accessToken;
    }
    return null;
  }

  /// Refresh the access token using the refresh token.
  Future<bool> refreshToken() async {
    if (_refreshToken == null) return false;

    try {
      final response = await _dio.get(_tokenEndpoint, queryParameters: {
        'grant_type': 'refresh_token',
        'refresh_token': _refreshToken,
        'client_id': clientId,
        'client_secret': clientSecret,
      });

      if (response.statusCode == 200) {
        final data = response.data;
        _accessToken = data['access_token'] as String?;
        _refreshToken = data['refresh_token'] as String? ?? _refreshToken;
        final expiresIn = data['expires_in'] as int? ?? 2592000;
        _expiresAt = DateTime.now().add(Duration(seconds: expiresIn - 60));

        await saveTokens();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Load tokens from secure storage.
  Future<void> loadTokens() async {
    _accessToken = await secureStorage.read(SecureStorageKeys.baiduAccessToken);
    _refreshToken = await secureStorage.read(SecureStorageKeys.baiduRefreshToken);

    // If we have tokens, assume they might still be valid
    // (actual expiry check happens on API call)
    if (_accessToken != null) {
      // Set a generous expiry; refresh will handle actual expiry
      _expiresAt = DateTime.now().add(const Duration(days: 30));
    }
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
