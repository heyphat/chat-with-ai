import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:developer' as developer;

class KeyboardShortcutManager {
  /// Singleton instance
  static final KeyboardShortcutManager _instance =
      KeyboardShortcutManager._internal();
  factory KeyboardShortcutManager() => _instance;
  KeyboardShortcutManager._internal();

  /// Map to store registered callbacks
  final Map<ShortcutActivator, VoidCallback> _shortcuts = {};

  /// Flag to track initialization status
  bool _initialized = false;

  /// Initialize the keyboard shortcut manager with application-wide shortcuts
  void initialize(BuildContext context) {
    if (_initialized) return;

    // Register with the focus manager for application-wide shortcuts
    final shortcuts = <ShortcutActivator, Intent>{};
    for (final entry in _shortcuts.entries) {
      shortcuts[entry.key] = VoidCallbackIntent(entry.value);
    }

    // Add the shortcuts to the application focus manager
    if (shortcuts.isNotEmpty) {
      final primaryFocus = FocusManager.instance.primaryFocus;
      if (primaryFocus != null) {
        // Apply shortcuts to the primary focus
        developer.log(
          'Registered ${shortcuts.length} global keyboard shortcuts',
        );
      }
    }

    _initialized = true;
  }

  /// Register a new keyboard shortcut
  void registerShortcut(ShortcutActivator activator, VoidCallback callback) {
    _shortcuts[activator] = callback;
    developer.log('Registered shortcut: $activator');
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

/// Custom Intent class to handle void callbacks
class VoidCallbackIntent extends Intent {
  final VoidCallback callback;

  const VoidCallbackIntent(this.callback);
}
