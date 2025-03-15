import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../screens/home_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/chat_history_screen.dart';
import '../providers/chat_provider.dart';
// import 'web_url_handler.dart';
import 'browser_url_manager.dart'; // Import our more reliable manager

// Route paths
class AppRoutes {
  static const String home = '/';
  static const String settings = '/settings';
  static const String chatHistory = '/chats';
  static const String chatDetail = '/chats/:chatId';

  // Helper method to generate a chat detail route
  static String getChatDetailRoute(String chatId) => '/chats/$chatId';

  // Helper method to parse path directly from browser URL
  static RouteConfiguration parsePathFromBrowser() {
    if (!kIsWeb) {
      return RouteConfiguration(path: home);
    }

    try {
      // Get the full URL from the browser
      final String fullUrl = BrowserUrlManager.getCurrentUrl();
      final Uri uri = Uri.parse(fullUrl);
      final String path = uri.path.isEmpty ? '/' : uri.path;

      // Extract chat ID if present
      String? chatId;
      final pathSegments = uri.pathSegments;

      if (pathSegments.length >= 2 && pathSegments[0] == 'chats') {
        chatId = pathSegments[1];
      }

      return RouteConfiguration(path: path, chatId: chatId);
    } catch (e) {
      print('Error parsing URL from browser: $e');
      return RouteConfiguration(path: home);
    }
  }
}

// Application router configuration
class AppRouter extends RouterDelegate<RouteConfiguration>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<RouteConfiguration> {
  final GlobalKey<NavigatorState> _navigatorKey;
  final ChatProvider chatProvider;

  AppRouter({required this.chatProvider})
    : _navigatorKey = GlobalKey<NavigatorState>() {
    // Listen to changes in the chat provider
    chatProvider.addListener(notifyListeners);

    // Initialize from browser URL if on web
    if (kIsWeb) {
      _initializeFromBrowserUrl();
    }
  }

  // Initialize the router from the current browser URL
  void _initializeFromBrowserUrl() {
    // Use a post-frame callback to ensure we're not in the build phase
    Future.delayed(Duration.zero, () {
      try {
        final config = AppRoutes.parsePathFromBrowser();
        final newPath = config.path;
        final newChatId = config.chatId;

        if (newPath != _currentPath || newChatId != _selectedChatId) {
          _currentPath = newPath;
          _selectedChatId = newChatId;

          // Set active chat if we have a chat ID
          if (_selectedChatId != null) {
            chatProvider.setActiveChat(_selectedChatId!);
          }

          print(
            'Router initialized from browser URL: path=$newPath, chatId=$newChatId',
          );
        }
      } catch (e) {
        print('Error initializing from browser URL: $e');
      }
    });
  }

  @override
  GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;

  // Current path
  String _currentPath = AppRoutes.home;
  String? _selectedChatId;

  // Getters and setters for current path
  String get currentPath => _currentPath;
  String? get selectedChatId => _selectedChatId;

  // Navigate to a different route
  void navigateTo(String path) {
    _currentPath = path;
    // Extract chatId if this is a chat detail route
    if (path.startsWith('/chats/') && path.length > 7) {
      _selectedChatId = path.substring(7);
      if (_selectedChatId != null) {
        chatProvider.setActiveChat(_selectedChatId!);
      }
    } else {
      // Only clear the chatId if we're not on a chat route
      // But preserve it in memory if we're navigating to settings
      if (_currentPath != AppRoutes.settings) {
        _selectedChatId = null;
      }
    }

    // Directly update the browser URL if on web
    if (kIsWeb) {
      print('Router.navigateTo: Updating URL to $path');

      // If navigating to settings while having a chat selected, use our preservation method
      if (_currentPath == AppRoutes.settings && _selectedChatId != null) {
        // First navigate to settings, then restore the chat ID in the URL
        BrowserUrlManager.updateUrl(path);
        Future.delayed(Duration(milliseconds: 50), () {
          BrowserUrlManager.preserveUrlState();
        });
      } else {
        BrowserUrlManager.updateUrl(path);
      }
    }

    notifyListeners();
  }

