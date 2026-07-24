import 'package:sqlite3/sqlite3.dart';
import 'package:knowledge_core/knowledge_core.dart';

/// A search result with excerpt.
class SearchResult {
  final KnowledgeDocument document;
  final String excerpt;
  final double relevance;

  const SearchResult({
    required this.document,
    required this.excerpt,
    required this.relevance,
  });
}

/// FTS5 search service.
///
/// Uses SQLite FTS5 for full-text search across documents.
/// Supports searching title, body, tags, and path.
class Fts5SearchService {
  final Database _db;

  Fts5SearchService(this._db);

  /// Initialize the FTS5 table.
  void initialize() {
    _db.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS document_contents_fts USING fts5(
        document_id UNINDEXED,
        title,
        body,
        tags,
        path,
        tokenize = 'porter unicode61'
      )
    ''');
  }

  /// Index a document for search.
  void indexDocument({
    required String documentId,
    required String title,
    required String body,
    String? tags,
    required String path,
  }) {
    _db.execute('''
      INSERT OR REPLACE INTO document_contents_fts(document_id, title, body, tags, path)
      VALUES (?, ?, ?, ?, ?)
    ''', [documentId, title, body, tags ?? '', path]);
  }

  /// Remove a document from the index.
  void removeDocument(String documentId) {
    _db.execute('''
      DELETE FROM document_contents_fts WHERE document_id = ?
    ''', [documentId]);
  }

  /// Search for documents matching [query].
  List<SearchResult> search(
    String query, {
    int limit = 50,
    String? sourceId,
    DateTime? modifiedAfter,
    DateTime? modifiedBefore,
  }) {
    final buffer = StringBuffer();
    final params = <Object?>[];

    buffer.write('''
      SELECT d.*, snippet(document_contents_fts, 2, '<mark>', '</mark>', '...', 32) as excerpt,
             rank as relevance
      FROM document_contents_fts
      JOIN documents d ON d.id = document_contents_fts.document_id
      WHERE document_contents_fts MATCH ?
    ''');
    params.add(query);

    if (sourceId != null) {
      buffer.write(' AND d.source_id = ?');
      params.add(sourceId);
    }
    if (modifiedAfter != null) {
      buffer.write(' AND d.modified_at > ?');
      params.add(modifiedAfter.millisecondsSinceEpoch);
    }
    if (modifiedBefore != null) {
      buffer.write(' AND d.modified_at < ?');
      params.add(modifiedBefore.millisecondsSinceEpoch);
    }

    buffer.write(' ORDER BY rank LIMIT ?');
    params.add(limit);

    final results = _db.select(buffer.toString(), params);

    return results.map((row) {
      return SearchResult(
        document: KnowledgeDocument(
          id: row['id'] as String,
          sourceId: row['source_id'] as String,
          path: row['path'] as String,
          title: row['title'] as String,
          kind: DocumentKind.values[row['kind'] as int],
          contentHash: row['content_hash'] as String,
          modifiedAt: DateTime.fromMillisecondsSinceEpoch(row['modified_at'] as int),
          isAvailableOffline: row['is_available_offline'] == 1,
        ),
        excerpt: row['excerpt'] as String? ?? '',
        relevance: row['relevance'] as double? ?? 0.0,
      );
    }).toList();
  }
}
