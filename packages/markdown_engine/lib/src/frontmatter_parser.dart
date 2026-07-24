/// YAML Frontmatter parser for MVision.
///
/// Preserves frontmatter in Markdown documents.
library frontmatter_parser;

/// Parsed YAML frontmatter.
class Frontmatter {
  /// The raw YAML content.
  final String raw;

  /// Parsed key-value pairs.
  final Map<String, dynamic> data;

  /// Start offset of frontmatter in source.
  final int start;

  /// End offset of frontmatter in source.
  final int end;

  const Frontmatter({
    required this.raw,
    required this.data,
    required this.start,
    required this.end,
  });

  /// The content after frontmatter.
  String bodyFrom(String source) => source.substring(end).trimLeft();
}

/// Parser for YAML frontmatter.
class FrontmatterParser {
  FrontmatterParser._();

  /// Regex pattern for YAML frontmatter.
  static final RegExp _pattern = RegExp(
    r'^---\s*\n([\s\S]*?)\n---\s*\n?',
    multiLine: true,
  );

  /// Parse frontmatter from [source].
  static Frontmatter? parse(String source) {
    final match = _pattern.firstMatch(source);
    if (match == null) return null;

    final raw = match.group(1) ?? '';
    final data = _parseYaml(raw);

    return Frontmatter(
      raw: raw,
      data: data,
      start: match.start,
      end: match.end,
    );
  }

  /// Check if [source] has frontmatter.
  static bool hasFrontmatter(String source) {
    return _pattern.hasMatch(source);
  }

  /// Extract frontmatter and return (frontmatter, body).
  static (Frontmatter?, String) extract(String source) {
    final frontmatter = parse(source);
    if (frontmatter == null) {
      return (null, source);
    }
    return (frontmatter, source.substring(frontmatter.end).trimLeft());
  }

  /// Simple YAML parser for key-value pairs.
  static Map<String, dynamic> _parseYaml(String yaml) {
    final result = <String, dynamic>{};
    final lines = yaml.split('\n');

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      final colonIndex = trimmed.indexOf(':');
      if (colonIndex > 0) {
        final key = trimmed.substring(0, colonIndex).trim();
        final value = trimmed.substring(colonIndex + 1).trim();
        result[key] = _parseValue(value);
      }
    }

    return result;
  }

  static dynamic _parseValue(String value) {
    if (value.isEmpty) return null;
    if (value == 'true') return true;
    if (value == 'false') return false;
    if (value == 'null') return null;

    // Try to parse as number
    final intValue = int.tryParse(value);
    if (intValue != null) return intValue;

    final doubleValue = double.tryParse(value);
    if (doubleValue != null) return doubleValue;

    // Remove quotes
    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
      return value.substring(1, value.length - 1);
    }

    // Parse as list
    if (value.startsWith('[') && value.endsWith(']')) {
      final items = value.substring(1, value.length - 1);
      return items.split(',').map((e) => _parseValue(e.trim())).toList();
    }

    return value;
  }
}
