import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../providers/chat_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/chat_sidebar.dart';
import '../widgets/chat_message_list.dart';
import '../widgets/message_input.dart';
import 'settings_screen.dart';
import 'chat_history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _messageController = TextEditingController();
  bool _showSidebar = true;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _toggleSidebar() {
    setState(() {
      _showSidebar = !_showSidebar;
    });
  }

  void _showNewChatDialog() {
    showDialog(
      context: context,
      builder: (context) {
        AIProvider selectedProvider = AIProvider.openai;
        String selectedModel = ChatProvider.openAIModels.keys.first;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('New Chat'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select AI Provider:'),
                  const SizedBox(height: 8),
                  DropdownButton<AIProvider>(
                    value: selectedProvider,
                    isExpanded: true,
                    onChanged: (value) {
                      setState(() {
                        selectedProvider = value!;
                        // Update model based on provider
                        switch (selectedProvider) {
                          case AIProvider.openai:
                            selectedModel = ChatProvider.openAIModels.keys.first;
                            break;
                          case AIProvider.anthropic:
                            selectedModel = ChatProvider.anthropicModels.keys.first;
                            break;
                          case AIProvider.gemini:
                            selectedModel = ChatProvider.geminiModels.keys.first;
                            break;
                        }
                      });
                    },
                    items: AIProvider.values.map((provider) {
                      return DropdownMenuItem(
                        value: provider,
                        child: Text(provider.name),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text('Select Model:'),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    value: selectedModel,
                    isExpanded: true,
                    onChanged: (value) {
                      setState(() {
                        selectedModel = value!;
                      });
                    },
                    items: _getModelItemsForProvider(selectedProvider),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Provider.of<ChatProvider>(context, listen: false)
                        .createChat(selectedProvider, selectedModel);
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<DropdownMenuItem<String>> _getModelItemsForProvider(AIProvider provider) {
    switch (provider) {
      case AIProvider.openai:
        return ChatProvider.openAIModels.entries
            .map((entry) => DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value),
                ))
            .toList();
      case AIProvider.anthropic:
        return ChatProvider.anthropicModels.entries
            .map((entry) => DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value),
                ))
            .toList();
      case AIProvider.gemini:
        return ChatProvider.geminiModels.entries
            .map((entry) => DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value),
                ))
            .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(chatProvider.activeChat?.title != null ? 'AI Chat - ${chatProvider.activeChat?.title}' : 'AI Chat'),
        leading: IconButton(
          icon: Icon(_showSidebar ? Icons.menu_open : Icons.menu),
          onPressed: _toggleSidebar,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ChatHistoryScreen()),
              );
            },
            tooltip: 'Chat History',
          ),
          IconButton(
            icon: Icon(themeProvider.isDarkMode
                ? Icons.light_mode
                : Icons.dark_mode),
            onPressed: themeProvider.toggleTheme,
            tooltip: 'Toggle Theme',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Row(
        children: [
          // Sidebar
          if (_showSidebar)
            SizedBox(
              width: 280,
              child: ChatSidebar(
                onNewChat: _showNewChatDialog,
              ),
            ),
          // Main content
          Expanded(
            child: Column(
              children: [
                // Messages list
                Expanded(
                  child: chatProvider.activeChat != null
                      ? ChatMessageList(
                          messages: chatProvider.activeChat!.messages,
                        )
                      : const Center(
                          child: Text('No active chat. Create a new chat to start.'),
                        ),
                ),
                // Message input
                if (chatProvider.activeChat != null)
                  MessageInput(
                    controller: _messageController,
                    onSend: (message) {
                      chatProvider.sendMessage(message);
                      _messageController.clear();
                    },
                    isLoading: chatProvider.isLoading,
                  ),
              ],
            ),
          ),
        ],
      ),
      //floatingActionButton: !_showSidebar
      //    ? FloatingActionButton(
      //        onPressed: _showNewChatDialog,
      //        tooltip: 'New Chat',
      //        child: const Icon(Icons.add),
      //      )
      //    : null,
    );
  }
} 