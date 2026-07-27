import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:knowledge_core/knowledge_core.dart';
import 'baidu_oauth.dart';

/// Baidu Netdisk storage connector.
///
/// Implements FR-SOURCE-003: Baidu Netdisk access via xpan API.
/// Supports list, download, upload, move, delete operations.
class BaiduConnector implements StorageConnector {
  final BaiduOAuth oauth;
  final Dio _dio;
  final String rootPath;

  static const _panApi = 'https://pan.baidu.com/rest/2.0/xpan';
  static const _pcsApi = 'https://d.pcs.baidu.com/rest/2.0/pcs';

  BaiduConnector({
    required this.oauth,
    this.rootPath = '/apps/mvision',
    Dio? dio,
  }) : _dio = dio ?? Dio();

  @override
  String get sourceId => 'baidu:${oauth.userId ?? "default"}';

  Future<String> _token() async {
    final token = await oauth.getValidToken();
    if (token == null) throw Exception('Not authenticated. Please login to Baidu first.');
    return token;
  }

  String _fullPath(String path) {
    if (path.startsWith('/')) return path;
    return '$rootPath/$path';
  }

  @override
  Future<ConnectionResult> connect() async {
    try {
      final token = await _token();
      // Test connection by getting user info
      final response = await _dio.get(
        '$_panApi/nas',
        queryParameters: {
          'method': 'uinfo',
          'access_token': token,
        },
      );

      if (response.statusCode == 200 && response.data['errno'] == 0) {
        return ConnectionResult.success();
      } else {
        final errMsg = response.data['errmsg'] ?? 'Unknown error';
        return ConnectionResult.failure('Baidu API error: $errMsg');
      }
    } catch (e) {
      return ConnectionResult.failure(e.toString());
    }
  }

  @override
  Future<List<StorageEntry>> list(String path) async {
    final token = await _token();
    final fullPath = _fullPath(path);

    final response = await _dio.get(
      '$_panApi/file',
      queryParameters: {
        'method': 'list',
        'access_token': token,
        'dir': fullPath,
        'order': 'name',
        'desc': 0,
        'limit': '0-1000',
        'folder': 0,
      },
    );

    final data = response.data;
    if (data['errno'] != 0) {
      throw Exception('Baidu list failed: errno=${data['errno']}');
    }

    final list = data['list'] as List? ?? [];
    return list.map((item) {
      final isDir = (item['isdir'] as int? ?? 0) == 1;
      final serverPath = item['path'] as String? ?? '';
      final name = item['server_filename'] as String? ?? '';
      final size = item['size'] as int?;
      final mtime = item['server_mtime'] as int?;

      return StorageEntry(
        path: serverPath,
        name: name,
        isDirectory: isDir,
        size: size,
        modifiedAt: mtime != null
            ? DateTime.fromMillisecondsSinceEpoch(mtime * 1000)
            : null,
      );
    }).toList();
  }

  @override
  Future<Uint8List> read(String path) async {
    final token = await _token();
    final fullPath = _fullPath(path);

    // Step 1: Get download link
    final metaResponse = await _dio.get(
      '$_panApi/multimedia',
      queryParameters: {
        'method': 'filemetas',
        'access_token': token,
        'target': jsonEncode([fullPath]),
        'dlink': 1,
      },
    );

    final metaData = metaResponse.data;
    if (metaData['errno'] != 0) {
      throw Exception('Baidu filemetas failed: errno=${metaData['errno']}');
    }

    final infoList = metaData['info'] as List? ?? [];
    if (infoList.isEmpty) {
      throw Exception('File not found: $path');
    }

    final dlink = infoList[0]['dlink'] as String?;
    if (dlink == null) {
      throw Exception('No download link available for: $path');
    }

    // Step 2: Download file content
    final downloadResponse = await _dio.get<List<int>>(
      dlink,
      queryParameters: {'access_token': token},
      options: Options(
        responseType: ResponseType.bytes,
        followRedirects: true,
        headers: {'User-Agent': 'pan.baidu.com'},
      ),
    );

    return Uint8List.fromList(downloadResponse.data ?? []);
  }

  @override
  Future<WriteResult> write(String path, Uint8List data) async {
    final token = await _token();
    final fullPath = _fullPath(path);

    try {
      // Baidu upload is a 3-step process:
      // 1. Pre-create
      final preCreateResponse = await _dio.post(
        '$_panApi/file',
        queryParameters: {
          'method': 'precreate',
          'access_token': token,
        },
        data: {
          'path': fullPath,
          'size': data.length,
          'isdir': 0,
          'autoinit': 1,
          'rtype': 3, // Overwrite if exists
          'block_list': jsonEncode([_md5(data)]),
        },
      );

      final preData = preCreateResponse.data;
      if (preData['errno'] != 0) {
        return WriteResult.failure('Pre-create failed: errno=${preData['errno']}');
      }

      final uploadId = preData['uploadid'] as String;

      // 2. Upload slice
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(data, filename: 'file'),
      });

