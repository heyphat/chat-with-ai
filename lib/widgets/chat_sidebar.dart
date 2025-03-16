import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/chat.dart';
import '../providers/chat_provider.dart';
import '../screens/chat_history_screen.dart';
import '../router/app_navigation.dart';
// import '../router/browser_url_manager.dart';

// Define swipe actions enum
enum _SwipeAction { delete, copy }

class ChatSidebar extends StatelessWidget {
  final Function(String) onChatSelected;
  final Function onNewChat;
  final VoidCallback? onChatHistoryPressed;

  const ChatSidebar({
    super.key,
    required this.onChatSelected,
    required this.onNewChat,
    this.onChatHistoryPressed,
  });

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final activeChat = chatProvider.activeChat;
    final chats = chatProvider.chatMetadata;

    return Container(
      height: double.infinity,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
      ),
      child: Column(
        children: [
          // New chat button
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 16.0,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    Theme.of(context).brightness == Brightness.dark
                        ? Icons.history
                        : Icons.history,
                  ),
                  // icon: Icons.history,
                  tooltip: 'Chat History',
                  onPressed: () {
                    if (onChatHistoryPressed != null) {
                      onChatHistoryPressed!();
                    } else {
                      // Fallback to direct navigation
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ChatHistoryScreen(),
                        ),
                      );
                    }
                  },
                  // backgroundColor:
                  //     Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => onNewChat(),
                    icon: const Icon(Icons.add),
                    label: const Text('New Chat'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // const Divider(),

          // Chat list
          Expanded(
            child:
                chats.isEmpty
                    ? const Center(child: Text('No chats yet'))
                    : ListView.builder(
                      itemCount: chats.length,
                      itemBuilder: (context, index) {
                        final metadata = chats[index];
                        final isActive = activeChat?.id == metadata.id;

                        // Use a separate stateless widget to memoize chat items
                        return _ChatListItem(
                          key: ValueKey(metadata.id),
                          metadata: metadata,
                          isActive: isActive,
                          onTap: () => onChatSelected(metadata.id),
                          onLongPress:
                              () => _showEditTitleDialog(
                                context,
                                metadata,
                                chatProvider,
                              ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  // void _handleChatTap(BuildContext context, String chatId) {
  //   // Get provider without listening (to avoid rebuild)
  //   final chatProvider = Provider.of<ChatProvider>(context, listen: false);
  //   chatProvider.setActiveChat(chatId);
  // }

  void _showEditTitleDialog(
    BuildContext context,
    ChatMetadata metadata,
    ChatProvider chatProvider,
  ) {
    final controller = TextEditingController(text: metadata.title);

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
                  chatProvider.updateChatTitle(metadata.id, newTitle);
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

// Extract ChatListItem to a separate widget to reduce rebuilds
class _ChatListItem extends StatelessWidget {
  final ChatMetadata metadata;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ChatListItem({
    super.key,
    required this.metadata,
    required this.isActive,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final String dateText = _formatDate(metadata.updatedAt);
    final String messagePreview =
        metadata.lastMessagePreview ?? 'No messages yet';
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    return Dismissible(
      key: ValueKey('dismissible-${metadata.id}'),
      direction:
          DismissDirection.endToStart, // Only allow swipe from right to left
      background: Container(
        color: Colors.transparent,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Delete action
            Container(
              color: Colors.red,
              width: 80,
              alignment: Alignment.center,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.delete, color: Colors.white),
                  Text(
                    'Delete',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
            // Copy action
            Container(
              color: Colors.blue,
              width: 80,
              alignment: Alignment.center,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.copy, color: Colors.white),
                  Text(
                    'Copy',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          // Show action selection dialog
          final action = await _showActionSelectionDialog(
            context,
            chatProvider,
          );
          if (action == _SwipeAction.delete) {
            _showDeleteConfirmation(context, chatProvider);
          } else if (action == _SwipeAction.copy) {
            _handleCopy(context, chatProvider);
          }
        }
        // Always return false to prevent actual dismissal
        return false;
      },
      child: Material(
        color:
            isActive
                ? Theme.of(
                  context,
                ).colorScheme.primaryContainer.withOpacity(0.3)
                : null,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        metadata.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight:
                              isActive ? FontWeight.bold : FontWeight.normal,
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
                    if (metadata.messageCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color:
                              Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${metadata.messageCount}',
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6.0,
                  runSpacing: 4.0,
                  children: [
                    Chip(
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        _getModelDisplayName(metadata.provider, metadata.model),
                        style: const TextStyle(fontSize: 10),
                      ),
                      avatar: _getProviderIcon(metadata.provider),
                      padding: EdgeInsets.zero,
                    ),

                    // Display token information if available
                    if (metadata.totalTokens != null)
                      Chip(
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        label: Tooltip(
                          message:
                              metadata.totalCost != null
                                  ? 'Total Cost: \$${metadata.totalCost!.toStringAsFixed(4)}'
                                  : 'Total Tokens',
                          child: Text(
                            '${_formatTokenCount(metadata.totalTokens!)} tokens',
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                        avatar: const Icon(Icons.token, size: 12),
                        padding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Show delete confirmation dialog - kept for future use
  void _showDeleteConfirmation(
    BuildContext context,
    ChatProvider chatProvider,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Chat'),
            content: Text(
              'Are you sure you want to delete "${metadata.title}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  chatProvider.deleteChat(metadata.id);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  // New method to show action selection dialog
  Future<_SwipeAction?> _showActionSelectionDialog(
    BuildContext context,
    ChatProvider chatProvider,
  ) async {
    return showDialog<_SwipeAction>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Chat Actions'),
            content: Text(
              'What would you like to do with "${metadata.title}"?',
            ),
            actions: [
              TextButton.icon(
                icon: const Icon(Icons.close),
                label: const Text('Cancel'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              TextButton.icon(
                icon: const Icon(Icons.copy, color: Colors.blue),
                label: const Text('Copy', style: TextStyle(color: Colors.blue)),
                onPressed: () {
                  Navigator.of(context).pop(_SwipeAction.copy);
                },
              ),
              TextButton.icon(
                icon: const Icon(Icons.delete, color: Colors.red),
                label: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
                onPressed: () {
                  Navigator.of(context).pop(_SwipeAction.delete);
                },
              ),
            ],
          ),
    );
  }

  // Handle copy action - kept for future use
  void _handleCopy(BuildContext context, ChatProvider chatProvider) async {
    // Show loading indicator
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Text('Copying chat...'),
        duration: Duration(milliseconds: 1000),
      ),
    );

    // Perform the copy operation
    try {
      final newChatId = await chatProvider.copyChat(metadata.id);

      // Show success message
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: const Text('Chat copied successfully'),
          action: SnackBarAction(
            label: 'Go to Copy',
            onPressed: () {
              // Navigate to the new chat using AppNavigation
              if (context.mounted) {
                final navigator = Navigator.of(context);
                if (navigator.canPop()) {
                  navigator.pop(); // Close the chat sidebar if open
                }
                // Navigate to the copied chat
                AppNavigation.toChat(newChatId);
              }
            },
          ),
        ),
      );
    } catch (e) {
      // Show error message
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error copying chat: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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

    return Icon(iconData, color: iconColor, size: 14);
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      // Format as time only for today
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (date.year == now.year) {
      // Format as month and day for this year
      return '${date.month}/${date.day}';
    } else {
      // Format as year-month-day for other years
      return '${date.year}-${date.month}-${date.day}';
    }
  }

  // Helper to format large token numbers
  String _formatTokenCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else {
      return count.toString();
    }
  }
}

// Hover-only icon button without splash effect
class _HoverIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color backgroundColor;

  const _HoverIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.backgroundColor,
  });

  @override
  State<_HoverIconButton> createState() => _HoverIconButtonState();
}

class _HoverIconButtonState extends State<_HoverIconButton> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: BorderRadius.circular(8.0),
            border:
                isHovered
                    ? Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.5),
                      width: 2,
                    )
                    : null,
          ),
          child: Tooltip(
            message: widget.tooltip,
            child: Center(child: Icon(widget.icon)),
          ),
        ),
      ),
    );
  }
}
