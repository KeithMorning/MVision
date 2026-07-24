import 'dart:io';
import 'dart:typed_data';
import 'package:knowledge_core/knowledge_core.dart';
import 'package:platform_api/platform_api.dart';

/// Local directory storage connector.
///
/// Implements StorageConnector for local file system access.
/// Does not take ownership of the directory.
class LocalConnector implements StorageConnector {
  final String rootPath;
  final FileAccess fileAccess;

  LocalConnector({
    required this.rootPath,
    required this.fileAccess,
  });

  @override
  String get sourceId => 'local:$rootPath';

  @override
  Future<ConnectionResult> connect() async {
    try {
      final dir = Directory(rootPath);
      if (!await dir.exists()) {
        return ConnectionResult.failure('Directory does not exist: $rootPath');
      }
      return ConnectionResult.success();
    } catch (e) {
      return ConnectionResult.failure(e.toString());
    }
  }

  @override
  Future<List<StorageEntry>> list(String path) async {
    final fullPath = _resolvePath(path);
    final dir = Directory(fullPath);

    if (!await dir.exists()) {
      throw Exception('Directory does not exist: $path');
    }

    final entries = <StorageEntry>[];
    await for (final entity in dir.list()) {
      final stat = await entity.stat();
      entries.add(StorageEntry(
        path: _relativePath(entity.path),
        name: entity.path.split(Platform.pathSeparator).last,
        isDirectory: entity is Directory,
        size: stat.size,
        modifiedAt: stat.modified,
      ));
    }

    return entries;
  }

  @override
  Future<Uint8List> read(String path) async {
    final fullPath = _resolvePath(path);
    final file = File(fullPath);
    return file.readAsBytes();
  }

  @override
  Future<WriteResult> write(String path, Uint8List data) async {
    try {
      final fullPath = _resolvePath(path);
      final file = File(fullPath);

      // Ensure parent directory exists
      await file.parent.create(recursive: true);

      // Write to temporary file first, then rename (atomic)
      final tempFile = File('$fullPath.tmp');
      await tempFile.writeAsBytes(data);
      await tempFile.rename(fullPath);

      return WriteResult.success(path: path);
    } catch (e) {
      return WriteResult.failure(e.toString());
    }
  }

  @override
  Future<void> move(String from, String to) async {
    final fromPath = _resolvePath(from);
    final toPath = _resolvePath(to);

    // Ensure target directory exists
    await File(toPath).parent.create(recursive: true);

    await File(fromPath).rename(toPath);
  }

  @override
  Future<void> delete(String path) async {
    final fullPath = _resolvePath(path);
    final file = File(fullPath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<StorageMetadata> metadata(String path) async {
    final fullPath = _resolvePath(path);
    final stat = await FileStat.stat(fullPath);

    return StorageMetadata(
      path: path,
      size: stat.size,
      modifiedAt: stat.modified,
    );
  }

  String _resolvePath(String relativePath) {
    // Prevent path traversal
    if (relativePath.contains('..')) {
      throw ArgumentError('Path traversal detected: $relativePath');
    }
    return '$rootPath${Platform.pathSeparator}$relativePath';
  }

  String _relativePath(String fullPath) {
    return fullPath.replaceFirst('$rootPath${Platform.pathSeparator}', '');
  }
}
