import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';

class KeyboardShortcutManager {
  /// Singleton instance
  static final KeyboardShortcutManager _instance =
      KeyboardShortcutManager._internal();
  factory KeyboardShortcutManager() => _instance;
  KeyboardShortcutManager._internal();

  /// Map to store registered callbacks
  final Map<ShortcutActivator, VoidCallback> _shortcuts = {};

  /// Register a new keyboard shortcut
  void registerShortcut(ShortcutActivator activator, VoidCallback callback) {
    _shortcuts[activator] = callback;
  }

  /// Remove a keyboard shortcut
  void unregisterShortcut(ShortcutActivator activator) {
    _shortcuts.remove(activator);
  }

  /// Get the current shortcuts map
  Map<ShortcutActivator, VoidCallback> get shortcuts =>
      Map.unmodifiable(_shortcuts);

  /// Clear all shortcuts
  void clearShortcuts() {
    _shortcuts.clear();
  }
}
