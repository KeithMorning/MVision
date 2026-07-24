import 'dart:io';
import 'dart:typed_data';

/// Abstract interface for platform file access.
///
/// Provides sandboxed file access and directory picking.
abstract interface class FileAccess {
  /// Pick a directory from the user.
  Future<String?> pickDirectory();

  /// Get the application documents directory.
  Future<Directory> getAppDocumentsDirectory();

  /// Get the application support directory.
  Future<Directory> getAppSupportDirectory();

  /// Get the temporary directory.
  Future<Directory> getTempDirectory();

  /// Check if a path exists.
  Future<bool> exists(String path);

  /// Read file as bytes.
  Future<Uint8List> readAsBytes(String path);

  /// Write bytes to file.
  Future<void> writeAsBytes(String path, Uint8List data);

  /// Delete a file.
  Future<void> delete(String path);

  /// Create a directory.
  Future<Directory> createDirectory(String path);
}
