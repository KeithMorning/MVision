import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show SingleActivator;

/// Platform-aware keyboard shortcut helpers.
///
/// On macOS/iOS the primary modifier is Cmd (meta);
/// on Windows/Linux/HarmonyOS it is Ctrl (control).
class PlatformKeys {
  PlatformKeys._();

  /// Whether the current platform uses Cmd as the primary modifier.
  static bool get isApple =>
      !kIsWeb && (Platform.isMacOS || Platform.isIOS);

  /// Display symbol for the primary modifier on this platform.
  static String get modifierSymbol => isApple ? '⌘' : 'Ctrl';

  /// Build a [SingleActivator] using the platform's primary modifier.
  ///
  /// Example: `PlatformKeys.activate(LogicalKeyboardKey.keyS)`
  /// maps to Cmd+S on macOS and Ctrl+S on Windows.
  static SingleActivator activate(
    LogicalKeyboardKey key, {
    bool shift = false,
    bool alt = false,
  }) {
    return SingleActivator(
      key,
      meta: isApple,
      control: !isApple,
      shift: shift,
      alt: alt,
    );
  }

  /// Format a shortcut label for display, e.g. `⌘1` or `Ctrl+1`.
  static String label(String key) =>
      isApple ? '$modifierSymbol$key' : '$modifierSymbol+$key';
}
