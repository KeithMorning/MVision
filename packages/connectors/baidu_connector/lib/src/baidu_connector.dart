import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:knowledge_core/knowledge_core.dart';
import 'baidu_oauth.dart';

/// Baidu Netdisk storage connector.
///
/// This is a placeholder for Phase 2 implementation.
/// See FR-SOURCE-003 in mvision-development-requirements.md
class BaiduConnector implements StorageConnector {
  final BaiduOAuth oauth;
  final Dio _dio;

  BaiduConnector({
    required this.oauth,
    Dio? dio,
  }) : _dio = dio ?? Dio();

  @override
  String get sourceId => 'baidu:${oauth.userId ?? "unknown"}';

  @override
  Future<ConnectionResult> connect() async {
    try {
      final token = await oauth.getValidToken();
      if (token == null) {
        return ConnectionResult.failure('Not authenticated');
      }

      // Test connection by getting user info
      final response = await _dio.get(
        'https://pan.baidu.com/rest/2.0/xpan/nas',
        queryParameters: {
          'method': 'uinfo',
          'access_token': token,
        },
      );

      if (response.statusCode == 200) {
        return ConnectionResult.success();
      } else {
        return ConnectionResult.failure('API error: ${response.statusCode}');
      }
    } catch (e) {
      return ConnectionResult.failure(e.toString());
    }
  }

  @override
  Future<List<StorageEntry>> list(String path) async {
    // TODO: Implement in Phase 2
    throw UnimplementedError('BaiduConnector.list will be implemented in Phase 2');
  }

  @override
  Future<Uint8List> read(String path) async {
    // TODO: Implement in Phase 2
    throw UnimplementedError('BaiduConnector.read will be implemented in Phase 2');
  }

  @override
  Future<WriteResult> write(String path, Uint8List data) async {
    // TODO: Implement in Phase 2
    throw UnimplementedError('BaiduConnector.write will be implemented in Phase 2');
  }

  @override
  Future<void> move(String from, String to) async {
    // TODO: Implement in Phase 2
    throw UnimplementedError('BaiduConnector.move will be implemented in Phase 2');
  }

  @override
  Future<void> delete(String path) async {
    // TODO: Implement in Phase 2
    throw UnimplementedError('BaiduConnector.delete will be implemented in Phase 2');
  }

  @override
  Future<StorageMetadata> metadata(String path) async {
    // TODO: Implement in Phase 2
    throw UnimplementedError('BaiduConnector.metadata will be implemented in Phase 2');
  }
}
