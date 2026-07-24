import 'package:knowledge_core/knowledge_core.dart';

/// Detects sync conflicts between local and remote versions.
class ConflictDetector {
  ConflictDetector._();

  /// Check if two file states represent a conflict.
  ///
  /// A conflict occurs when both local and remote have changed
  /// since the last successful sync.
  static bool isConflict({
    required String localHash,
    required String remoteHash,
    required String lastSyncedHash,
  }) {
    final localChanged = localHash != lastSyncedHash;
    final remoteChanged = remoteHash != lastSyncedHash;
    return localChanged && remoteChanged;
  }

  /// Create a conflict record from sync state.
  static SyncConflict createConflict({
    required String sourceId,
    required String path,
    required String localHash,
    required String remoteHash,
  }) {
    return SyncConflict(
      sourceId: sourceId,
      path: path,
      localHash: localHash,
      remoteHash: remoteHash,
      detectedAt: DateTime.now(),
    );
  }

  /// Generate a conflict copy filename.
  static String conflictCopyName(String originalPath, String deviceName) {
    final timestamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    final dir = originalPath.contains('/')
        ? originalPath.substring(0, originalPath.lastIndexOf('/'))
        : '';
    final filename = originalPath.split('/').last;
    final ext = filename.contains('.')
        ? filename.substring(filename.lastIndexOf('.'))
        : '';
    final basename = filename.contains('.')
        ? filename.substring(0, filename.lastIndexOf('.'))
        : filename;

    return '$dir/$basename.conflict-$deviceName-$timestamp$ext';
  }
}
