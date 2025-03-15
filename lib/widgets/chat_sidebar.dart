import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chat.dart';
import '../providers/chat_provider.dart';
import '../screens/chat_history_screen.dart';

class ChatSidebar extends StatelessWidget {
  final VoidCallback onNewChat;

  const ChatSidebar({
    super.key,
    required this.onNewChat,
  });

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final activeChat = chatProvider.activeChat;
    final chats = chatProvider.chats;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: Column(
        children: [
          // New chat button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onNewChat,
                icon: const Icon(Icons.add),
                label: const Text('New Chat'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                ),
              ),
            ),
          ),
          
          const Divider(),
          
          // Chat list
          Expanded(
            child: chats.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 48,
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No chats yet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Create a new chat to start a conversation',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: onNewChat,
                          icon: const Icon(Icons.add),
                          label: const Text('New Chat'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: chats.length,
                    itemBuilder: (context, index) {
                      final chat = chats[index];
                      final isActive = activeChat?.id == chat.id;
                      
                      return _buildChatItem(
                        context,
                        chat,
                        isActive,
                        chatProvider,
                      );
                    },
                  ),
          ),
          
          // Remove stats and footer section
        ],
      ),
    );
  }

  Widget _buildChatItem(
    BuildContext context,
    Chat chat,
    bool isActive,
    ChatProvider chatProvider,
  ) {
    // Calculate a summary of the chat
    final lastMessage = chat.messages.isNotEmpty 
        ? chat.messages.last.content 
        : 'No messages yet';
    final messagePreview = lastMessage.length > 40 
        ? '${lastMessage.substring(0, 40)}...' 
        : lastMessage;
    
    // Format the date
    final now = DateTime.now();
    final chatDate = chat.updatedAt;
    String dateText;
    
    if (now.difference(chatDate).inDays == 0) {
      // Today - show time
      dateText = '${chatDate.hour.toString().padLeft(2, '0')}:${chatDate.minute.toString().padLeft(2, '0')}';
    } else if (now.difference(chatDate).inDays < 7) {
      // This week - show day name
      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      dateText = days[chatDate.weekday - 1];
    } else {
      // Older - show date
      dateText = '${chatDate.day}/${chatDate.month}';
    }

    return Dismissible(
      key: Key(chat.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16.0),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      confirmDismiss: (direction) async {
        // Show confirmation dialog before deletion
        return await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Delete Chat'),
              content: const Text('Are you sure you want to delete this chat?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ?? false;
      },
      onDismissed: (direction) {
        chatProvider.deleteChat(chat.id);
      },
      child: Container(
        color: isActive ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3) : null,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  chat.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              Text(
                dateText,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      messagePreview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (chat.messages.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${chat.messages.length}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Chip(
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                label: Text(
                  _getModelDisplayName(chat.provider, chat.model),
                  style: const TextStyle(fontSize: 10),
                ),
                avatar: _getProviderIcon(chat.provider),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          selected: isActive,
          onTap: () {
            chatProvider.setActiveChat(chat.id);
          },
          onLongPress: () {
            _showEditTitleDialog(context, chat, chatProvider);
          },
        ),
      ),
    );
  }

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

    return Icon(
      iconData,
      color: iconColor,
      size: 14,
    );
  }

  String _getModelDisplayName(AIProvider provider, String modelId) {
    switch (provider) {
      case AIProvider.openai:
        return ChatProvider.openAIModels[modelId] ?? modelId;
      case AIProvider.anthropic:
        return ChatProvider.anthropicModels[modelId] ?? modelId;
      case AIProvider.gemini:
        return ChatProvider.geminiModels[modelId] ?? modelId;
    }
  }

  void _showEditTitleDialog(
    BuildContext context,
    Chat chat,
    ChatProvider chatProvider,
  ) {
    final controller = TextEditingController(text: chat.title);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Chat Title'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final newTitle = controller.text.trim();
                if (newTitle.isNotEmpty) {
                  chatProvider.updateChatTitle(chat.id, newTitle);
                }
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
} 