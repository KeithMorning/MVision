import 'package:knowledge_core/knowledge_core.dart';

/// Service for compiling Wiki from sources using LLM.
///
/// This is a placeholder interface for Phase 3 implementation.
abstract interface class WikiCompiler {
  /// Identify new or changed sources since last compilation.
  Future<List<String>> identifyChangedSources();

  /// Retrieve relevant existing Wiki pages for context.
  Future<List<String>> retrieveContext(List<String> changedSources);

  /// Build the LLM prompt for Wiki compilation.
  Future<String> buildPrompt(List<String> sources, List<String> context);

  /// Call the LLM with the prompt.
  Future<String> callLlm(String prompt);

  /// Parse the LLM response into a Wiki patch.
  Future<WikiPatch> parseResponse(String response);

  /// Compile Wiki from changed sources.
  Future<WikiPatch> compile();
}
