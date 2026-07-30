import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'database_service.dart';

/// Scans a local directory for Markdown files and indexes them.
/// Also parses links (wiki links, markdown links) and tags.
class ScannerService {
  final DatabaseService db;

  ScannerService({required this.db});

  /// Extensions we consider as documents.
  static const _supportedExtensions = {'.md', '.markdown'};

  /// Directories to skip during scanning.
  static const _ignoredDirs = {
    '.git', '.svn', '.hg',
    'node_modules', '.dart_tool', '.build',
    '.mvision', '__pycache__', '.Trash', '.obsidian',
  };

  /// Scan progress callback.
  void Function(int processed, int total)? onProgress;

  // Regex patterns for parsing
  static final _wikiLinkPattern = RegExp(
    r'\[\[([^\]|]+)(?:\|([^\]]+))?\]\]',
    multiLine: true,
  );

  static final _markdownLinkPattern = RegExp(
    r'\[([^\]]+)\]\(([^)]+\.md(?:#[^)]*)?)\)',
    multiLine: true,
  );

  static final _inlineTagPattern = RegExp(
    r'(?:^|\s)#([a-zA-Z\u4e00-\u9fff][a-zA-Z0-9\u4e00-\u9fff_/-]*)',
    multiLine: true,
  );

  static final _frontmatterTagsPattern = RegExp(
    r'^tags:\s*\[([^\]]+)\]',
    multiLine: true,
  );

  static final _frontmatterTagsListPattern = RegExp(
    r'^tags:\s*\n((?:\s+-\s+.+\n?)+)',
    multiLine: true,
  );

  /// Scan a source directory and index all Markdown files.
  ///
  /// Returns the number of new/updated documents.
  Future<int> scanSource({
    required String sourceId,
    required String rootPath,
  }) async {
    final root = Directory(rootPath);
    if (!await root.exists()) {
      throw Exception('Directory does not exist: $rootPath');
    }

    // Collect all markdown files first
    final files = <File>[];
    await _collectFiles(root, files);

    int updated = 0;
    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      final relativePath = p.relative(file.path, from: rootPath);

      try {
        final stat = await file.stat();
        final bytes = await file.readAsBytes();
        final hash = sha256.convert(bytes).toString();

        // Check if file changed
        final existingHash = db.getContentHash(sourceId, relativePath);
        if (existingHash == hash) continue; // No change

        final content = utf8.decode(bytes, allowMalformed: true);
        final title = _extractTitle(relativePath, content);
        final docId = _generateDocId(sourceId, relativePath);

        db.insertDocument(
          id: docId,
          sourceId: sourceId,
          path: relativePath,
          title: title,
          kind: 0, // markdown
          contentHash: hash,
          size: stat.size,
          modifiedAt: stat.modified.millisecondsSinceEpoch,
        );

        // Index content for FTS
        db.indexDocumentContent(
          documentId: docId,
          title: title,
          body: content,
        );

        // Parse and store tags
        _parseAndStoreTags(docId, content);

        updated++;
      } catch (e) {
        // Skip files that can't be read
        continue;
      }

      onProgress?.call(i + 1, files.length);
    }

    // Pass 2: rebuild links for the whole vault.
    //
    // Link resolution requires every document to be indexed first. Parsing
    // per-file during pass 1 silently dropped forward references (a file
    // linking to a not-yet-scanned file), and since unchanged files are
    // skipped on later scans, those links never healed.
    await _rebuildLinks(rootPath);

