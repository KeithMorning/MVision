import 'package:freezed_annotation/freezed_annotation.dart';

part 'sync_conflict.freezed.dart';
part 'sync_conflict.g.dart';

/// A sync conflict between local and remote versions.
@freezed
class SyncConflict with _$SyncConflict {
  const factory SyncConflict({
    /// ID of the source.
    required String sourceId,

    /// Path of the conflicting file.
    required String path,

    /// Hash of local version.
    required String localHash,

    /// Hash of remote version.
    required String remoteHash,

    /// When the conflict was detected.
    required DateTime detectedAt,
  }) = _SyncConflict;

  factory SyncConflict.fromJson(Map<String, dynamic> json) =>
      _$SyncConflictFromJson(json);
}
