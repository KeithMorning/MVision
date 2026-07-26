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

/// State for the sources list.
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

    _db.insertSource(
      id: id,
      name: name,
      type: 'local',
      rootPath: dirPath,
    );
    _load();
  }

  void removeSource(String id) {
    _db.deleteSource(id);
    _load();
  }
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

/// Action to scan a source.
Future<void> scanSource(
  WidgetRef ref, {
  required String sourceId,
  required String rootPath,
}) async {
  final scanner = ref.read(scannerProvider);
  final scanState = ref.read(scanStateProvider.notifier);

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
      rootPath: rootPath,
    );
    scanState.state = ScanState(
      message: '扫描完成，更新了 $updated 个文档',
    );
    // Refresh documents list
    ref.read(documentsProvider.notifier).refresh();
  } catch (e) {
    scanState.state = ScanState(message: '扫描失败: $e');
  }
}

/// Initialize the database at app startup.
Future<DatabaseService> initDatabase() async {
  final appDir = await getApplicationSupportDirectory();
  final dbPath = p.join(appDir.path, 'mvision.db');
  return DatabaseService(dbPath);
}