    db.updateSourceLastScanned(sourceId);
    return updated;
  }

  /// Re-parse links for every indexed document.
  ///
  /// Vaults are small (hundreds of notes), so a full rebuild after each scan
  /// is cheap and guarantees a correct link graph.
  Future<void> _rebuildLinks(String rootPath) async {
    final docs = db.getAllDocumentTitles();

    // Lookup indexes, Obsidian semantics:
    // - byName:  file basename without extension (primary wiki-link target)
    // - byPath:  full relative path without extension (path-form links)
    // - byTitle: frontmatter/heading title (fallback for legacy data)
    final byName = <String, Map<String, dynamic>>{};
    final byPath = <String, Map<String, dynamic>>{};
    final byTitle = <String, Map<String, dynamic>>{};
    for (final d in docs) {
      final path = d['path'] as String;
      final normalized = p.normalize(path).toLowerCase();
      final withoutExt = normalized.endsWith('.markdown')
          ? normalized.substring(0, normalized.length - '.markdown'.length)
          : normalized.endsWith('.md')
              ? normalized.substring(0, normalized.length - 3)
              : normalized;
      byName.putIfAbsent(p.basename(withoutExt), () => d);
      byPath.putIfAbsent(withoutExt, () => d);
      byTitle.putIfAbsent((d['title'] as String).toLowerCase(), () => d);
    }

    for (final d in docs) {
      final relPath = d['path'] as String;
      final file = File(p.join(rootPath, relPath));
      final String content;
      try {
        content = await file.readAsString();
      } catch (_) {
        continue;
      }
      _parseAndStoreLinks(
        d['id'] as String,
        relPath,
        content,
        byName: byName,
        byPath: byPath,
        byTitle: byTitle,
      );
    }
  }

  /// Recursively collect Markdown files, skipping ignored directories.
  Future<void> _collectFiles(Directory dir, List<File> files) async {
    await for (final entity in dir.list(followLinks: false)) {
      final name = p.basename(entity.path);

      if (entity is Directory) {
        if (name.startsWith('.') && _ignoredDirs.contains(name)) continue;
        if (_ignoredDirs.contains(name)) continue;
        await _collectFiles(entity, files);
      } else if (entity is File) {
        final ext = p.extension(entity.path).toLowerCase();
        if (_supportedExtensions.contains(ext)) {
          files.add(entity);
        }
      }
    }
  }

  /// Extract title from frontmatter or first heading, fallback to filename.
  String _extractTitle(String relativePath, String content) {
    // Try YAML frontmatter title
    if (content.startsWith('---')) {
      final endIdx = content.indexOf('---', 3);
      if (endIdx > 0) {
        final frontmatter = content.substring(3, endIdx);
        final titleMatch = RegExp(r'^title:\s*(.+)$', multiLine: true)
            .firstMatch(frontmatter);
        if (titleMatch != null) {
          return titleMatch.group(1)!.trim().replaceAll(RegExp(r"""^["']|["']$"""), '');
        }
      }
    }

    // Try first heading
    final headingMatch = RegExp(r'^#{1,3}\s+(.+)$', multiLine: true)
        .firstMatch(content);
    if (headingMatch != null) {
      return headingMatch.group(1)!.trim();
    }

    // Fallback to filename without extension
    return p.basenameWithoutExtension(relativePath);
  }

  /// Generate a stable document ID from source and path.
  String _generateDocId(String sourceId, String relativePath) {
    final input = '$sourceId:$relativePath';
    return sha256.convert(utf8.encode(input)).toString().substring(0, 16);
  }

  /// Parse wiki links and markdown links, store in DB.
  void _parseAndStoreLinks(
    String docId,
    String docPath,
    String content, {
    required Map<String, Map<String, dynamic>> byName,
    required Map<String, Map<String, dynamic>> byPath,
    required Map<String, Map<String, dynamic>> byTitle,
  }) {
    db.clearLinksForDocument(docId);

    // Remove code blocks before parsing links
    final cleanContent = _removeCodeBlocks(content);

    // Parse [[wiki links]]
    for (final match in _wikiLinkPattern.allMatches(cleanContent)) {
      // Strip heading/block reference: [[note#heading]] -> note
      final target = match.group(1)!.split('#').first.trim();
      if (target.isEmpty) continue;
      final context = _extractContext(cleanContent, match.start);

      final targetDoc = _resolveWikiLink(
        target,
        byName: byName,
        byPath: byPath,
        byTitle: byTitle,
      );
      if (targetDoc != null && targetDoc['id'] != docId) {
        db.insertLink(
          sourceDocId: docId,
          targetDocId: targetDoc['id'] as String,
          linkText: target,
          linkType: 'wiki',
          context: context,
        );
      }
    }

    // Parse [text](path.md) markdown links
    for (final match in _markdownLinkPattern.allMatches(cleanContent)) {
      final linkPath = match.group(2)!.trim();
      final context = _extractContext(cleanContent, match.start);

      final targetDoc = _resolveMarkdownLink(linkPath, docPath, byPath, byName);
      if (targetDoc != null && targetDoc['id'] != docId) {
        db.insertLink(
          sourceDocId: docId,
          targetDocId: targetDoc['id'] as String,
          linkText: match.group(1)!.trim(),
          linkType: 'markdown',
          context: context,
        );
      }
    }
  }

  /// Resolve a [[wiki link]] target, Obsidian semantics:
  /// 1. file basename without extension (primary)
  /// 2. relative path without extension ([[folder/note]])
  /// 3. document title (fallback, keeps legacy links working)
  Map<String, dynamic>? _resolveWikiLink(
    String target, {
    required Map<String, Map<String, dynamic>> byName,
    required Map<String, Map<String, dynamic>> byPath,
    required Map<String, Map<String, dynamic>> byTitle,
  }) {
    final key = target.toLowerCase();
    final normalized = p.normalize(key);
    return byName[p.basename(normalized)] ??
        byPath[normalized] ??
        byTitle[key];
  }

  /// Parse tags from content and frontmatter, store in DB.
  void _parseAndStoreTags(String docId, String content) {
    db.clearTagsForDocument(docId);
    final tags = <String>{};

    // Parse YAML frontmatter tags
    if (content.startsWith('---')) {
      final endIdx = content.indexOf('---', 3);
      if (endIdx > 0) {
        final frontmatter = content.substring(3, endIdx);

        // tags: [tag1, tag2]
        final inlineMatch = _frontmatterTagsPattern.firstMatch(frontmatter);
        if (inlineMatch != null) {
          final tagList = inlineMatch.group(1)!;
          for (final tag in tagList.split(',')) {
            final cleaned = tag.trim().replaceAll(RegExp(r'''^["']|["']$'''), '');
            if (cleaned.isNotEmpty) tags.add(cleaned);
          }
        }

        // tags:\n  - tag1\n  - tag2
        final listMatch = _frontmatterTagsListPattern.firstMatch(frontmatter);
        if (listMatch != null) {
          final lines = listMatch.group(1)!.split('\n');
          for (final line in lines) {
            final cleaned = line.trim().replaceFirst(RegExp(r'^-\s+'), '');
            if (cleaned.isNotEmpty) tags.add(cleaned);
          }
        }
      }
    }

    // Parse inline #tags (outside code blocks)
    final cleanContent = _removeCodeBlocks(content);
    for (final match in _inlineTagPattern.allMatches(cleanContent)) {
      final tag = match.group(1)!.trim();
      if (tag.isNotEmpty && tag.length > 1) {
        tags.add(tag);
      }
    }

    // Store tags
    for (final tag in tags) {
      final tagId = db.getOrCreateTag(tag);
      db.addTagToDocument(docId, tagId);
    }
  }

  /// Remove code blocks from content to avoid parsing links/tags inside them.
  String _removeCodeBlocks(String content) {
    return content.replaceAll(RegExp(r'```[\s\S]*?```', multiLine: true), '');
  }

  /// Extract surrounding context for a link (for backlink previews).
  String _extractContext(String content, int position) {
    final start = (position - 40).clamp(0, content.length);
    final end = (position + 80).clamp(0, content.length);
    var context = content.substring(start, end).replaceAll('\n', ' ').trim();
    if (start > 0) context = '...$context';
    if (end < content.length) context = '$context...';
    return context;
  }

  /// Resolve a markdown link path to a document.
  ///
  /// Relative links are resolved against the source document's directory;
  /// falls back to basename matching.
  Map<String, dynamic>? _resolveMarkdownLink(
    String linkPath,
    String docPath,
    Map<String, Map<String, dynamic>> byPath,
    Map<String, Map<String, dynamic>> byName,
  ) {
    // Remove anchor
    final path = linkPath.split('#').first.trim();
    if (path.isEmpty) return null;

    String stripExt(String s) {
      final lower = s.toLowerCase();
      if (lower.endsWith('.markdown')) {
        return s.substring(0, s.length - '.markdown'.length);
      }
      if (lower.endsWith('.md')) return s.substring(0, s.length - 3);
      return s;
    }

    // Resolve relative to the source document's directory
    final resolved =
        p.normalize(p.join(p.dirname(docPath), path)).toLowerCase();
    final direct = byPath[stripExt(resolved)];
    if (direct != null) return direct;

    // Fallback: basename match
    return byName[p.basename(stripExt(resolved))];
  }
}
