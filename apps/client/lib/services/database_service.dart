import 'package:sqlite3/sqlite3.dart';

/// Local SQLite database for MVision.
///
/// Stores derived data only. Original Markdown files remain the single
/// source of truth. Deleting this database should allow full rebuild
/// from source files.
class DatabaseService {
  late final Database _db;

  DatabaseService(String dbPath) {
    _db = sqlite3.open(dbPath);
    _initialize();
  }

  void _initialize() {
    _db.execute('PRAGMA journal_mode = WAL');
    _db.execute('PRAGMA foreign_keys = ON');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS sources (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'local',
        root_path TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        last_scanned_at INTEGER
      )
    ''');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS documents (
        id TEXT PRIMARY KEY,
        source_id TEXT NOT NULL,
        path TEXT NOT NULL,
        title TEXT NOT NULL,
        kind INTEGER NOT NULL DEFAULT 0,
        content_hash TEXT NOT NULL,
        size INTEGER NOT NULL DEFAULT 0,
        modified_at INTEGER NOT NULL,
        is_available_offline INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (source_id) REFERENCES sources(id) ON DELETE CASCADE
      )
    ''');

    _db.execute('''
      CREATE INDEX IF NOT EXISTS idx_documents_source
        ON documents(source_id)
    ''');

    _db.execute('''
      CREATE INDEX IF NOT EXISTS idx_documents_modified
        ON documents(modified_at DESC)
    ''');