  // Navigate to chat detail
  void navigateToChatDetail(String chatId) {
    // Ensure we're on the home path with the selected chat ID
    // This will make sure navigation from chat history goes back to home
    _currentPath = AppRoutes.home; // Always go to home path first
    _selectedChatId = chatId;

    // Then update active chat in the provider
    chatProvider.setActiveChat(chatId);

    // Directly update the browser URL if on web
    if (kIsWeb) {
      final String path = '/chats/$chatId';
      print('Router.navigateToChatDetail: Updating URL to $path');
      BrowserUrlManager.updateUrl(path);
    }

    notifyListeners();
  }

  // Navigate back
  void pop() {
    if (_currentPath != AppRoutes.home) {
      _currentPath = AppRoutes.home;
      _selectedChatId = null;
      notifyListeners();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      pages: _getPages(),
      onPopPage: (route, result) {
        if (!route.didPop(result)) {
          return false;
        }
        pop();
        return true;
      },
    );
  }

  List<Page> _getPages() {
    final List<Page> pages = [];

    // Always add home page at the bottom of the stack
    pages.add(
      MaterialPage(
        key: const ValueKey('HomeScreen'),
        child: HomeScreen(
          routeToSettings: () => navigateTo(AppRoutes.settings),
          routeToChatHistory: () => navigateTo(AppRoutes.chatHistory),
          routeToChatDetail: navigateToChatDetail,
        ),
      ),
    );

    // Add additional pages based on the current path
    if (_currentPath == AppRoutes.settings) {
      pages.add(
        MaterialPage(
          key: const ValueKey('SettingsScreen'),
          child: const SettingsScreen(),
        ),
      );
    } else if (_currentPath == AppRoutes.chatHistory) {
      pages.add(
        MaterialPage(
          key: const ValueKey('ChatHistoryScreen'),
          child: const ChatHistoryScreen(),
        ),
      );
    } else if (_currentPath.startsWith('/chats/') && _selectedChatId != null) {
      // This will be handled by the HomeScreen with the selected chat
      // No need to add a separate page as the HomeScreen displays the chat
    }

    return pages;
  }

  @override
  Future<void> setNewRoutePath(RouteConfiguration configuration) async {
    // Check if the path is actually changing to prevent unnecessary updates
    final newPath = configuration.path;
    final newChatId = configuration.chatId;

    if (newPath != _currentPath || newChatId != _selectedChatId) {
      _currentPath = newPath;
      _selectedChatId = newChatId;

      if (_selectedChatId != null) {
        await chatProvider.setActiveChat(_selectedChatId!);
      }

      // Update the URL if changed
      if (kIsWeb) {
        BrowserUrlManager.updateUrl(newPath);
      }

      // Notify listeners about the route change
      notifyListeners();
    }

    return;
  }

  @override
  RouteConfiguration? get currentConfiguration {
    return RouteConfiguration(path: _currentPath, chatId: _selectedChatId);
  }
}

// Route configuration for handling path information
class RouteConfiguration {
  final String path;
  final String? chatId;

  RouteConfiguration({required this.path, this.chatId});
}

// RouteInformationParser implementation
class AppRouteInformationParser
    extends RouteInformationParser<RouteConfiguration> {
  @override
  Future<RouteConfiguration> parseRouteInformation(
    RouteInformation routeInformation,
  ) async {
    final uri = Uri.parse(routeInformation.uri.toString());
    final pathSegments = uri.pathSegments;

    // Default route
    if (pathSegments.isEmpty) {
      return RouteConfiguration(path: AppRoutes.home);
    }

    // Handle settings route
    if (pathSegments.length == 1 && pathSegments[0] == 'settings') {
      return RouteConfiguration(path: AppRoutes.settings);
    }

    // Handle chat history route
    if (pathSegments.length == 1 && pathSegments[0] == 'chats') {
      return RouteConfiguration(path: AppRoutes.chatHistory);
    }

    // Handle chat detail route
    if (pathSegments.length == 2 && pathSegments[0] == 'chats') {
      final chatId = pathSegments[1];
      return RouteConfiguration(path: '/chats/$chatId', chatId: chatId);
    }

    // Default to home for unknown routes
    return RouteConfiguration(path: AppRoutes.home);
  }

  @override
  RouteInformation restoreRouteInformation(RouteConfiguration configuration) {
    // Convert the configuration back to a URL
    final path = configuration.path;
    return RouteInformation(uri: Uri.parse(path));
  }
}
