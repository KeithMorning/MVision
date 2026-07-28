import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../services/database_service.dart';
import '../services/scanner_service.dart';

/// Provides the database service instance.
final databaseProvider = Provider<DatabaseService>((ref) {
  throw UnimplementedError('Must be overridden at app startup');
});

/// Provides the scanner service.
final scannerProvider = Provider<ScannerService>((ref) {
  final db = ref.watch(databaseProvider);
  return ScannerService(db: db);
});

// ============================================================
// Vault Model (single vault, like Obsidian)
// ============================================================

/// Vault configuration.
class VaultConfig {
  final String name;
  final String rootPath;
  final String dailyNotesFolder;
  final String templatesFolder;
  final int? lastOpenedAt;

  const VaultConfig({
    required this.name,
    required this.rootPath,
    this.dailyNotesFolder = 'daily',
    this.templatesFolder = 'templates',
    this.lastOpenedAt,
  });

  factory VaultConfig.fromRow(Map<String, dynamic> row) {
    return VaultConfig(
      name: row['name'] as String,
      rootPath: row['root_path'] as String,
      dailyNotesFolder: row['daily_notes_folder'] as String? ?? 'daily',
      templatesFolder: row['templates_folder'] as String? ?? 'templates',
      lastOpenedAt: row['last_opened_at'] as int?,
    );
  }

  bool get exists => Directory(rootPath).existsSync();
}

/// Vault state provider.
final vaultProvider = StateNotifierProvider<VaultNotifier, VaultConfig?>((ref) {
  return VaultNotifier(ref.watch(databaseProvider));
});

class VaultNotifier extends StateNotifier<VaultConfig?> {
  final DatabaseService _db;

  VaultNotifier(this._db) : super(null) {
    _load();
  }

  void _load() {
    final row = _db.getVaultConfig();
    if (row != null) {
      state = VaultConfig.fromRow(row);
      _db.updateVaultLastOpened();
    }
  }

  /// Open or create a vault at the given directory.
  void openVault(String dirPath, {String? name}) {
    final vaultName = name ?? p.basename(dirPath);
    _db.setVaultConfig(name: vaultName, rootPath: dirPath);

    // Also register as a source for backward compat with scanner
    final sourceId = 'local:$dirPath';
    _db.insertSource(
      id: sourceId,
      name: vaultName,
      type: 'local',
      rootPath: dirPath,
    );

    _load();
  }

  void closeVault() {
    state = null;
  }
}

/// Whether a vault is currently open.
final hasVaultProvider = Provider<bool>((ref) {
  return ref.watch(vaultProvider) != null;
});

// ============================================================
// File Tree (for File Explorer sidebar)
// ============================================================

/// A node in the file tree.
class FileTreeNode {
  final String name;
  final String relativePath;
  final bool isDirectory;
  final List<FileTreeNode> children;
  final int? size;
  final DateTime? modifiedAt;

  const FileTreeNode({
    required this.name,
    required this.relativePath,
    required this.isDirectory,
    this.children = const [],
    this.size,
    this.modifiedAt,
  });

  FileTreeNode copyWithChildren(List<FileTreeNode> newChildren) {
    return FileTreeNode(
      name: name,
      relativePath: relativePath,
      isDirectory: isDirectory,
      children: newChildren,
      size: size,
      modifiedAt: modifiedAt,
    );
  }
}

/// File tree provider - builds tree from vault root.
final fileTreeProvider = StateNotifierProvider<FileTreeNotifier, List<FileTreeNode>>((ref) {
  final vault = ref.watch(vaultProvider);
  return FileTreeNotifier(vault?.rootPath);
});

class FileTreeNotifier extends StateNotifier<List<FileTreeNode>> {
  final String? _rootPath;

  FileTreeNotifier(this._rootPath) : super([]) {
    if (_rootPath != null) refresh();
  }

