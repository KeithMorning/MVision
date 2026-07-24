import 'package:markdown/markdown.dart' as md;

/// Markdown AST parser.
///
/// Wraps the `markdown` package and provides a simplified API
/// for parsing Markdown into an AST.
class MarkdownParser {
  MarkdownParser._();

  /// Parse Markdown source into an AST document.
  static md.Document parse(String source) {
    return md.Document(
      extensionSet: md.ExtensionSet.gitHubFlavored,
      encodeHtml: false,
    );
  }

  /// Parse and return the AST nodes.
  static List<md.Node> parseNodes(String source) {
    final document = parse(source);
    return document.parseLines(source.split('\n'));
  }

  /// Extract headings from a Markdown source.
  static List<MarkdownHeading> extractHeadings(String source) {
    final nodes = parseNodes(source);
    return _extractHeadings(nodes);
  }

  static List<MarkdownHeading> _extractHeadings(List<md.Node> nodes) {
    final headings = <MarkdownHeading>[];
    for (final node in nodes) {
      if (node is md.Element && node.tag.startsWith('h')) {
        final level = int.tryParse(node.tag.substring(1)) ?? 1;
        headings.add(MarkdownHeading(
          level: level,
          text: node.textContent,
        ));
      }
    }
    return headings;
  }

  /// Extract all links from a Markdown source.
  static List<MarkdownLink> extractLinks(String source) {
    final nodes = parseNodes(source);
    return _extractLinks(nodes);
  }

  static List<MarkdownLink> _extractLinks(List<md.Node> nodes) {
    final links = <MarkdownLink>[];
    for (final node in nodes) {
      if (node is md.Element && node.tag == 'a') {
        links.add(MarkdownLink(
          text: node.textContent,
          href: node.attributes['href'] ?? '',
        ));
      }
    }
    return links;
  }
}

/// A heading extracted from Markdown.
class MarkdownHeading {
  final int level;
  final String text;

  const MarkdownHeading({
    required this.level,
    required this.text,
  });
}

/// A link extracted from Markdown.
class MarkdownLink {
  final String text;
  final String href;

  const MarkdownLink({
    required this.text,
    required this.href,
  });
}
