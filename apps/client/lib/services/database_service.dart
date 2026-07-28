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

    // Vault configuration (single vault model, like Obsidian)
    _db.execute('''
      CREATE TABLE IF NOT EXISTS vault_config (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        name TEXT NOT NULL DEFAULT 'My Vault',
        root_path TEXT NOT NULL,
        daily_notes_folder TEXT NOT NULL DEFAULT 'daily',
        templates_folder TEXT NOT NULL DEFAULT 'templates',
        created_at INTEGER NOT NULL,
        last_opened_at INTEGER
      )
    ''');

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

    // Links between documents (backlinks, outgoing links)
    _db.execute('''
      CREATE TABLE IF NOT EXISTS links (
        source_doc_id TEXT NOT NULL,
        target_doc_id TEXT NOT NULL,
        link_text TEXT NOT NULL DEFAULT '',
        link_type TEXT NOT NULL DEFAULT 'wiki',
        context TEXT NOT NULL DEFAULT '',
        PRIMARY KEY (source_doc_id, target_doc_id, link_text),
        FOREIGN KEY (source_doc_id) REFERENCES documents(id) ON DELETE CASCADE,
        FOREIGN KEY (target_doc_id) REFERENCES documents(id) ON DELETE CASCADE
      )
    ''');

    _db.execute('''
      CREATE INDEX IF NOT EXISTS idx_links_target
        ON links(target_doc_id)
    ''');

    _db.execute('''
      CREATE INDEX IF NOT EXISTS idx_links_source
        ON links(source_doc_id)
    ''');

    // Tags
    _db.execute('''
      CREATE TABLE IF NOT EXISTS tags (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE COLLATE NOCASE
      )
    ''');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS document_tags (
        document_id TEXT NOT NULL,
        tag_id INTEGER NOT NULL,
        PRIMARY KEY (document_id, tag_id),
        FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE,
        FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
      )
    ''');

    // Starred / favorites
    _db.execute('''
      CREATE TABLE IF NOT EXISTS starred (
        document_id TEXT PRIMARY KEY,
        starred_at INTEGER NOT NULL,
        FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE
      )
    ''');

    // Recent files (for quick switcher)
    _db.execute('''
      CREATE TABLE IF NOT EXISTS recent_files (
        document_id TEXT PRIMARY KEY,
        opened_at INTEGER NOT NULL,
        FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE
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

  Map<String, dynamic>? getSourceById(String id) {
    final result = _db.select('SELECT * FROM sources WHERE id = ?', [id]);
    if (result.isEmpty) return null;
    return result.first;
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

  // --- Vault Config ---

  void setVaultConfig({
    required String name,
    required String rootPath,
    String dailyNotesFolder = 'daily',
    String templatesFolder = 'templates',
  }) {
    _db.execute(
      '''INSERT OR REPLACE INTO vault_config
         (id, name, root_path, daily_notes_folder, templates_folder, created_at, last_opened_at)
         VALUES (1, ?, ?, ?, ?, COALESCE((SELECT created_at FROM vault_config WHERE id = 1), ?), ?)''',
      [name, rootPath, dailyNotesFolder, templatesFolder,
       DateTime.now().millisecondsSinceEpoch, DateTime.now().millisecondsSinceEpoch],
    );
  }

  Map<String, dynamic>? getVaultConfig() {
    final result = _db.select('SELECT * FROM vault_config WHERE id = 1');
    if (result.isEmpty) return null;
    return result.first;
  }

  void updateVaultLastOpened() {
    _db.execute(
      'UPDATE vault_config SET last_opened_at = ? WHERE id = 1',
      [DateTime.now().millisecondsSinceEpoch],
    );
  }

  // --- Links ---

  void clearLinksForDocument(String docId) {
    _db.execute('DELETE FROM links WHERE source_doc_id = ?', [docId]);
  }

  void insertLink({
    required String sourceDocId,
    required String targetDocId,
    required String linkText,
    required String linkType,
    required String context,
  }) {
    _db.execute(
      '''INSERT OR REPLACE INTO links (source_doc_id, target_doc_id, link_text, link_type, context)
         VALUES (?, ?, ?, ?, ?)''',
      [sourceDocId, targetDocId, linkText, linkType, context],
    );
  }

  /// Get backlinks for a document (documents that link TO this doc).
  List<Map<String, dynamic>> getBacklinks(String docId) {
    final result = _db.select(
      '''SELECT l.*, d.title as source_title, d.path as source_path
         FROM links l
         JOIN documents d ON d.id = l.source_doc_id
         WHERE l.target_doc_id = ?
         ORDER BY d.title''',
      [docId],
    );
    return result.map((row) => row).toList();
  }

  /// Get outgoing links from a document.
  List<Map<String, dynamic>> getOutgoingLinks(String docId) {
    final result = _db.select(
      '''SELECT l.*, d.title as target_title, d.path as target_path
         FROM links l
         JOIN documents d ON d.id = l.target_doc_id
         WHERE l.source_doc_id = ?
         ORDER BY d.title''',
      [docId],
    );
    return result.map((row) => row).toList();
  }

  int getBacklinkCount(String docId) {
    final result = _db.select(
      'SELECT COUNT(*) as count FROM links WHERE target_doc_id = ?',
      [docId],
    );
    return result.first['count'] as int;
  }

  /// Get all documents that link to a specific document.
  List<Map<String, dynamic>> getDocumentsLinkingTo(String targetDocId) {
    final result = _db.select(
      '''SELECT DISTINCT d.* 
         FROM documents d
         JOIN links l ON l.source_doc_id = d.id
         WHERE l.target_doc_id = ?''',
      [targetDocId],
    );
    return result.map((row) => row).toList();
  }

  /// Update document path and title (used when renaming).
  void updateDocumentPath(String docId, String newPath, String newTitle) {
    _db.execute(
      'UPDATE documents SET path = ?, title = ? WHERE id = ?',
      [newPath, newTitle, docId],
    );
    // Also update FTS index
    _db.execute(
      'UPDATE documents_fts SET title = ? WHERE document_id = ?',
      [newTitle, docId],
    );
  }

  /// Get document by path.
  Map<String, dynamic>? getDocumentByPath(String path) {
    final result = _db.select('SELECT * FROM documents WHERE path = ?', [path]);
    if (result.isEmpty) return null;
    return result.first;
  }

  // --- Tags ---

  int getOrCreateTag(String name) {
    final normalized = name.toLowerCase().trim();
    final existing = _db.select('SELECT id FROM tags WHERE name = ?', [normalized]);
    if (existing.isNotEmpty) return existing.first['id'] as int;
    _db.execute('INSERT INTO tags (name) VALUES (?)', [normalized]);
    return _db.lastInsertRowId;
  }

  void clearTagsForDocument(String docId) {
    _db.execute('DELETE FROM document_tags WHERE document_id = ?', [docId]);
  }

  void addTagToDocument(String docId, int tagId) {
    _db.execute(
      'INSERT OR IGNORE INTO document_tags (document_id, tag_id) VALUES (?, ?)',
      [docId, tagId],
    );
  }

  List<Map<String, dynamic>> getAllTags() {
    final result = _db.select(
      '''SELECT t.id, t.name, COUNT(dt.document_id) as doc_count
         FROM tags t
         LEFT JOIN document_tags dt ON dt.tag_id = t.id
         GROUP BY t.id
         ORDER BY doc_count DESC, t.name''',
    );
    return result.map((row) => row).toList();
  }

  List<Map<String, dynamic>> getTagsForDocument(String docId) {
    final result = _db.select(
      '''SELECT t.id, t.name
         FROM tags t
         JOIN document_tags dt ON dt.tag_id = t.id
         WHERE dt.document_id = ?
         ORDER BY t.name''',
      [docId],
    );
    return result.map((row) => row).toList();
  }

  List<Map<String, dynamic>> getDocumentsByTag(int tagId, {int limit = 100}) {
    final result = _db.select(
      '''SELECT d.*
         FROM documents d
         JOIN document_tags dt ON dt.document_id = d.id
         WHERE dt.tag_id = ?
         ORDER BY d.modified_at DESC
         LIMIT ?''',
      [tagId, limit],
    );
    return result.map((row) => row).toList();
  }

  // --- Starred ---

  void toggleStar(String docId) {
    final existing = _db.select(
      'SELECT document_id FROM starred WHERE document_id = ?', [docId],
    );
    if (existing.isNotEmpty) {
      _db.execute('DELETE FROM starred WHERE document_id = ?', [docId]);
    } else {
      _db.execute(
        'INSERT INTO starred (document_id, starred_at) VALUES (?, ?)',
        [docId, DateTime.now().millisecondsSinceEpoch],
      );
    }
  }

  bool isStarred(String docId) {
    final result = _db.select(
      'SELECT document_id FROM starred WHERE document_id = ?', [docId],
    );
    return result.isNotEmpty;
  }

  List<Map<String, dynamic>> getStarredDocuments() {
    final result = _db.select(
      '''SELECT d.*, s.starred_at
         FROM documents d
         JOIN starred s ON s.document_id = d.id
         ORDER BY s.starred_at DESC''',
    );
    return result.map((row) => row).toList();
  }

  // --- Recent Files ---

  void recordFileOpened(String docId) {
    _db.execute(
      '''INSERT OR REPLACE INTO recent_files (document_id, opened_at)
         VALUES (?, ?)''',
      [docId, DateTime.now().millisecondsSinceEpoch],
    );
  }

  List<Map<String, dynamic>> getRecentFiles({int limit = 20}) {
    final result = _db.select(
      '''SELECT d.*, r.opened_at
         FROM documents d
         JOIN recent_files r ON r.document_id = d.id
         ORDER BY r.opened_at DESC
         LIMIT ?''',
      [limit],
    );
    return result.map((row) => row).toList();
  }

  // --- Document lookup helpers ---

  /// Find a document by filename (without extension) for wiki link resolution.
  Map<String, dynamic>? findDocumentByTitle(String title) {
    final result = _db.select(
      'SELECT * FROM documents WHERE title = ? COLLATE NOCASE LIMIT 1',
      [title],
    );
    if (result.isNotEmpty) return result.first;
    // Try matching by filename without extension
    final result2 = _db.select(
      '''SELECT * FROM documents
         WHERE REPLACE(REPLACE(path, '.md', ''), '.markdown', '') LIKE ?
         LIMIT 1''',
      ['%$title'],
    );
    if (result2.isNotEmpty) return result2.first;
    return null;
  }

  /// Get all document titles for autocomplete.
  List<Map<String, dynamic>> getAllDocumentTitles() {
    final result = _db.select(
      'SELECT id, title, path FROM documents ORDER BY title',
    );
    return result.map((row) => row).toList();
  }

  void close() {
    _db.dispose();
  }
}
