/// Type of knowledge document.
enum DocumentKind {
  /// Markdown document (.md, .markdown)
  markdown,

  /// PDF document
  pdf,

  /// Image file
  image,

  /// Plain text
  text,

  /// Other/unknown
  other,
}

/// Extension to get kind from file extension.
extension DocumentKindFromPath on String {
  DocumentKind get documentKind {
    final ext = split('.').last.toLowerCase();
    return switch (ext) {
      'md' || 'markdown' => DocumentKind.markdown,
      'pdf' => DocumentKind.pdf,
      'jpg' || 'jpeg' || 'png' || 'gif' || 'webp' || 'svg' => DocumentKind.image,
      'txt' => DocumentKind.text,
      _ => DocumentKind.other,
    };
  }
}
