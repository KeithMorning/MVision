import 'package:knowledge_core/knowledge_core.dart';

/// Sync status for a file.
enum SyncStatus {
  /// File is in sync.
  synced,

  /// Local file has changed, needs upload.
  localModified,

  /// Remote file has changed, needs download.
  remoteModified,

  /// Both local and remote have changed, conflict.
  conflict,

  /// File exists only locally.
  localOnly,

  /// File exists only remotely.
  remoteOnly,

  /// File is being synced.
  syncing,

  /// Sync error occurred.
  error,
}

/// Sync state for a file.
class SyncState {
  final String sourceId;
  final String path;
  final String localHash;
  final String remoteHash;
  final String lastSyncedHash;
  final DateTime? lastSyncedAt;
  final SyncStatus status;

  const SyncState({
    required this.sourceId,
    required this.path,
    required this.localHash,
    required this.remoteHash,
    required this.lastSyncedHash,
    this.lastSyncedAt,
    required this.status,
  });

  /// Create a new sync state for a file that has never been synced.
  factory SyncState.initial({
    required String sourceId,
    required String path,
    required String localHash,
    required String remoteHash,
  }) {
    return SyncState(
      sourceId: sourceId,
      path: path,
      localHash: localHash,
      remoteHash: remoteHash,
      lastSyncedHash: '',
      status: _determineStatus(localHash, remoteHash, ''),
    );
  }

  /// Create a sync state from an existing synced state.
  factory SyncState.fromSynced({
    required String sourceId,
    required String path,
    required String currentLocalHash,
    required String currentRemoteHash,
    required String lastSyncedHash,
    DateTime? lastSyncedAt,
  }) {
    return SyncState(
      sourceId: sourceId,
      path: path,
      localHash: currentLocalHash,
      remoteHash: currentRemoteHash,
      lastSyncedHash: lastSyncedHash,
      lastSyncedAt: lastSyncedAt,
      status: _determineStatus(currentLocalHash, currentRemoteHash, lastSyncedHash),
    );
  }

  static SyncStatus _determineStatus(
    String localHash,
    String remoteHash,
    String lastSyncedHash,
  ) {
    final localChanged = localHash != lastSyncedHash;
    final remoteChanged = remoteHash != lastSyncedHash;

    if (localChanged && remoteChanged) {
      return SyncStatus.conflict;
    } else if (localChanged) {
      return SyncStatus.localModified;
    } else if (remoteChanged) {
      return SyncStatus.remoteModified;
    } else {
      return SyncStatus.synced;
    }
  }

  /// Check if this file needs to be uploaded.
  bool get needsUpload => status == SyncStatus.localModified;

  /// Check if this file needs to be downloaded.
  bool get needsDownload => status == SyncStatus.remoteModified;

  /// Check if this file has a conflict.
  bool get hasConflict => status == SyncStatus.conflict;

  /// Mark this file as synced.
  SyncState markSynced(String syncedHash) {
    return SyncState(
      sourceId: sourceId,
      path: path,
      localHash: syncedHash,
      remoteHash: syncedHash,
      lastSyncedHash: syncedHash,
      lastSyncedAt: DateTime.now(),
      status: SyncStatus.synced,
    );
  }

  /// Create a copy with updated values.
  SyncState copyWith({
    String? sourceId,
    String? path,
    String? localHash,
    String? remoteHash,
    String? lastSyncedHash,
    DateTime? lastSyncedAt,
    SyncStatus? status,
  }) {
    return SyncState(
      sourceId: sourceId ?? this.sourceId,
      path: path ?? this.path,
      localHash: localHash ?? this.localHash,
      remoteHash: remoteHash ?? this.remoteHash,
      lastSyncedHash: lastSyncedHash ?? this.lastSyncedHash,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      status: status ?? this.status,
    );
  }
}

/// Sync state machine.
///
/// Compares local and remote manifests to determine sync actions.
class SyncStateMachine {
  /// Compare local and remote file states and determine actions.
  static List<SyncAction> compare({
    required String sourceId,
    required Map<String, String> localHashes,
    required Map<String, String> remoteHashes,
    required Map<String, SyncState> previousStates,
  }) {
    final actions = <SyncAction>[];
    final allPaths = {...localHashes.keys, ...remoteHashes.keys};

    for (final path in allPaths) {
      final localHash = localHashes[path];
      final remoteHash = remoteHashes[path];
      final previousState = previousStates[path];

      if (localHash == null && remoteHash != null) {
        // File exists only remotely
        if (previousState == null) {
          actions.add(SyncAction.download(sourceId: sourceId, path: path));
        } else {
          // Was previously synced, now deleted locally
          actions.add(SyncAction.deleteRemote(sourceId: sourceId, path: path));
        }
      } else if (localHash != null && remoteHash == null) {
        // File exists only locally
        if (previousState == null) {
          actions.add(SyncAction.upload(sourceId: sourceId, path: path));
        } else {
          // Was previously synced, now deleted remotely
          actions.add(SyncAction.deleteLocal(sourceId: sourceId, path: path));
        }
      } else if (localHash != null && remoteHash != null) {
        // File exists on both sides
        final state = SyncState.fromSynced(
          sourceId: sourceId,
          path: path,
          currentLocalHash: localHash,
          currentRemoteHash: remoteHash,
          lastSyncedHash: previousState?.lastSyncedHash ?? '',
          lastSyncedAt: previousState?.lastSyncedAt,
        );

        switch (state.status) {
          case SyncStatus.synced:
            // No action needed
            break;
          case SyncStatus.localModified:
            actions.add(SyncAction.upload(sourceId: sourceId, path: path));
          case SyncStatus.remoteModified:
            actions.add(SyncAction.download(sourceId: sourceId, path: path));
          case SyncStatus.conflict:
            actions.add(SyncAction.conflict(sourceId: sourceId, path: path));
          default:
            break;
        }
      }
    }

    return actions;
  }
}

/// A sync action to perform.
sealed class SyncAction {
  final String sourceId;
  final String path;

  const SyncAction({required this.sourceId, required this.path});

  const factory SyncAction.upload({
    required String sourceId,
    required String path,
  }) = UploadAction;

  const factory SyncAction.download({
    required String sourceId,
    required String path,
  }) = DownloadAction;

  const factory SyncAction.conflict({
    required String sourceId,
    required String path,
  }) = ConflictAction;

  const factory SyncAction.deleteLocal({
    required String sourceId,
    required String path,
  }) = DeleteLocalAction;

  const factory SyncAction.deleteRemote({
    required String sourceId,
    required String path,
  }) = DeleteRemoteAction;
}

final class UploadAction extends SyncAction {
  const UploadAction({required super.sourceId, required super.path});
}

final class DownloadAction extends SyncAction {
  const DownloadAction({required super.sourceId, required super.path});
}

final class ConflictAction extends SyncAction {
  const ConflictAction({required super.sourceId, required super.path});
}

final class DeleteLocalAction extends SyncAction {
  const DeleteLocalAction({required super.sourceId, required super.path});
}

final class DeleteRemoteAction extends SyncAction {
  const DeleteRemoteAction({required super.sourceId, required super.path});
}
