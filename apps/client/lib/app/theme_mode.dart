import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Theme mode state provider.
///
/// Defaults to [ThemeMode.system]; overridden at app startup with the
/// persisted value (see [loadThemeMode]).
final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier(ThemeMode.system);
});

/// Holds the current [ThemeMode] and persists changes to a local JSON file,
/// same pattern as the AI config (app support directory).
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(super.initial);

  static const _fileName = 'theme_config.json';

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, _fileName));
  }

  /// Change the theme mode and persist it.
  Future<void> setMode(ThemeMode mode) async {
    if (mode == state) return;
    state = mode;
    try {
      final file = await _file();
      file.writeAsStringSync(jsonEncode({'mode': mode.name}));
    } catch (_) {
      // Persistence failure is non-fatal: keep the in-memory mode.
    }
  }
}

/// Load the persisted theme mode at app startup.
///
/// Returns [ThemeMode.system] when no config exists or it is unreadable.
Future<ThemeMode> loadThemeMode() async {
  try {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, ThemeModeNotifier._fileName));
    if (!file.existsSync()) return ThemeMode.system;
    final json = jsonDecode(file.readAsStringSync());
    final name = json['mode'] as String?;
    return ThemeMode.values.asNameMap()[name] ?? ThemeMode.system;
  } catch (_) {
    return ThemeMode.system;
  }
}
