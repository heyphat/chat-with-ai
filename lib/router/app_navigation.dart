// import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// import 'package:flutter/services.dart';
import 'app_router.dart';
// import 'web_url_handler.dart';
import 'browser_url_manager.dart';

// Helper class for navigation
class AppNavigation {
  static AppRouter? _router;

  // Initialize with the app router
  static void init(AppRouter router) {
    _router = router;
  }

  // Update URL using multiple mechanisms for maximum reliability
  static void _updateSystemUrl(String path) {
    if (kIsWeb) {
      // Use only BrowserUrlManager for URL updates
      BrowserUrlManager.updateUrl(path);
    }
  }

  // Navigate to a path
  static void navigateTo(String path) {
    _router?.navigateTo(path);

    // Directly update URL for web
    if (kIsWeb) {
      _updateSystemUrl(path);
    }
  }

  // Navigate to home
  static void toHome() {
    _router?.navigateTo(AppRoutes.home);

    // Directly update URL for web
    if (kIsWeb) {
      _updateSystemUrl('/');
    }
  }

  // Navigate to settings
  static void toSettings() {
    _router?.navigateTo(AppRoutes.settings);

    // Directly update URL for web
    if (kIsWeb) {
      _updateSystemUrl('/settings');
    }
  }

  // Navigate to chat history
  static void toChatHistory() {
    _router?.navigateTo(AppRoutes.chatHistory);

    // Directly update URL for web
    if (kIsWeb) {
      _updateSystemUrl('/chats');
    }
  }

  // Navigate to specific chat
  static void toChat(String chatId) {
    _router?.navigateToChatDetail(chatId);

    // Directly update URL for web - use the chat-specific URL pattern
    // even though internally we're on the home screen
    if (kIsWeb) {
      _updateSystemUrl('/chats/$chatId');
    }
  }

  // Go back
  static void back() {
    _router?.pop();
  }
}
