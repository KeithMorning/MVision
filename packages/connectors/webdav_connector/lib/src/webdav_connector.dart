import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:knowledge_core/knowledge_core.dart';
import 'package:xml/xml.dart';

/// WebDAV storage connector.
///
/// Implements FR-SOURCE-004: WebDAV support with HTTPS enforcement,
/// username/password or token auth, and connection testing.
class WebdavConnector implements StorageConnector {
  final String baseUrl;
  final String? username;
  final String? password;
  final String? token;
  final String rootPath;
  final Dio _dio;

  WebdavConnector({
    required this.baseUrl,
    this.username,
    this.password,
    this.token,
    this.rootPath = '/',
    Dio? dio,
  }) : _dio = dio ?? Dio() {
    // HTTPS enforcement (FR-SOURCE-004: plain HTTP must warn, default deny)
    if (baseUrl.startsWith('http://')) {
      throw ArgumentError(
        'WebDAV URL must use HTTPS for security. Plain HTTP is not allowed: $baseUrl',
      );
    }
    if (!baseUrl.startsWith('https://')) {
      throw ArgumentError('WebDAV URL must start with https://: $baseUrl');
    }
  }

  @override
  String get sourceId => 'webdav:${Uri.parse(baseUrl).host}:$rootPath';

  String _fullUrl(String path) {
    final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return '$base$cleanPath';
  }

  @override
  Future<ConnectionResult> connect() async {
    try {
      // Test connection with PROPFIND on root
      final response = await _dio.request(
        _fullUrl(rootPath),
        options: Options(
          method: 'PROPFIND',
          headers: {
            ..._buildHeaders(),
            'Depth': '0',
            'Content-Type': 'application/xml',
          },
        ),
        data: '<?xml version="1.0"?><propfind xmlns="DAV:"><prop><resourcetype/></prop></propfind>',
      );

      if (response.statusCode == 207 || response.statusCode == 200) {
        return ConnectionResult.success();
      } else {
        return ConnectionResult.failure('Connection failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        return ConnectionResult.failure('Authentication failed: invalid credentials');
      }
      return ConnectionResult.failure('Connection error: ${e.message}');
    } catch (e) {
      return ConnectionResult.failure('Connection error: $e');
    }
  }

  @override
  Future<List<StorageEntry>> list(String path) async {
    final fullPath = _joinPath(rootPath, path);
    
    try {
      final response = await _dio.request(
        _fullUrl(fullPath),
        options: Options(
          method: 'PROPFIND',
          headers: {
            ..._buildHeaders(),
            'Depth': '1',
            'Content-Type': 'application/xml',
          },
        ),
        data: '''<?xml version="1.0"?>
<propfind xmlns="DAV:">
  <prop>
    <displayname/>
    <resourcetype/>
    <getcontentlength/>
    <getlastmodified/>
  </prop>
</propfind>''',
      );

      if (response.statusCode != 207) {
        throw Exception('PROPFIND failed: ${response.statusCode}');
      }

      return _parseMultiStatus(response.data.toString(), fullPath);
    } on DioException catch (e) {
      throw Exception('WebDAV list failed: ${e.message}');
    }
  }

  List<StorageEntry> _parseMultiStatus(String xml, String basePath) {
    final entries = <StorageEntry>[];
    
    try {
      final document = XmlDocument.parse(xml);
      final responses = document.findAllElements('response', namespace: 'DAV:');
      
      for (final response in responses) {
        final href = response.findElements('href', namespace: 'DAV:').firstOrNull?.innerText ?? '';
        final propstat = response.findElements('propstat', namespace: 'DAV:').firstOrNull;
        final prop = propstat?.findElements('prop', namespace: 'DAV:').firstOrNull;
        
        if (prop == null) continue;
        
        // Check if directory
        final resourceType = prop.findElements('resourcetype', namespace: 'DAV:').firstOrNull;
        final isDirectory = resourceType?.findElements('collection', namespace: 'DAV:').isNotEmpty ?? false;
        
        // Get display name
        final displayName = prop.findElements('displayname', namespace: 'DAV:').firstOrNull?.innerText ?? '';
        
        // Get size
        final sizeStr = prop.findElements('getcontentlength', namespace: 'DAV:').firstOrNull?.innerText;
        final size = sizeStr != null ? int.tryParse(sizeStr) : null;
        
        // Get modified time
        final modifiedStr = prop.findElements('getlastmodified', namespace: 'DAV:').firstOrNull?.innerText;
        DateTime? modifiedAt;
        if (modifiedStr != null) {
          try {
            modifiedAt = HttpDate.parse(modifiedStr);
          } catch (_) {}
        }
        
        // Skip the base path itself
        final decodedHref = Uri.decodeComponent(href);
        if (decodedHref == basePath || decodedHref == '$basePath/') continue;
        
        // Extract relative path
        final name = displayName.isNotEmpty 
            ? displayName 
            : decodedHref.split('/').where((s) => s.isNotEmpty).lastOrNull ?? '';
        
        entries.add(StorageEntry(
          path: decodedHref,
          name: name,
          isDirectory: isDirectory,
          size: size,
          modifiedAt: modifiedAt,
        ));
      }
    } catch (e) {
      throw Exception('Failed to parse WebDAV response: $e');
    }
    
    return entries;
  }

  @override
  Future<Uint8List> read(String path) async {
    final fullPath = _joinPath(rootPath, path);
    
    try {
      final response = await _dio.get<List<int>>(
        _fullUrl(fullPath),
        options: Options(
          headers: _buildHeaders(),
          responseType: ResponseType.bytes,
        ),
      );
      
      return Uint8List.fromList(response.data ?? []);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('File not found: $path');
      }
      throw Exception('WebDAV read failed: ${e.message}');
    }
  }

