import 'package:knowledge_core/knowledge_core.dart';

/// Builds prompts for LLM Wiki compilation.
class PromptBuilder {
  PromptBuilder._();

  /// Build the system prompt for Wiki compilation.
  static String buildSystemPrompt() {
    return '''
You are a knowledge compiler for a personal Wiki system.

Your task is to analyze new source materials and propose updates to existing Wiki pages.

Rules:
1. Output a structured WikiPatch in JSON format
2. Only write to the wiki/ directory
3. Never modify sources/ directory
4. Include source references for all claims
5. Mark any contradictions or uncertainties
6. Prefer updating existing pages over creating new ones

Output format:
{
  "summary": "Description of changes",
  "riskLevel": "low|medium|high|critical",
  "files": [
    {
      "path": "wiki/page.md",
      "operation": "create|update|delete|move",
      "content": "...",
      "originalContent": "..."
    }
  ],
  "references": [
    {
      "sourceDocumentId": "doc-id",
      "anchor": "optional-anchor",
      "excerpt": "relevant text"
    }
  ]
}
''';
  }

  /// Build the user prompt with source content and context.
  static String buildUserPrompt({
    required List<String> sourceContents,
    required List<String> existingWikiPages,
    required Map<String, String> sourceMetadata,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('# New Source Materials');
    buffer.writeln();
    for (var i = 0; i < sourceContents.length; i++) {
      buffer.writeln('## Source ${i + 1}');
      buffer.writeln(sourceContents[i]);
      buffer.writeln();
    }

    if (existingWikiPages.isNotEmpty) {
      buffer.writeln('# Existing Wiki Pages');
      buffer.writeln();
      for (final page in existingWikiPages) {
        buffer.writeln('---');
        buffer.writeln(page);
        buffer.writeln();
      }
    }

    buffer.writeln('Please analyze the new sources and propose Wiki updates as a WikiPatch.');

    return buffer.toString();
  }

  /// Build a Q&A prompt.
  static String buildQaPrompt({
    required String question,
    required List<String> contextDocuments,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('# Context');
    buffer.writeln();
    for (var i = 0; i < contextDocuments.length; i++) {
      buffer.writeln('## Document ${i + 1}');
      buffer.writeln(contextDocuments[i]);
      buffer.writeln();
    }

    buffer.writeln('# Question');
    buffer.writeln(question);
    buffer.writeln();
    buffer.writeln('Please answer based on the context above. ');
    buffer.writeln('If the context does not contain enough information, say so explicitly. ');
    buffer.writeln('Always cite your sources.');

    return buffer.toString();
  }
}
