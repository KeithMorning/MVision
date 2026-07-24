import 'package:freezed_annotation/freezed_annotation.dart';

part 'source_reference.freezed.dart';
part 'source_reference.g.dart';

/// Reference to a source document for citations.
@freezed
class SourceReference with _$SourceReference {
  const factory SourceReference({
    /// ID of the source document.
    required String sourceDocumentId,

    /// Optional anchor within the document (e.g., heading, block).
    String? anchor,

    /// Excerpt from the source.
    required String excerpt,
  }) = _SourceReference;

  factory SourceReference.fromJson(Map<String, dynamic> json) =>
      _$SourceReferenceFromJson(json);
}
