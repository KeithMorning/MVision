import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// AI configuration stored securely.
class AiConfig {
  final String baseUrl;
  final String apiKey;
  final String model;

  const AiConfig({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
  });

  Map<String, dynamic> toJson() => {
    'baseUrl': baseUrl,
    'apiKey': apiKey,
    'model': model,
  };

  factory AiConfig.fromJson(Map<String, dynamic> json) => AiConfig(
    baseUrl: json['baseUrl'] as String? ?? '',
    apiKey: json['apiKey'] as String? ?? '',
    model: json['model'] as String? ?? 'gpt-4',
  );

  bool get isConfigured => baseUrl.isNotEmpty && apiKey.isNotEmpty;
}

/// AI service for LLM integration (FR-AI-001 BYOK).
///
/// Supports OpenAI-compatible endpoints.
/// API keys are stored in platform secure storage.
class AiService {
  static const _storageKey = 'mvision_ai_config';
  final FlutterSecureStorage _secureStorage;
  final Dio _dio;

  AiConfig? _cachedConfig;

  AiService({
    FlutterSecureStorage? secureStorage,
    Dio? dio,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _dio = dio ?? Dio(BaseOptions(
         connectTimeout: const Duration(seconds: 15),
         receiveTimeout: const Duration(seconds: 60),
         sendTimeout: const Duration(seconds: 30),
       ));

  /// Load AI config from secure storage.
  Future<AiConfig?> loadConfig() async {
    if (_cachedConfig != null) return _cachedConfig;

    try {
      final jsonStr = await _secureStorage.read(key: _storageKey);
      if (jsonStr != null) {
        _cachedConfig = AiConfig.fromJson(jsonDecode(jsonStr));
        return _cachedConfig;
      }
    } catch (e) {
      // Ignore read errors
    }
    return null;
  }

  /// Save AI config to secure storage.
  Future<void> saveConfig(AiConfig config) async {
    await _secureStorage.write(
      key: _storageKey,
      value: jsonEncode(config.toJson()),
    );
    _cachedConfig = config;
  }

  /// Delete AI config from secure storage.
  Future<void> deleteConfig() async {
    await _secureStorage.delete(key: _storageKey);
    _cachedConfig = null;
  }

  /// Test connection to the AI endpoint.
  Future<ConnectionTestResult> testConnection(AiConfig config) async {
    try {
      final response = await _dio.post(
        '${config.baseUrl}/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer ${config.apiKey}',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'model': config.model,
          'messages': [
            {'role': 'user', 'content': 'Hello'}
          ],
          'max_tokens': 10,
        },
      );

      if (response.statusCode == 200) {
        return ConnectionTestResult.success();
      } else {
        return ConnectionTestResult.failure('Unexpected status: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        return ConnectionTestResult.failure('Invalid API key');
      }
      if (e.response?.statusCode == 404) {
        return ConnectionTestResult.failure('Model not found: ${config.model}');
      }
      return ConnectionTestResult.failure('Connection error: ${e.message}');
    } catch (e) {
      return ConnectionTestResult.failure('Error: $e');
    }
  }

  /// Send a chat completion request.
  Future<String> chat({
    required String systemPrompt,
    required String userMessage,
    double temperature = 0.7,
    int maxTokens = 4096,
  }) async {
    final config = await loadConfig();
    if (config == null || !config.isConfigured) {
      throw Exception('AI not configured. Please set up your API key in Settings.');
    }

    final response = await _dio.post(
      '${config.baseUrl}/chat/completions',
      options: Options(
        headers: {
          'Authorization': 'Bearer ${config.apiKey}',
          'Content-Type': 'application/json',
        },
      ),
      data: {
        'model': config.model,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userMessage},
        ],
        'temperature': temperature,
        'max_tokens': maxTokens,
      },
    );

    final data = response.data;
    if (data['choices'] != null && (data['choices'] as List).isNotEmpty) {
      return data['choices'][0]['message']['content'] as String;
    }
    throw Exception('No response from AI');
  }