    // FTS5 for full-text search
    _db.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS documents_fts USING fts5(
        document_id UNINDEXED,
        title,
        body,
        tokenize = 'unicode61'
      )
    ''');

    // Sync states (FR-SYNC-001)
    _db.execute('''
      CREATE TABLE IF NOT EXISTS sync_states (
        source_id TEXT NOT NULL,
        path TEXT NOT NULL,
        local_hash TEXT NOT NULL DEFAULT '',
        remote_hash TEXT NOT NULL DEFAULT '',
        last_synced_hash TEXT NOT NULL DEFAULT '',
        last_synced_at INTEGER,
        status TEXT NOT NULL DEFAULT 'synced',
        PRIMARY KEY (source_id, path)
      )
    ''');

    // Sync conflicts (FR-SYNC-002)
    _db.execute('''
      CREATE TABLE IF NOT EXISTS sync_conflicts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        source_id TEXT NOT NULL,
        path TEXT NOT NULL,
        local_hash TEXT NOT NULL,
        remote_hash TEXT NOT NULL,
        conflict_path TEXT,
        detected_at INTEGER NOT NULL,
        resolved INTEGER NOT NULL DEFAULT 0,
        resolution TEXT
      )
    ''');
  }

  // --- Sources ---

  void insertSource({
    required String id,
    required String name,
    required String type,
    required String rootPath,
  }) {
    _db.execute(
      'INSERT OR REPLACE INTO sources (id, name, type, root_path, created_at) VALUES (?, ?, ?, ?, ?)',
      [id, name, type, rootPath, DateTime.now().millisecondsSinceEpoch],
    );
  }

  void updateSourceLastScanned(String id) {
    _db.execute(
      'UPDATE sources SET last_scanned_at = ? WHERE id = ?',
      [DateTime.now().millisecondsSinceEpoch, id],
    );
  }

  List<Map<String, dynamic>> getSources() {
    final result = _db.select('SELECT * FROM sources ORDER BY created_at DESC');
    return result.map((row) => row).toList();
  }

  void deleteSource(String id) {
    _db.execute('DELETE FROM documents WHERE source_id = ?', [id]);
    _db.execute('DELETE FROM sync_states WHERE source_id = ?', [id]);
    _db.execute('DELETE FROM sync_conflicts WHERE source_id = ?', [id]);
    _db.execute('DELETE FROM sources WHERE id = ?', [id]);
  }

  // --- Documents ---

  void insertDocument({
    required String id,
    required String sourceId,
    required String path,
    required String title,
    required int kind,
    required String contentHash,
    required int size,
    required int modifiedAt,
  }) {
    _db.execute(
      '''INSERT OR REPLACE INTO documents
         (id, source_id, path, title, kind, content_hash, size, modified_at, is_available_offline, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, ?)''',
      [id, sourceId, path, title, kind, contentHash, size, modifiedAt,
       DateTime.now().millisecondsSinceEpoch],
    );
  }

  void indexDocumentContent({
    required String documentId,
    required String title,
    required String body,
  }) {
    _db.execute(
      'DELETE FROM documents_fts WHERE document_id = ?',
      [documentId],
    );
    _db.execute(
      'INSERT INTO documents_fts (document_id, title, body) VALUES (?, ?, ?)',
      [documentId, title, body],
    );
  }

  List<Map<String, dynamic>> getDocuments({String? sourceId, int limit = 100}) {
    if (sourceId != null) {
      final result = _db.select(
        'SELECT * FROM documents WHERE source_id = ? ORDER BY modified_at DESC LIMIT ?',
        [sourceId, limit],
      );
      return result.map((row) => row).toList();
    }
    final result = _db.select(
      'SELECT * FROM documents ORDER BY modified_at DESC LIMIT ?',
      [limit],
    );
    return result.map((row) => row).toList();
  }

  Map<String, dynamic>? getDocument(String id) {
    final result = _db.select('SELECT * FROM documents WHERE id = ?', [id]);
    if (result.isEmpty) return null;
    return result.first;
  }

  int getDocumentCount({String? sourceId}) {
    if (sourceId != null) {
      final result = _db.select(
        'SELECT COUNT(*) as count FROM documents WHERE source_id = ?',
        [sourceId],
      );
      return result.first['count'] as int;
    }
    final result = _db.select('SELECT COUNT(*) as count FROM documents');
    return result.first['count'] as int;
  }

  String? getContentHash(String sourceId, String path) {
    final result = _db.select(
      'SELECT content_hash FROM documents WHERE source_id = ? AND path = ?',
      [sourceId, path],
    );
    if (result.isEmpty) return null;
    return result.first['content_hash'] as String;
  }

  // --- Search ---

  List<Map<String, dynamic>> search(String query, {int limit = 50}) {
    final result = _db.select(
      '''SELECT d.*, snippet(documents_fts, 2, '<mark>', '</mark>', '...', 32) as excerpt
         FROM documents_fts
         JOIN documents d ON d.id = documents_fts.document_id
         WHERE documents_fts MATCH ?
         ORDER BY rank
         LIMIT ?''',
      [query, limit],
    );
    return result.map((row) => row).toList();
  }

  // --- Sync States (FR-SYNC-001) ---

  void upsertSyncState({
    required String sourceId,
    required String path,
    required String localHash,
    required String remoteHash,
    required String lastSyncedHash,
    int? lastSyncedAt,
    required String status,
  }) {
    _db.execute(
      '''INSERT OR REPLACE INTO sync_states
         (source_id, path, local_hash, remote_hash, last_synced_hash, last_synced_at, status)
         VALUES (?, ?, ?, ?, ?, ?, ?)''',
      [sourceId, path, localHash, remoteHash, lastSyncedHash, lastSyncedAt, status],
    );
  }

  Map<String, dynamic>? getSyncState(String sourceId, String path) {
    final result = _db.select(
      'SELECT * FROM sync_states WHERE source_id = ? AND path = ?',
      [sourceId, path],
    );
    if (result.isEmpty) return null;
    return result.first;
  }

  List<Map<String, dynamic>> getSyncStates(String sourceId) {
    final result = _db.select(
      'SELECT * FROM sync_states WHERE source_id = ?',
      [sourceId],
    );
    return result.map((row) => row).toList();
  }

  Map<String, String> getLocalHashes(String sourceId) {
    final result = _db.select(
      'SELECT path, local_hash FROM sync_states WHERE source_id = ?',
      [sourceId],
    );
    return {for (var row in result) row['path'] as String: row['local_hash'] as String};
  }

  // --- Sync Conflicts (FR-SYNC-002) ---

  void insertConflict({
    required String sourceId,
    required String path,
    required String localHash,
    required String remoteHash,
    String? conflictPath,
  }) {
    _db.execute(
      '''INSERT INTO sync_conflicts
         (source_id, path, local_hash, remote_hash, conflict_path, detected_at)
         VALUES (?, ?, ?, ?, ?, ?)''',
      [sourceId, path, localHash, remoteHash, conflictPath,
       DateTime.now().millisecondsSinceEpoch],
    );
  }

  List<Map<String, dynamic>> getConflicts({bool unresolvedOnly = true}) {
    final query = unresolvedOnly
        ? 'SELECT * FROM sync_conflicts WHERE resolved = 0 ORDER BY detected_at DESC'
        : 'SELECT * FROM sync_conflicts ORDER BY detected_at DESC';
    final result = _db.select(query);
    return result.map((row) => row).toList();
  }

  void resolveConflict(int id, String resolution) {
    _db.execute(
      'UPDATE sync_conflicts SET resolved = 1, resolution = ? WHERE id = ?',
      [resolution, id],
    );
  }

  int getConflictCount() {
    final result = _db.select(
      'SELECT COUNT(*) as count FROM sync_conflicts WHERE resolved = 0',
    );
    return result.first['count'] as int;
  }

  void close() {
    _db.dispose();
  }
}