  @override
  Future<WriteResult> write(String path, Uint8List data) async {
    final fullPath = _joinPath(rootPath, path);
    
    try {
      final response = await _dio.put(
        _fullUrl(fullPath),
        data: data,
        options: Options(
          headers: {
            ..._buildHeaders(),
            'Content-Type': 'application/octet-stream',
          },
        ),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204) {
        return WriteResult.success(path: path);
      } else {
        return WriteResult.failure('Write failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      return WriteResult.failure('WebDAV write failed: ${e.message}');
    }
  }

  @override
  Future<void> move(String from, String to) async {
    final fullFrom = _joinPath(rootPath, from);
    final fullTo = _joinPath(rootPath, to);
    
    try {
      await _dio.request(
        _fullUrl(fullFrom),
        options: Options(
          method: 'MOVE',
          headers: {
            ..._buildHeaders(),
            'Destination': _fullUrl(fullTo),
            'Overwrite': 'F',
          },
        ),
      );
    } on DioException catch (e) {
      throw Exception('WebDAV move failed: ${e.message}');
    }
  }

  @override
  Future<void> delete(String path) async {
    final fullPath = _joinPath(rootPath, path);
    
    try {
      await _dio.delete(
        _fullUrl(fullPath),
        options: Options(headers: _buildHeaders()),
      );
    } on DioException catch (e) {
      throw Exception('WebDAV delete failed: ${e.message}');
    }
  }

  @override
  Future<StorageMetadata> metadata(String path) async {
    final fullPath = _joinPath(rootPath, path);
    
    try {
      final response = await _dio.request(
        _fullUrl(fullPath),
        options: Options(
          method: 'PROPFIND',
          headers: {
            ..._buildHeaders(),
            'Depth': '0',
            'Content-Type': 'application/xml',
          },
        ),
        data: '''<?xml version="1.0"?>
<propfind xmlns="DAV:">
  <prop>
    <getcontenttype/>
    <getcontentlength/>
    <getlastmodified/>
    <getetag/>
  </prop>
</propfind>''',
      );

      final document = XmlDocument.parse(response.data.toString());
      final prop = document.findAllElements('prop', namespace: 'DAV:').firstOrNull;
      
      final contentType = prop?.findElements('getcontenttype', namespace: 'DAV:').firstOrNull?.innerText;
      final sizeStr = prop?.findElements('getcontentlength', namespace: 'DAV:').firstOrNull?.innerText;
      final modifiedStr = prop?.findElements('getlastmodified', namespace: 'DAV:').firstOrNull?.innerText;
      final etag = prop?.findElements('getetag', namespace: 'DAV:').firstOrNull?.innerText;
      
      DateTime? modifiedAt;
      if (modifiedStr != null) {
        try {
          modifiedAt = HttpDate.parse(modifiedStr);
        } catch (_) {}
      }
      
      return StorageMetadata(
        path: path,
        contentType: contentType,
        size: sizeStr != null ? int.tryParse(sizeStr) : null,
        modifiedAt: modifiedAt,
        etag: etag,
      );
    } on DioException catch (e) {
      throw Exception('WebDAV metadata failed: ${e.message}');
    }
  }

  Map<String, String> _buildHeaders() {
    final headers = <String, String>{};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    } else if (username != null && password != null) {
      final credentials = base64Encode(utf8.encode('$username:$password'));
      headers['Authorization'] = 'Basic $credentials';
    }
    return headers;
  }

  String _joinPath(String base, String path) {
    final cleanBase = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return '$cleanBase$cleanPath';
  }
}
