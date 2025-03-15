import 'package:flutter/foundation.dart' show kIsWeb;
// import 'package:flutter/services.dart';
import 'browser_url_manager.dart';

// A dedicated class to handle URL updates in web
class WebUrlHandler {
  // Private singleton constructor
  WebUrlHandler._();

  // Singleton instance
  static final WebUrlHandler _instance = WebUrlHandler._();

  // Factory constructor to return the singleton instance
  factory WebUrlHandler() => _instance;

  // Flag to prevent repeated updates to the same URL
  String? _lastUpdatedUrl;

  // This flag prevents URL clearing during scroll operations
  bool _isUrlLocked = false;

  // Lock the current URL to prevent it from being changed by scrolling
  void lockCurrentUrl() {
    if (kIsWeb && _lastUpdatedUrl != null) {
      _isUrlLocked = true;

      // Only update once to prevent recursive calls
      if (_lastUpdatedUrl != null) {
        BrowserUrlManager.updateUrl(_lastUpdatedUrl!);
      }
    }
  }

  // Unlock the URL when no longer needed
  void unlockUrl() {
    _isUrlLocked = false;
  }

  // Update the URL in a way that persists even after rebuilds
  void updateUrl(String path) {
    if (!kIsWeb) return; // Only relevant for web

    // Don't update if URL is locked and this is a different URL
    if (_isUrlLocked && _lastUpdatedUrl != null && _lastUpdatedUrl != path) {
      return;
    }

    // Don't update if it's the same URL (prevents flickering)
    if (_lastUpdatedUrl == path) return;

    // Track the last updated URL
    _lastUpdatedUrl = path;

    // Use our more reliable BrowserUrlManager
    BrowserUrlManager.updateUrl(path);
  }

  // Method to explicitly get the current URL
  String? getCurrentUrl() {
    if (kIsWeb) {
      return BrowserUrlManager.getCurrentPath();
    }
    return _lastUpdatedUrl;
  }
}

// Global convenience instance
final webUrlHandler = WebUrlHandler();
