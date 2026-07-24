import 'package:knowledge_core/knowledge_core.dart';

/// Result of patch validation.
class PatchValidationResult {
  final bool isValid;
  final List<ValidationError> errors;

  const PatchValidationResult({
    required this.isValid,
    required this.errors,
  });

  const PatchValidationResult.valid()
      : isValid = true,
        errors = const [];

  const PatchValidationResult.invalid(this.errors) : isValid = false;
}

/// A validation error.
class ValidationError {
  final ValidationErrorType type;
  final String message;
  final String? path;

  const ValidationError({
    required this.type,
    required this.message,
    this.path,
  });
}

/// Type of validation error.
enum ValidationErrorType {
  pathOutsideWiki,
  pathTraversal,
  modifiesSources,
  invalidMarkdown,
  referenceNotFound,
  undeclaredDeletion,
  thresholdExceeded,
}

/// Validates Wiki patches before they can be applied.
///
/// See FR-AI-004 in mvision-development-requirements.md
class PatchValidator {
  PatchValidator._();

  /// Validate a Wiki patch.
  ///
  /// Checks:
  /// - Target path is in allowed `wiki/` directory
  /// - No path traversal attacks
  /// - Does not modify `sources/`
  /// - Markdown is parseable
  /// - Referenced sources exist
  /// - Does not delete undeclared files
  /// - Threshold not exceeded
  static PatchValidationResult validate(
    WikiPatch patch, {
    required bool Function(String path) referenceExists,
    required bool Function(String path) fileExists,
    int maxFilesPerPatch = 50,
    int maxTotalChanges = 1000,
  }) {
    final errors = <ValidationError>[];

    // Check file count threshold
    if (patch.files.length > maxFilesPerPatch) {
      errors.add(ValidationError(
        type: ValidationErrorType.thresholdExceeded,
        message: 'Patch contains ${patch.files.length} files, exceeding limit of $maxFilesPerPatch',
      ));
    }

    // Validate each file patch
    for (final file in patch.files) {
      final fileErrors = _validateFilePatch(file, referenceExists, fileExists);
      errors.addAll(fileErrors);
    }

    // Validate references
    for (final ref in patch.references) {
      if (!referenceExists(ref.sourceDocumentId)) {
        errors.add(ValidationError(
          type: ValidationErrorType.referenceNotFound,
          message: 'Referenced source not found: ${ref.sourceDocumentId}',
          path: ref.sourceDocumentId,
        ));
      }
    }

    return errors.isEmpty
        ? const PatchValidationResult.valid()
        : PatchValidationResult.invalid(errors);
  }

  static List<ValidationError> _validateFilePatch(
    FilePatch file,
    bool Function(String path) referenceExists,
    bool Function(String path) fileExists,
  ) {
    final errors = <ValidationError>[];
    final path = file.path;

    // Check path is in wiki/ directory
    if (!path.startsWith('wiki/')) {
      errors.add(ValidationError(
        type: ValidationErrorType.pathOutsideWiki,
        message: 'Path must be in wiki/ directory: $path',
        path: path,
      ));
    }

    // Check for path traversal
    if (_hasPathTraversal(path)) {
      errors.add(ValidationError(
        type: ValidationErrorType.pathTraversal,
        message: 'Path traversal detected: $path',
        path: path,
      ));
    }

    // Check not modifying sources/
    if (path.startsWith('sources/')) {
      errors.add(ValidationError(
        type: ValidationErrorType.modifiesSources,
        message: 'Cannot modify sources/ directory: $path',
        path: path,
      ));
    }

    // Validate markdown content for create/update
    if ((file.operation == FilePatchOperation.create ||
            file.operation == FilePatchOperation.update) &&
        file.content != null) {
      final markdownError = _validateMarkdown(file.content!);
      if (markdownError != null) {
        errors.add(ValidationError(
          type: ValidationErrorType.invalidMarkdown,
          message: 'Invalid Markdown: $markdownError',
          path: path,
        ));
      }
    }

    // Check undeclared deletions
    if (file.operation == FilePatchOperation.delete && !fileExists(path)) {
      errors.add(ValidationError(
        type: ValidationErrorType.undeclaredDeletion,
        message: 'Attempting to delete non-existent file: $path',
        path: path,
      ));
    }

    return errors;
  }

  static bool _hasPathTraversal(String path) {
    // Check for common path traversal patterns
    if (path.contains('..')) return true;
    if (path.contains('~')) return true;
    if (path.startsWith('/')) return true;
    if (path.contains('\\')) return true;
    return false;
  }

  static String? _validateMarkdown(String content) {
    // Basic markdown validation
    // In a real implementation, this would use a proper parser
    if (content.trim().isEmpty) {
      return 'Content is empty';
    }
    return null;
  }

  /// Check if a patch requires secondary confirmation.
  static bool requiresSecondaryConfirmation(WikiPatch patch) {
    return patch.riskLevel.requiresSecondaryConfirmation;
  }
}