      final uploadResponse = await _dio.post(
        '$_pcsApi/superfile2',
        queryParameters: {
          'method': 'upload',
          'access_token': token,
          'type': 'tmpfile',
          'path': fullPath,
          'uploadid': uploadId,
          'partseq': 0,
        },
        data: formData,
      );

      final uploadData = uploadResponse.data;
      if (uploadData['error_code'] != null) {
        return WriteResult.failure('Upload failed: ${uploadData['error_msg']}');
      }

      final sliceMd5 = uploadData['md5'] as String;

      // 3. Create (combine slices)
      final createResponse = await _dio.post(
        '$_panApi/file',
        queryParameters: {
          'method': 'create',
          'access_token': token,
        },
        data: {
          'path': fullPath,
          'size': data.length,
          'isdir': 0,
          'uploadid': uploadId,
          'rtype': 3,
          'block_list': jsonEncode([sliceMd5]),
        },
      );

      final createData = createResponse.data;
      if (createData['errno'] != 0) {
        return WriteResult.failure('Create failed: errno=${createData['errno']}');
      }

      return WriteResult.success(path: path);
    } on DioException catch (e) {
      return WriteResult.failure('Baidu write failed: ${e.message}');
    }
  }

  @override
  Future<void> move(String from, String to) async {
    final token = await _token();
    final fullFrom = _fullPath(from);
    final fullTo = _fullPath(to);

    final response = await _dio.post(
      '$_panApi/file',
      queryParameters: {
        'method': 'filemanager',
        'access_token': token,
        'opera': 'move',
      },
      data: {
        'async': 0,
        'filelist': jsonEncode([
          {'path': fullFrom, 'dest': _parentPath(fullTo), 'newname': _fileName(fullTo)}
        ]),
      },
    );

    final data = response.data;
    if (data['errno'] != 0) {
      throw Exception('Baidu move failed: errno=${data['errno']}');
    }
  }

  @override
  Future<void> delete(String path) async {
    final token = await _token();
    final fullPath = _fullPath(path);

    final response = await _dio.post(
      '$_panApi/file',
      queryParameters: {
        'method': 'delete',
        'access_token': token,
      },
      data: {
        'filelist': jsonEncode([fullPath]),
      },
    );

    final data = response.data;
    if (data['errno'] != 0) {
      throw Exception('Baidu delete failed: errno=${data['errno']}');
    }
  }

  @override
  Future<StorageMetadata> metadata(String path) async {
    final token = await _token();
    final fullPath = _fullPath(path);

    final response = await _dio.get(
      '$_panApi/multimedia',
      queryParameters: {
        'method': 'filemetas',
        'access_token': token,
        'target': jsonEncode([fullPath]),
      },
    );

    final data = response.data;
    if (data['errno'] != 0) {
      throw Exception('Baidu metadata failed: errno=${data['errno']}');
    }

    final infoList = data['info'] as List? ?? [];
    if (infoList.isEmpty) {
      throw Exception('File not found: $path');
    }

    final info = infoList[0];
    final mtime = info['server_mtime'] as int?;

    return StorageMetadata(
      path: info['path'] as String? ?? path,
      size: info['size'] as int?,
      modifiedAt: mtime != null
          ? DateTime.fromMillisecondsSinceEpoch(mtime * 1000)
          : null,
      etag: info['md5'] as String?,
    );
  }

  /// Create a directory on Baidu Netdisk.
  Future<void> mkdir(String path) async {
    final token = await _token();
    final fullPath = _fullPath(path);

    await _dio.post(
      '$_panApi/file',
      queryParameters: {
        'method': 'create',
        'access_token': token,
      },
      data: {
        'path': fullPath,
        'isdir': 1,
        'size': 0,
      },
    );
  }

  // --- Helpers ---

  String _parentPath(String path) {
    final idx = path.lastIndexOf('/');
    return idx > 0 ? path.substring(0, idx) : '/';
  }

  String _fileName(String path) {
    final idx = path.lastIndexOf('/');
    return idx >= 0 ? path.substring(idx + 1) : path;
  }

  String _md5(Uint8List data) {
    return md5.convert(data).toString();
  }
}
