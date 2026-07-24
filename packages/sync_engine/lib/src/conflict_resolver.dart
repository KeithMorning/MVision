import 'dart:typed_data';
import 'package:knowledge_core/knowledge_core.dart';
import 'conflict_detector.dart';

/// Result of conflict resolution.
enum ConflictResolution {
  /// Keep local version.
  keepLocal,

  /// Keep remote version.
  keepRemote,

  /// Keep both (remote as conflict copy).
  keepBoth,

  /// User resolved manually.
  manual,
}

/// Resolves sync conflicts.
class ConflictResolver {
  ConflictResolver._();

  /// Resolve a conflict by keeping local version and saving remote as conflict copy.
  static ConflictResolutionResult keepLocalSaveRemoteCopy({
    required String sourceId,
    required String path,
    required Uint8List localContent,
    required Uint8List remoteContent,
    required String deviceName,
  }) {
    final conflictPath = ConflictDetector.conflictCopyName(path, deviceName);

    return ConflictResolutionResult(
      resolution: ConflictResolution.keepBoth,
      localContent: localContent,
      conflictCopyPath: conflictPath,
      conflictCopyContent: remoteContent,
    );
  }

  /// Resolve a conflict by keeping remote version.
  static ConflictResolutionResult keepRemote({
    required String sourceId,
    required String path,
    required Uint8List remoteContent,
  }) {
    return ConflictResolutionResult(
      resolution: ConflictResolution.keepRemote,
      localContent: remoteContent,
    );
  }
}

/// Result of conflict resolution.
class ConflictResolutionResult {
  final ConflictResolution resolution;
  final Uint8List localContent;
  final String? conflictCopyPath;
  final Uint8List? conflictCopyContent;

  const ConflictResolutionResult({
    required this.resolution,
    required this.localContent,
    this.conflictCopyPath,
    this.conflictCopyContent,
  });
}
