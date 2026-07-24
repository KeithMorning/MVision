/// Wiki Link parser for MVision.
///
/// Parses `[[Wiki Link]]` syntax in Markdown documents.
library wiki_link_parser;

/// A Wiki Link found in a document.
class WikiLink {
  /// The target of the link (e.g., "Page Name" in `[[Page Name]]`).
  final String target;

  /// Optional display text (e.g., "Display" in `[[Page Name|Display]]`).
  final String? displayText;

  /// The original raw text (e.g., "[[Page Name|Display]]").
  final String raw;

  /// Start offset in source.
  final int start;

  /// End offset in source.
  final int end;

  const WikiLink({
    required this.target,
    this.displayText,
    required this.raw,
    required this.start,
    required this.end,
  });

  /// The text to display for this link.
  String get effectiveText => displayText ?? target;
}

/// Parser for `[[Wiki Link]]` syntax.
class WikiLinkParser {
  WikiLinkParser._();

  /// Regex pattern for Wiki Links.
  /// Matches `[[Target]]` or `[[Target|Display Text]]`.
  static final RegExp _pattern = RegExp(
    r'\[\[([^\]|]+)(?:\|([^\]]+))?\]\]',
    multiLine: true,
  );

  /// Parse all Wiki Links from [source].
  static List<WikiLink> parse(String source) {
    final links = <WikiLink>[];

    for (final match in _pattern.allMatches(source)) {
      links.add(WikiLink(
        target: match.group(1)!.trim(),
        displayText: match.group(2)?.trim(),
        raw: match.group(0)!,
        start: match.start,
        end: match.end,
      ));
    }

    return links;
  }

  /// Replace Wiki Links with standard Markdown links.
  ///
  /// Useful for rendering with standard Markdown renderers.
  static String toMarkdownLinks(String source, {String Function(String)? resolver}) {
    return source.replaceAllMapped(_pattern, (match) {
      final target = match.group(1)!.trim();
      final display = match.group(2)?.trim() ?? target;
      final resolved = resolver?.call(target) ?? target;
      return '[$display]($resolved)';
    });
  }

  /// Check if [source] contains any Wiki Links.
  static bool hasWikiLinks(String source) {
    return _pattern.hasMatch(source);
  }

  /// Extract all unique Wiki Link targets.
  static Set<String> extractTargets(String source) {
    return parse(source).map((link) => link.target).toSet();
  }
}