  /// Directories to skip.
  static const _ignoredDirs = {
    '.git', '.svn', '.hg', 'node_modules', '.dart_tool',
    '.build', '.mvision', '__pycache__', '.Trash', '.obsidian',
  };

  void refresh() {
    if (_rootPath == null) {
      state = [];
      return;
    }
    final root = Directory(_rootPath);
    if (!root.existsSync()) {
      state = [];
      return;
    }
    state = _buildTree(root, '');
  }

  List<FileTreeNode> _buildTree(Directory dir, String relativeBase) {
    final nodes = <FileTreeNode>[];
    try {
      final entities = dir.listSync(followLinks: false);
      for (final entity in entities) {
        final name = p.basename(entity.path);
        if (name.startsWith('.') && _ignoredDirs.contains(name)) continue;
        if (_ignoredDirs.contains(name)) continue;

        final relPath = relativeBase.isEmpty ? name : '$relativeBase/$name';

        if (entity is Directory) {
          nodes.add(FileTreeNode(
            name: name,
            relativePath: relPath,
            isDirectory: true,
            children: _buildTree(entity, relPath),
          ));
        } else if (entity is File) {
          final stat = entity.statSync();
          nodes.add(FileTreeNode(
            name: name,
            relativePath: relPath,
            isDirectory: false,
            size: stat.size,
            modifiedAt: stat.modified,
          ));
        }
      }
    } catch (_) {}

    // Sort: directories first, then alphabetical
    nodes.sort((a, b) {
      if (a.isDirectory && !b.isDirectory) return -1;
      if (!a.isDirectory && b.isDirectory) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return nodes;
  }
}

// ============================================================
// Documents (kept for backward compat, vault-aware)
// ============================================================

/// Represents an indexed document.
class DocumentItem {
  final String id;
  final String sourceId;
  final String path;
  final String title;
  final int kind;
  final int size;
  final int modifiedAt;

  const DocumentItem({
    required this.id,
    required this.sourceId,
    required this.path,
    required this.title,
    required this.kind,
    required this.size,
    required this.modifiedAt,
  });

  factory DocumentItem.fromRow(Map<String, dynamic> row) {
    return DocumentItem(
      id: row['id'] as String,
      sourceId: row['source_id'] as String,
      path: row['path'] as String,
      title: row['title'] as String,
      kind: row['kind'] as int,
      size: row['size'] as int,
      modifiedAt: row['modified_at'] as int,
    );
  }

  DateTime get modifiedDate =>
      DateTime.fromMillisecondsSinceEpoch(modifiedAt);
}

/// State for the documents list.
final documentsProvider =
    StateNotifierProvider<DocumentsNotifier, List<DocumentItem>>((ref) {
  return DocumentsNotifier(ref.watch(databaseProvider));
});

class DocumentsNotifier extends StateNotifier<List<DocumentItem>> {
  final DatabaseService _db;

  DocumentsNotifier(this._db) : super([]) {
    _load();
  }

  void _load({String? sourceId}) {
    final rows = _db.getDocuments(sourceId: sourceId);
    state = rows.map((r) => DocumentItem.fromRow(r)).toList();
  }

  void refresh({String? sourceId}) => _load(sourceId: sourceId);
}

// ============================================================
// Scan state
// ============================================================

/// Scan state.
class ScanState {
  final bool isScanning;
  final int processed;
  final int total;
  final String? message;

  const ScanState({
    this.isScanning = false,
    this.processed = 0,
    this.total = 0,
    this.message,
  });
}

final scanStateProvider = StateProvider<ScanState>((ref) => const ScanState());

/// Action to scan the current vault.
Future<void> scanVault(WidgetRef ref) async {
  final vault = ref.read(vaultProvider);
  if (vault == null) return;

  final scanner = ref.read(scannerProvider);
  final scanState = ref.read(scanStateProvider.notifier);
  final sourceId = 'local:${vault.rootPath}';

  scanState.state = const ScanState(isScanning: true, message: '正在扫描...');

  scanner.onProgress = (processed, total) {
    scanState.state = ScanState(
      isScanning: true,
      processed: processed,
      total: total,
      message: '正在扫描 $processed/$total',
    );
  };

  try {
    final updated = await scanner.scanSource(
      sourceId: sourceId,
      rootPath: vault.rootPath,
    );
    scanState.state = ScanState(
      message: '扫描完成，更新了 $updated 个文档',
    );
    ref.read(documentsProvider.notifier).refresh();
    ref.read(fileTreeProvider.notifier).refresh();
  } catch (e) {
    scanState.state = ScanState(message: '扫描失败: $e');
  }
}

// ============================================================
// Tags
// ============================================================

final tagsProvider = StateNotifierProvider<TagsNotifier, List<Map<String, dynamic>>>((ref) {
  return TagsNotifier(ref.watch(databaseProvider));
});

class TagsNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  final DatabaseService _db;

  TagsNotifier(this._db) : super([]) {
    refresh();
  }

  void refresh() {
    state = _db.getAllTags();
  }
}

// ============================================================
// Starred
// ============================================================

final starredProvider = StateNotifierProvider<StarredNotifier, List<Map<String, dynamic>>>((ref) {
  return StarredNotifier(ref.watch(databaseProvider));
});

class StarredNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  final DatabaseService _db;