  /// Send a streaming chat completion request.
  /// Calls [onToken] for each token received.
  Future<String> chatStream({
    required String systemPrompt,
    required String userMessage,
    required void Function(String token) onToken,
    double temperature = 0.7,
    int maxTokens = 4096,
  }) async {
    final config = await loadConfig();
    if (config == null || !config.isConfigured) {
      throw Exception('AI not configured. Please set up your API key in Settings.');
    }

    final buffer = StringBuffer();

    final response = await _dio.post<ResponseBody>(
      '${config.baseUrl}/chat/completions',
      options: Options(
        headers: {
          'Authorization': 'Bearer ${config.apiKey}',
          'Content-Type': 'application/json',
        },
        responseType: ResponseType.stream,
      ),
      data: {
        'model': config.model,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userMessage},
        ],
        'temperature': temperature,
        'max_tokens': maxTokens,
        'stream': true,
      },
    );

    final stream = response.data!.stream;
    final lines = stream.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter());

    await for (final line in lines) {
      if (line.startsWith('data: ')) {
        final data = line.substring(6);
        if (data == '[DONE]') break;
        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          final delta = json['choices']?[0]?['delta'];
          final content = delta?['content'] as String?;
          if (content != null && content.isNotEmpty) {
            buffer.write(content);
            onToken(content);
          }
        } catch (_) {
          // Skip malformed chunks
        }
      }
    }

    return buffer.toString();
  }

  /// Generate Wiki content from source documents (FR-AI-003).
  Future<WikiCompilationResult> compileWiki({
    required List<String> sourceContents,
    required List<String> existingWikiPages,
    required String topic,
  }) async {
    final systemPrompt = '''You are a knowledge compiler for a personal Wiki.
Your task is to analyze source documents and generate structured Wiki updates.

Rules:
1. Generate summaries, cross-links, and source references
2. Prefer updating existing topics over creating new ones
3. Mark contradictions, uncertainties, and outdated information
4. Output structured JSON with the following format:
{
  "summary": "Brief description of changes",
  "patches": [
    {
      "action": "create" | "update",
      "path": "wiki/topic-name.md",
      "content": "Markdown content",
      "references": ["source1.md", "source2.md"]
    }
  ],
  "links": [["Topic A", "Topic B"]]
}

Do NOT modify source documents. Only generate Wiki content.''';

    final userMessage = '''Topic: $topic

Source documents:
${sourceContents.asMap().entries.map((e) => '--- Source ${e.key + 1} ---\n${e.value}').join('\n\n')}

Existing Wiki pages:
${existingWikiPages.isEmpty ? '(none)' : existingWikiPages.join('\n\n---\n\n')}

Generate Wiki compilation result as JSON:''';

    final response = await chat(
      systemPrompt: systemPrompt,
      userMessage: userMessage,
      temperature: 0.3,
    );

    return WikiCompilationResult.parse(response);
  }

  /// Answer a question about knowledge base (FR-AI-006).
  Future<QaResult> askQuestion({
    required String question,
    required List<String> contextDocuments,
  }) async {
    final systemPrompt = '''You are a knowledge assistant. Answer questions based ONLY on the provided context.

Rules:
1. Always cite your sources
2. If you cannot find reliable information, say so clearly
3. Do not make up citations
4. Format your answer in Markdown

Output format:
{
  "answer": "Your answer in Markdown",
  "sources": ["source1.md", "source2.md"],
  "confidence": "high" | "medium" | "low"
}''';

    final userMessage = '''Context documents:
${contextDocuments.asMap().entries.map((e) => '--- Document ${e.key + 1} ---\n${e.value}').join('\n\n')}

Question: $question

Answer as JSON:''';

    final response = await chat(
      systemPrompt: systemPrompt,
      userMessage: userMessage,
      temperature: 0.3,
    );

    return QaResult.parse(response);
  }
}

/// Result of a connection test.
class ConnectionTestResult {
  final bool success;
  final String? errorMessage;

  const ConnectionTestResult({required this.success, this.errorMessage});

  factory ConnectionTestResult.success() => const ConnectionTestResult(success: true);
  factory ConnectionTestResult.failure(String message) =>
      ConnectionTestResult(success: false, errorMessage: message);
}

/// Result of Wiki compilation.
class WikiCompilationResult {
  final String summary;
  final List<WikiPatchItem> patches;
  final List<List<String>> links;

  const WikiCompilationResult({
    required this.summary,
    required this.patches,
    required this.links,
  });

  factory WikiCompilationResult.parse(String response) {
    try {
      // Try to extract JSON from response
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(response);
      if (jsonMatch != null) {
        final json = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
        final patches = (json['patches'] as List? ?? [])
            .map((p) => WikiPatchItem.fromJson(p))
            .toList();
        final links = (json['links'] as List? ?? [])
            .map((l) => (l as List).map((e) => e.toString()).toList())
            .toList();
        return WikiCompilationResult(
          summary: json['summary'] as String? ?? '',
          patches: patches,
          links: links,
        );
      }
    } catch (e) {
      // Fall through to raw response
    }
    return WikiCompilationResult(
      summary: response,
      patches: [],
      links: [],
    );
  }
}

/// A single Wiki patch item.
class WikiPatchItem {
  final String action;
  final String path;
  final String content;
  final List<String> references;

  const WikiPatchItem({
    required this.action,
    required this.path,
    required this.content,
    required this.references,
  });

  factory WikiPatchItem.fromJson(Map<String, dynamic> json) => WikiPatchItem(
    action: json['action'] as String? ?? 'create',
    path: json['path'] as String? ?? '',
    content: json['content'] as String? ?? '',
    references: (json['references'] as List? ?? [])
        .map((e) => e.toString())
        .toList(),
  );
}

/// Result of a Q&A query.
class QaResult {
  final String answer;
  final List<String> sources;
  final String confidence;

  const QaResult({
    required this.answer,
    required this.sources,
    required this.confidence,
  });

  factory QaResult.parse(String response) {
    try {
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(response);
      if (jsonMatch != null) {
        final json = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
        return QaResult(
          answer: json['answer'] as String? ?? response,
          sources: (json['sources'] as List? ?? [])
              .map((e) => e.toString())
              .toList(),
          confidence: json['confidence'] as String? ?? 'medium',
        );
      }
    } catch (e) {
      // Fall through
    }
    return QaResult(
      answer: response,
      sources: [],
      confidence: 'low',
    );
  }
}
