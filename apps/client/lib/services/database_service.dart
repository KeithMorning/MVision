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

  void close() {
    _db.dispose();
  }
}