  StarredNotifier(this._db) : super([]) {
    refresh();
  }

  void refresh() {
    state = _db.getStarredDocuments();
  }

  void toggle(String docId) {
    _db.toggleStar(docId);
    refresh();
  }
}

// ============================================================
// Recent files
// ============================================================

final recentFilesProvider = StateNotifierProvider<RecentFilesNotifier, List<Map<String, dynamic>>>((ref) {
  return RecentFilesNotifier(ref.watch(databaseProvider));
});

class RecentFilesNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  final DatabaseService _db;

  RecentFilesNotifier(this._db) : super([]) {
    refresh();
  }

  void refresh() {
    state = _db.getRecentFiles();
  }

  void recordOpen(String docId) {
    _db.recordFileOpened(docId);
    refresh();
  }
}

// ============================================================
// Legacy sources (kept for backward compat)
// ============================================================

/// Represents a connected knowledge source.
class KnowledgeSource {
  final String id;
  final String name;
  final String type;
  final String rootPath;
  final int? lastScannedAt;

  const KnowledgeSource({
    required this.id,
    required this.name,
    required this.type,
    required this.rootPath,
    this.lastScannedAt,
  });

  factory KnowledgeSource.fromRow(Map<String, dynamic> row) {
    return KnowledgeSource(
      id: row['id'] as String,
      name: row['name'] as String,
      type: row['type'] as String,
      rootPath: row['root_path'] as String,
      lastScannedAt: row['last_scanned_at'] as int?,
    );
  }
}

final sourcesProvider =
    StateNotifierProvider<SourcesNotifier, List<KnowledgeSource>>((ref) {
  return SourcesNotifier(ref.watch(databaseProvider));
});

class SourcesNotifier extends StateNotifier<List<KnowledgeSource>> {
  final DatabaseService _db;

  SourcesNotifier(this._db) : super([]) {
    _load();
  }

  void _load() {
    final rows = _db.getSources();
    state = rows.map((r) => KnowledgeSource.fromRow(r)).toList();
  }

  Future<void> addLocalSource(String dirPath) async {
    final name = p.basename(dirPath);
    final id = 'local:$dirPath';
    _db.insertSource(id: id, name: name, type: 'local', rootPath: dirPath);
    _load();
  }

  void removeSource(String id) {
    _db.deleteSource(id);
    _load();
  }
}

/// Initialize the database at app startup.
Future<DatabaseService> initDatabase() async {
  final appDir = await getApplicationSupportDirectory();
  final dbPath = p.join(appDir.path, 'mvision.db');
  return DatabaseService(dbPath);
}
