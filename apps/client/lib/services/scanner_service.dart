import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'database_service.dart';

/// Scans a local directory for Markdown files and indexes them.
class ScannerService {
  final DatabaseService db;

  ScannerService({required this.db});

  /// Extensions we consider as documents.
  static const _supportedExtensions = {'.md', '.markdown'};

  /// Directories to skip during scanning.
  static const _ignoredDirs = {
    '.git', '.svn', '.hg',
    'node_modules', '.dart_tool', '.build',
    '.mvision', '__pycache__', '.Trash',
  };

  /// Scan progress callback.
  void Function(int processed, int total)? onProgress;

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

        updated++;
      } catch (e) {
        // Skip files that can't be read
        continue;
      }

      onProgress?.call(i + 1, files.length);
    }

    db.updateSourceLastScanned(sourceId);
    return updated;
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
}
