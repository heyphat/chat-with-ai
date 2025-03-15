import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:js' as js;
import 'dart:async';

/// A more direct and reliable way to manipulate browser URLs
class BrowserUrlManager {
  // Static variable to track the last update time
  static DateTime? _lastUpdateTime;
  // Minimum time between updates to prevent rapid-fire updates
  static const _debounceMs = 300;
  // Flag to prevent recursive updates
  static bool _isUpdating = false;
  // The last URL that was set
  static String? _lastSetUrl;

  /// Updates the browser URL without causing a page navigation
  /// This uses direct JavaScript interop to ensure it works reliably
  static void updateUrl(String url) {
    if (!kIsWeb) return;

    // Sanitize the URL to prevent duplication in path and hash
    url = _sanitizeUrl(url);

    // Get the current URL to compare
    final currentUrl = getCurrentPath();

    // Don't update if it's the same URL (added more robust comparison)
    if (currentUrl == url || _lastSetUrl == url || _isUpdating) {
      print('URL update skipped - same URL or already updating: $url');
      return;
    }

    // Check if we're updating too frequently
    final now = DateTime.now();
    if (_lastUpdateTime != null) {
      final timeSinceLastUpdate =
          now.difference(_lastUpdateTime!).inMilliseconds;
      if (timeSinceLastUpdate < _debounceMs) {
        // Schedule the update for later to avoid excessive updates
        Timer(Duration(milliseconds: _debounceMs - timeSinceLastUpdate), () {
          updateUrl(url);
        });
        return;
      }
    }

    try {
      _isUpdating = true;
      _lastUpdateTime = now;
      _lastSetUrl = url;

      // Use JavaScript interop to directly call the history API
      js.context.callMethod('eval', [
        "window.history.pushState({}, '', '$url');",
      ]);

      // Add console logging for debugging
      print('URL updated to: $url');
    } catch (e) {
      print('Error updating browser URL: $e');
    } finally {
      // Set a timer to reset the updating flag
      Timer(const Duration(milliseconds: 50), () {
        _isUpdating = false;
      });
    }
  }

  /// Updates the URL while preserving the current chat ID if the URL contains one
  /// This is crucial for UI interactions like toggling theme or changing model
  static void preserveUrlState() {
    if (!kIsWeb) return;

    try {
      final currentPath = getCurrentPath();

      // Check if the current path contains a chat ID (path format: /chats/[chatId])
      final pathSegments = Uri.parse(currentPath).pathSegments;
      if (pathSegments.length >= 2 && pathSegments[0] == 'chats') {
        final chatId = pathSegments[1];

        // If we have a valid chat ID, ensure it's in the URL
        if (chatId.isNotEmpty) {
          final chatUrl = '/chats/$chatId';

          // Only update if the current URL doesn't match the expected format
          if (currentPath != chatUrl) {
            print('Preserving chat ID in URL: $chatUrl');
            updateUrl(chatUrl);
          }
        }
      }
    } catch (e) {
      print('Error preserving URL state: $e');
    }
  }

  /// Explicitly preserves a specific chat ID in browser state
  /// This is used when navigating to settings while a chat is selected
  static void preserveChatIdState(String chatId) {
    if (!kIsWeb) return;

    try {
      // Store the chat ID in browser history state
      js.context.callMethod('eval', [
        "window.history.replaceState({'chatId': '$chatId'}, '', window.location.pathname);",
      ]);
      print('Stored chat ID $chatId in browser history state');
    } catch (e) {
      print('Error preserving chat ID state: $e');
    }
  }

  /// Retrieves a chat ID from the browser history state if available
  /// Returns null if no chat ID is found in the state
  static String? getStoredChatId() {
    if (!kIsWeb) return null;

    try {
      // Attempt to get chat ID from state
      final dynamic state = js.context.callMethod('eval', [
        "window.history.state && window.history.state.chatId ? window.history.state.chatId : null",
      ]);

      if (state != null) {
        final String chatId = state.toString();
        print('Retrieved stored chat ID from browser state: $chatId');
        return chatId;
      }
    } catch (e) {
      print('Error getting stored chat ID: $e');
    }
    return null;
  }

  /// Sanitize URL to prevent duplication in path and hash
  static String _sanitizeUrl(String url) {
    try {
      // First, remove any hash from the URL
      if (url.contains('#')) {
        url = url.split('#')[0];
      }

      // Ensure we have a clean, absolute URL path
      if (!url.startsWith('/')) {
        url = '/$url';
      }

      // Avoid potential URL encoding issues with spaces, etc.
      final uri = Uri.parse(url);
      return uri.path;
    } catch (e) {
      print('Error sanitizing URL: $e');
      return url;
    }
  }

  /// Gets the current URL from the browser
  static String getCurrentUrl() {
    if (!kIsWeb) return '';

    try {
      return js.context['location']['href'].toString();
    } catch (e) {
      print('Error getting current URL: $e');
      return '';
    }
  }

  /// Gets just the path portion of the current URL
  static String getCurrentPath() {
    if (!kIsWeb) return '/';

    try {
      final url = getCurrentUrl();
      final uri = Uri.parse(url);
      return uri.path.isEmpty ? '/' : uri.path;
    } catch (e) {
      print('Error getting current path: $e');
      return '/';
    }
  }

  /// Resets the update state - useful if you need to force an update
  static void resetUpdateState() {
    _isUpdating = false;
    _lastUpdateTime = null;
  }
}
