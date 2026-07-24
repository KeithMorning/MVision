import 'package:freezed_annotation/freezed_annotation.dart';
import 'document_kind.dart';

part 'knowledge_document.freezed.dart';
part 'knowledge_document.g.dart';

/// A knowledge document in the system.
///
/// Document identity is separated from path. The same document may exist
/// at different paths in different sources.
@freezed
class KnowledgeDocument with _$KnowledgeDocument {
  const factory KnowledgeDocument({
    /// Unique document ID.
    required String id,

    /// ID of the source this document belongs to.
    required String sourceId,

    /// Path within the source.
    required String path,

    /// Document title (from filename or frontmatter).
    required String title,

    /// Type of document.
    required DocumentKind kind,

    /// Content hash for change detection.
    required String contentHash,

    /// Last modification time.
    required DateTime modifiedAt,

    /// Whether the document is available offline.
    @Default(false) bool isAvailableOffline,
  }) = _KnowledgeDocument;

  factory KnowledgeDocument.fromJson(Map<String, dynamic> json) =>
      _$KnowledgeDocumentFromJson(json);
}
