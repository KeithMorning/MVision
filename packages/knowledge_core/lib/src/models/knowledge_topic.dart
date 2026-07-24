import 'package:freezed_annotation/freezed_annotation.dart';

part 'knowledge_topic.freezed.dart';
part 'knowledge_topic.g.dart';

/// A knowledge topic grouping related documents.
@freezed
class KnowledgeTopic with _$KnowledgeTopic {
  const factory KnowledgeTopic({
    /// Unique topic ID.
    required String id,

    /// Topic title.
    required String title,

    /// Optional summary of the topic.
    String? summary,

    /// IDs of documents in this topic.
    @Default([]) List<String> documentIds,

    /// Last update time.
    required DateTime updatedAt,
  }) = _KnowledgeTopic;

  factory KnowledgeTopic.fromJson(Map<String, dynamic> json) =>
      _$KnowledgeTopicFromJson(json);
}
