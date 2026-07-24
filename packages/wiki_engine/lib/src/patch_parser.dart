import 'dart:convert';
import 'package:knowledge_core/knowledge_core.dart';

/// Parses LLM responses into Wiki patches.
class PatchParser {
  PatchParser._();

  /// Parse an LLM response into a WikiPatch.
  static WikiPatch? parse(String response) {
    try {
      // Try to extract JSON from response
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(response);
      if (jsonMatch == null) return null;

      final json = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
      return _parseJson(json);
    } catch (e) {
      return null;
    }
  }

  static WikiPatch _parseJson(Map<String, dynamic> json) {
    final files = (json['files'] as List<dynamic>?)
            ?.map((f) => FilePatch(
                  path: f['path'] as String,
                  operation: _parseOperation(f['operation'] as String),
                  content: f['content'] as String?,
                  originalContent: f['originalContent'] as String?,
                ))
            .toList() ??
        [];

    final references = (json['references'] as List<dynamic>?)
            ?.map((r) => SourceReference(
                  sourceDocumentId: r['sourceDocumentId'] as String,
                  anchor: r['anchor'] as String?,
                  excerpt: r['excerpt'] as String,
                ))
            .toList() ??
        [];

    return WikiPatch(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      files: files,
      references: references,
      summary: json['summary'] as String? ?? '',
      riskLevel: _parseRiskLevel(json['riskLevel'] as String?),
      createdAt: DateTime.now(),
    );
  }

  static FilePatchOperation _parseOperation(String op) {
    return switch (op) {
      'create' => FilePatchOperation.create,
      'update' => FilePatchOperation.update,
      'delete' => FilePatchOperation.delete,
      'move' => FilePatchOperation.move,
      _ => FilePatchOperation.update,
    };
  }

  static PatchRiskLevel _parseRiskLevel(String? level) {
    return switch (level) {
      'low' => PatchRiskLevel.low,
      'medium' => PatchRiskLevel.medium,
      'high' => PatchRiskLevel.high,
      'critical' => PatchRiskLevel.critical,
      _ => PatchRiskLevel.medium,
    };
  }
}
