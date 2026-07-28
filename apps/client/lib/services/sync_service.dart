import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:crypto/crypto.dart';

import 'database_service.dart';

/// Sync status state.
class SyncState {
  final bool isSyncing;
  final String? message;
  final int progress; // 0-100
  final int totalFiles;
  final int syncedFiles;
  final DateTime? lastSyncAt;
  final String? error;

  const SyncState({
    this.isSyncing = false,
    this.message,
    this.progress = 0,
    this.totalFiles = 0,
    this.syncedFiles = 0,
    this.lastSyncAt,
    this.error,
  });

  SyncState copyWith({
    bool? isSyncing,
    String? message,
    int? progress,
    int? totalFiles,
    int? syncedFiles,
    DateTime? lastSyncAt,
    String? error,
  }) {
    return SyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      message: message ?? this.message,
      progress: progress ?? this.progress,
      totalFiles: totalFiles ?? this.totalFiles,
      syncedFiles: syncedFiles ?? this.syncedFiles,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      error: error,
    );
  }
}

/// Sync state notifier.
class SyncNotifier extends StateNotifier<SyncState> {
  SyncNotifier() : super(const SyncState());

  void setSyncing(bool syncing, {String? message}) {
    state = state.copyWith(isSyncing: syncing, message: message, error: null);
  }

  void setProgress(int synced, int total, {String? message}) {
    final progress = total > 0 ? (synced * 100 / total).round() : 0;
    state = state.copyWith(
      syncedFiles: synced,
      totalFiles: total,
      progress: progress,
      message: message,
    );
  }

  void setComplete() {
    state = state.copyWith(
      isSyncing: false,
      progress: 100,
      lastSyncAt: DateTime.now(),
      message: '同步完成',
    );
  }

  void setError(String error) {
    state = state.copyWith(
      isSyncing: false,
      error: error,
      message: null,
    );
  }
}

/// Sync state provider.
final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  return SyncNotifier();
});

/// Baidu sync configuration.
class BaiduSyncConfig {
  final String appKey;
  final String secretKey;
  final String? accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;

  const BaiduSyncConfig({
    required this.appKey,
    required this.secretKey,
    this.accessToken,
    this.refreshToken,
    this.expiresAt,
  });

  bool get isAuthenticated => accessToken != null && 
      expiresAt != null && 
      DateTime.now().isBefore(expiresAt!);

  Map<String, dynamic> toJson() => {
    'appKey': appKey,
    'secretKey': secretKey,
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresAt': expiresAt?.toIso8601String(),
  };

  factory BaiduSyncConfig.fromJson(Map<String, dynamic> json) {
    return BaiduSyncConfig(
      appKey: json['appKey'] as String? ?? '',
      secretKey: json['secretKey'] as String? ?? '',
      accessToken: json['accessToken'] as String?,
      refreshToken: json['refreshToken'] as String?,
      expiresAt: json['expiresAt'] != null 
          ? DateTime.parse(json['expiresAt'] as String) 
          : null,
    );
  }
}

/// Service for syncing vault with Baidu Netdisk.
class BaiduSyncService {
  final DatabaseService db;
  final String vaultPath;
  final BaiduSyncConfig config;

  BaiduSyncService({
    required this.db,
    required this.vaultPath,
    required this.config,
  });

  /// Calculate MD5 hash of file content.
  String _md5(List<int> bytes) {
    return md5.convert(bytes).toString();
  }

  /// Get relative path from vault root.
  String _relativePath(String fullPath) {
    return p.relative(fullPath, from: vaultPath);
  }

  /// List all markdown files in vault.
  List<File> _listVaultFiles() {
    final dir = Directory(vaultPath);
    if (!dir.existsSync()) return [];

    return dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.md'))
        .where((f) => !f.path.contains('${p.separator}.')) // Skip hidden
        .toList();
  }

  /// Sync local vault to Baidu (upload changes).
  Future<void> syncToBaidu(
    void Function(int synced, int total, String message) onProgress,
  ) async {
    if (!config.isAuthenticated) {
      throw Exception('未登录百度网盘');
    }

    final files = _listVaultFiles();
    int synced = 0;

    for (final file in files) {
      final relativePath = _relativePath(file.path);
      onProgress(synced, files.length, '上传: $relativePath');

      try {
        // Check if file needs upload (compare hashes)
        final localHash = _md5(await file.readAsBytes());
        final syncState = db.getSyncState('baidu', relativePath);
        
        if (syncState != null && syncState['local_hash'] == localHash) {
          // File unchanged, skip
          synced++;
          continue;
        }

        // Upload file
        await _uploadFile(file, relativePath, localHash);
        
        // Update sync state
        db.upsertSyncState(
          sourceId: 'baidu',
          path: relativePath,
          localHash: localHash,
          remoteHash: localHash,
          lastSyncedHash: localHash,
          lastSyncedAt: DateTime.now().millisecondsSinceEpoch,
          status: 'synced',
        );

        synced++;
      } catch (e) {
        // Log error but continue with other files
        // ignore: avoid_print
        print('Sync error for $relativePath: $e');
      }
    }

    onProgress(files.length, files.length, '同步完成');
  }

  /// Upload a single file to Baidu.
  Future<void> _uploadFile(File file, String relativePath, String hash) async {
    // This would use the BaiduConnector.write() method
    // For now, this is a placeholder
    throw UnimplementedError('Upload not yet implemented');
  }

  /// Download changes from Baidu to local vault.
  Future<void> syncFromBaidu(
    void Function(int synced, int total, String message) onProgress,
  ) async {
    if (!config.isAuthenticated) {
      throw Exception('未登录百度网盘');
    }

    // This would list remote files and download changes
    throw UnimplementedError('Download not yet implemented');
  }
}
