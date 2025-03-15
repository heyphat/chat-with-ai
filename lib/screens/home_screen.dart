import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import '../models/chat.dart';
import '../providers/chat_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/chat_sidebar.dart';
import '../widgets/chat_message_list.dart';
import '../widgets/message_input.dart';
import '../widgets/keyboard_shortcuts_help.dart';
// import '../router/web_url_handler.dart';
import '../router/browser_url_manager.dart';
import 'settings_screen.dart';
import 'dart:developer' as developer;

// Use a global variable to preserve sidebar state across navigations
// This ensures the sidebar state is maintained when switching between chats
bool _globalShowSidebar = false;

class HomeScreen extends StatefulWidget {
  final VoidCallback? routeToSettings;
  final VoidCallback? routeToChatHistory;
  final void Function(String)? routeToChatDetail;

  const HomeScreen({
    super.key,
    this.routeToSettings,
    this.routeToChatHistory,
    this.routeToChatDetail,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  // Add FocusNode for the message input
  final FocusNode _messageInputFocusNode = FocusNode();
  bool _showSidebar = false;
  bool _isLoadingChat = false;
  // Track the last active chat ID to prevent unnecessary state changes
  String? _lastActiveChatId;

  // Add FocusNode to handle keyboard shortcuts
  final FocusNode _keyboardFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    // Register for lifecycle events
    WidgetsBinding.instance.addObserver(this);

    // Use the global sidebar state
    _showSidebar = _globalShowSidebar;

    // Add this to initialize with a new chat when no history
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Check if the widget is still mounted before accessing context
      if (!mounted) return;

      final chatProvider = Provider.of<ChatProvider>(context, listen: false);

      // If there are no chats, automatically create a new one and keep sidebar closed
      if (chatProvider.chatMetadata.isEmpty) {
        // Create a new chat with default OpenAI model
        final AIProvider defaultProvider = AIProvider.openai;
        final String defaultModel = ChatProvider.openAIModels.keys.first;

        // Create the chat and get the new chat ID
        final newChatId = await chatProvider.createChat(
          defaultProvider,
          defaultModel,
        );

        // Initialize global state to closed for new users
        _globalShowSidebar = false;
        _showSidebar = false;

        // Now update the URL with the new chat ID
        if (kIsWeb) {
          final chatUrl = '/chats/$newChatId';
          BrowserUrlManager.updateUrl(chatUrl);

          // Update tracking variable
          _lastActiveChatId = newChatId;
        }
      }

      // Request focus for keyboard shortcuts
      _ensureKeyboardFocus();
    });
  }

  @override
  void dispose() {
    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);

    _messageController.dispose();
    _messageInputFocusNode.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  // Lifecycle method to handle app state changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    developer.log('App lifecycle state changed: $state');

    // When app is resumed, ensure keyboard focus is restored
    if (state == AppLifecycleState.resumed) {
      _ensureKeyboardFocus();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Request focus when dependencies change, which happens on navigation changes
    _ensureKeyboardFocus();
  }

  // Helper method to ensure keyboard focus is properly set
  void _ensureKeyboardFocus() {
    if (mounted && _keyboardFocusNode.canRequestFocus) {
      developer.log('Requesting keyboard focus');
      // Use a short delay to ensure focus is requested after the UI is fully rendered
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && _keyboardFocusNode.canRequestFocus) {
          _keyboardFocusNode.requestFocus();
        }
      });
    }
  }

  void _toggleSidebar() {
    setState(() {
      _showSidebar = !_showSidebar;
      _globalShowSidebar = _showSidebar; // Update global state when toggled
    });
  }

  // Focus on the message input
  void _focusMessageInput() {
    if (_messageInputFocusNode.canRequestFocus) {
      _messageInputFocusNode.requestFocus();
    }
  }

  // Handle keyboard shortcuts globally
  KeyEventResult _handleKeyboardShortcuts(FocusNode node, KeyEvent event) {
    // Handle Cmd+B for toggling sidebar
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.keyB &&
        (HardwareKeyboard.instance.isMetaPressed ||
            HardwareKeyboard.instance.isControlPressed)) {
      _toggleSidebar();
      return KeyEventResult.handled;
    }

    // Handle Cmd+I for focusing on message input (changed from Cmd+F)
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.keyI &&
        (HardwareKeyboard.instance.isMetaPressed ||
            HardwareKeyboard.instance.isControlPressed)) {
      _focusMessageInput();
      return KeyEventResult.handled;
    }

    // Handle Cmd+Shift+N for creating a new chat
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.keyN &&
        HardwareKeyboard.instance.isShiftPressed &&
        (HardwareKeyboard.instance.isMetaPressed ||
            HardwareKeyboard.instance.isControlPressed)) {
      _showNewChatDialog();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  // Wrapper for setActiveChat to show loading state
  Future<void> _setActiveChat(String chatId) async {
    // Skip if we're already on this chat
    if (_lastActiveChatId == chatId) return;

    // Only set loading state without changing sidebar
    setState(() {
      _isLoadingChat = true;
    });

    try {
      // Use the router if available, otherwise directly set active chat
      if (widget.routeToChatDetail != null) {
        widget.routeToChatDetail!(chatId);
      } else {
        final chatProvider = Provider.of<ChatProvider>(context, listen: false);
        await chatProvider.setActiveChat(chatId);

        // Only update URL here if we're not using the router
        if (kIsWeb) {
          final chatUrl = '/chats/$chatId';
          BrowserUrlManager.updateUrl(chatUrl);
        }
      }

      // Update tracking variable
      _lastActiveChatId = chatId;
    } finally {
      setState(() {
        _isLoadingChat = false;
      });
    }
  }

  void _showNewChatDialog() async {
    // Create a new chat directly with the default OpenAI model
    final AIProvider defaultProvider = AIProvider.openai;
    final String defaultModel = ChatProvider.openAIModels.keys.first;
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    // Create new chat and get the new chat ID
    final newChatId = await chatProvider.createChat(
      defaultProvider,
      defaultModel,
    );

    // Update the URL after chat creation
    if (kIsWeb) {
      final chatUrl = '/chats/$newChatId';
      BrowserUrlManager.updateUrl(chatUrl);

      // Update tracking variable
      _lastActiveChatId = newChatId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    // We don't need to update tracking variable here anymore with global state approach

    // Ensure the widget can request focus
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureKeyboardFocus();
    });

    // Wrap the entire screen with a Focus widget to capture keyboard shortcuts
    return Focus(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      canRequestFocus: true,
      onFocusChange: (hasFocus) {
        if (!hasFocus) {
          // If focus is lost, try to recapture it after a short delay
          // This helps with scenarios where focus might be temporarily lost
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted && _keyboardFocusNode.canRequestFocus) {
              _keyboardFocusNode.requestFocus();
            }
          });
        } else {
          developer.log('Focus node has focus');
        }
      },
      onKeyEvent: _handleKeyboardShortcuts,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          // Prevent app bar color/elevation changes during scrolling
          scrolledUnderElevation:
              0, // Set to 0 to prevent elevation change on scroll
          backgroundColor:
              Theme.of(
                context,
              ).scaffoldBackgroundColor, // Match with scaffold background
          surfaceTintColor:
              Colors
                  .transparent, // Remove surface tint that can cause color shifts
          elevation: 0, // Set a consistent elevation
          title:
              chatProvider.activeChat != null
                  ? InkWell(
                    onTap: () {
                      // Show dropdown menu for AI provider selection
                      final RenderBox button =
                          context.findRenderObject() as RenderBox;
                      final RenderBox overlay =
                          Overlay.of(context).context.findRenderObject()
                              as RenderBox;
                      final RelativeRect position = RelativeRect.fromRect(
                        Rect.fromPoints(
                          button.localToGlobal(Offset.zero, ancestor: overlay),
                          button.localToGlobal(
                            button.size.bottomRight(Offset.zero),
                            ancestor: overlay,
                          ),
                        ),
                        Offset.zero & overlay.size,
                      );

                      showMenu<Map<String, dynamic>>(
                        context: context,
                        position: position,
                        items: _buildProviderMenuItems(),
                        elevation: 8,
                      ).then((item) {
                        if (item != null) {
                          final AIProvider provider = item['provider'];
                          final String model = item['model'];
                          chatProvider.updateChatProvider(provider, model);

                          // Preserve URL state after changing model
                          if (kIsWeb) {
                            // Add a small delay to ensure provider updates first
                            Future.delayed(
                              const Duration(milliseconds: 50),
                              () {
                                BrowserUrlManager.preserveUrlState();
                              },
                            );
                          }
                        }
                      });
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _getProviderIcon(chatProvider.activeChat!.provider),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'AI Chat - ${chatProvider.activeChat?.title}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down, size: 20),
                      ],
                    ),
                  )
                  : const Text('AI Chat'),
          leading: IconButton(
            icon: Icon(_showSidebar ? Icons.menu_open : Icons.menu),
            onPressed: _toggleSidebar,
          ),
          actions: [
            // Add the keyboard shortcuts help button
            const KeyboardShortcutsHelp(),
            IconButton(
              icon: Icon(
                themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
              ),
              onPressed: themeProvider.toggleTheme,
              tooltip: 'Toggle Theme',
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                if (widget.routeToSettings != null) {
                  widget.routeToSettings!();

                  // Preserve URL state when navigating to settings
                  if (kIsWeb) {
                    Future.delayed(const Duration(milliseconds: 50), () {
                      BrowserUrlManager.preserveUrlState();
                    });
                  }
                } else {
                  // Fallback to direct navigation if router not provided
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  ).then((_) {
                    // Preserve URL state after returning from settings
                    if (kIsWeb) {
                      BrowserUrlManager.preserveUrlState();
                    }
                  });
                }
              },
              tooltip: 'Settings',
            ),
          ],
        ),
        body: Row(
          children: [
            // Sidebar with shadow
            if (_showSidebar)
              SizedBox(
                width: 280,
                child: Material(
                  elevation: 4,
                  color: Theme.of(context).scaffoldBackgroundColor,
                  shadowColor: Theme.of(context).shadowColor.withOpacity(0.3),
                  child: ChatSidebar(
                    onNewChat: _showNewChatDialog,
                    onChatSelected: _setActiveChat,
                    onChatHistoryPressed: widget.routeToChatHistory,
                  ),
                ),
              ),

            // Main content area with message input overlay
            Expanded(
              child: Stack(
                children: [
                  // Messages list with padding
                  Positioned.fill(
                    child: Column(
                      children: [
                        Expanded(
                          child:
                              _isLoadingChat
                                  ? const Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircularProgressIndicator(),
                                        SizedBox(height: 16),
                                        Text('Loading chat...'),
                                      ],
                                    ),
                                  )
                                  : chatProvider.activeChat != null
                                  ? Padding(
                                    padding: const EdgeInsets.only(bottom: 80),
                                    child: ChatMessageList(
                                      messages:
                                          chatProvider.activeChat!.messages,
                                    ),
                                  )
                                  : const Center(
                                    child: Text(
                                      'No active chat. Create a new chat to start.',
                                    ),
                                  ),
                        ),
                      ],
                    ),
                  ),

                  // Message input positioned at the bottom
                  if (chatProvider.activeChat != null && !_isLoadingChat)
                    Positioned(
                      left:
                          _showSidebar
                              ? 4
                              : 0, // Add 4px offset when sidebar is open to show shadow
                      right: 0,
                      bottom: 0,
                      child: Material(
                        elevation: 0,
                        color: Colors.transparent,
                        shadowColor: Colors.transparent,
                        child: MessageInput(
                          controller: _messageController,
                          focusNode:
                              _messageInputFocusNode, // Pass focus node to MessageInput
                          onSend: (message) {
                            chatProvider.sendMessage(message);
                            _messageController.clear();
                          },
                          isLoading: chatProvider.isLoading,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper function to get the icon for the current AI provider
  Widget _getProviderIcon(AIProvider provider) {
    IconData iconData;
    Color iconColor;

    switch (provider) {
      case AIProvider.openai:
        iconData = Icons.chat_bubble_outline;
        iconColor = Colors.green;
        break;
      case AIProvider.anthropic:
        iconData = Icons.psychology;
        iconColor = Colors.purple;
        break;
      case AIProvider.gemini:
        iconData = Icons.science;
        iconColor = Colors.blue;
        break;
    }

    return Icon(iconData, color: iconColor);
  }

  // Build menu items for AI providers
  List<PopupMenuEntry<Map<String, dynamic>>> _buildProviderMenuItems() {
    List<PopupMenuEntry<Map<String, dynamic>>> allItems = [];

    // OpenAI models
    allItems.add(
      const PopupMenuItem<Map<String, dynamic>>(
        enabled: false,
        child: Text(
          'OpenAI Models',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );

    allItems.addAll(
      ChatProvider.openAIModels.entries
          .map(
            (entry) => PopupMenuItem<Map<String, dynamic>>(
              value: {'provider': AIProvider.openai, 'model': entry.key},
              child: Text(entry.value),
            ),
          )
          .toList(),
    );

    // Anthropic models
    allItems.add(
      const PopupMenuItem<Map<String, dynamic>>(
        enabled: false,
        child: Text(
          'Anthropic Models',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );

    allItems.addAll(
      ChatProvider.anthropicModels.entries
          .map(
            (entry) => PopupMenuItem<Map<String, dynamic>>(
              value: {'provider': AIProvider.anthropic, 'model': entry.key},
              child: Text(entry.value),
            ),
          )
          .toList(),
    );

    // Gemini models
    allItems.add(
      const PopupMenuItem<Map<String, dynamic>>(
        enabled: false,
        child: Text(
          'Gemini Models',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );

    allItems.addAll(
      ChatProvider.geminiModels.entries
          .map(
            (entry) => PopupMenuItem<Map<String, dynamic>>(
              value: {'provider': AIProvider.gemini, 'model': entry.key},
              child: Text(entry.value),
            ),
          )
          .toList(),
    );

    return allItems;
  }
}
