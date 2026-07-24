import 'dart:typed_data';

/// Result of a connection attempt.
class ConnectionResult {
  final bool success;
  final String? errorMessage;
  final DateTime connectedAt;

  const ConnectionResult({
    required this.success,
    this.errorMessage,
    required this.connectedAt,
  });

  const ConnectionResult.success({DateTime? connectedAt})
      : success = true,
        errorMessage = null,
        connectedAt = connectedAt ?? DateTime.now();

  const ConnectionResult.failure(this.errorMessage, {DateTime? connectedAt})
      : success = false,
        connectedAt = connectedAt ?? DateTime.now();
}

/// An entry in a storage listing.
class StorageEntry {
  final String path;
  final String name;
  final bool isDirectory;
  final int? size;
  final DateTime? modifiedAt;

  const StorageEntry({
    required this.path,
    required this.name,
    required this.isDirectory,
    this.size,
    this.modifiedAt,
  });
}

/// Metadata about a stored item.
class StorageMetadata {
  final String path;
  final String? contentType;
  final int? size;
  final DateTime? modifiedAt;
  final String? etag;

  const StorageMetadata({
    required this.path,
    this.contentType,
    this.size,
    this.modifiedAt,
    this.etag,
  });
}

/// Result of a write operation.
class WriteResult {
  final bool success;
  final String? path;
  final String? errorMessage;
  final DateTime writtenAt;

  const WriteResult({
    required this.success,
    this.path,
    this.errorMessage,
    required this.writtenAt,
  });

  const WriteResult.success({String? path, DateTime? writtenAt})
      : success = true,
        path = path,
        errorMessage = null,
        writtenAt = writtenAt ?? DateTime.now();

  const WriteResult.failure(this.errorMessage, {DateTime? writtenAt})
      : success = false,
        path = null,
        writtenAt = writtenAt ?? DateTime.now();
}

/// Abstract interface for all storage connectors.
///
/// All data sources (local directory, Baidu Netdisk, WebDAV, etc.) must
/// implement this interface. UI and Wiki engine must not depend on
/// vendor-specific SDKs directly.
///
/// See FR-SOURCE-001 in mvision-development-requirements.md
abstract interface class StorageConnector {
  /// Unique identifier for this source instance.
  String get sourceId;

  /// Connect to the storage source.
  Future<ConnectionResult> connect();

  /// List entries at [path].
  Future<List<StorageEntry>> list(String path);

  /// Read file content at [path].
  Future<Uint8List> read(String path);

  /// Write [data] to [path].
  Future<WriteResult> write(String path, Uint8List data);

  /// Move file from [from] to [to].
  Future<void> move(String from, String to);

  /// Delete file at [path].
  Future<void> delete(String path);

  /// Get metadata for [path].
  Future<StorageMetadata> metadata(String path);
}
