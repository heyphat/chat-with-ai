import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../models/message.dart';
import 'math_markdown.dart';

class ChatMessageList extends StatefulWidget {
  final List<Message> messages;

  const ChatMessageList({
    super.key,
    required this.messages,
  });

  @override
  State<ChatMessageList> createState() => _ChatMessageListState();
}

class _ChatMessageListState extends State<ChatMessageList> {
  final ScrollController _scrollController = ScrollController();
  bool _needsScroll = false;
  int _previousMessageCount = 0;
  
  @override
  void initState() {
    super.initState();
    _previousMessageCount = widget.messages.length;
    
    // Initial scroll once the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollToBottom(animate: false);
      }
    });
  }
  
  @override
  void didUpdateWidget(ChatMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Only schedule a scroll if new messages have been added
    if (widget.messages.length > _previousMessageCount) {
      _needsScroll = true;
      _previousMessageCount = widget.messages.length;
      
      // Scroll after the frame is rendered
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted && _needsScroll) {
          _scrollToBottom();
          _needsScroll = false;
        }
      });
    }
  }
  
  void _scrollToBottom({bool animate = true}) {
    if (!mounted || !_scrollController.hasClients) return;
    
    try {
      if (animate) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    } catch (e) {
      debugPrint('Error scrolling: $e');
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.messages.isEmpty) {
      return const Center(
        child: Text('Send a message to start a conversation'),
      );
    }

    return ListView.builder(
      key: ValueKey('chat_list_${widget.messages.length}'),
      controller: _scrollController,
      padding: const EdgeInsets.all(16.0),
      itemCount: widget.messages.length,
      itemBuilder: (context, index) {
        final message = widget.messages[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: MessageBubble(
            key: ValueKey(message.id),
            message: message,
            isUser: message.role == MessageRole.user,
          ),
        );
      },
    );
  }
}

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isUser;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isUser,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Determine the maximum width for the bubble
          final maxBubbleWidth = constraints.maxWidth * 0.75;
          
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxBubbleWidth,
            ),
            child: UnconstrainedBox(
              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
              constrainedAxis: Axis.horizontal,
              child: Container(
                decoration: BoxDecoration(
                  color: isUser
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.8)
                      : Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(12.0),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Message content
                    MathMarkdown(
                      data: message.content.isNotEmpty ? message.content : ' ', // Ensure there's always something to render
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                          color: isUser ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        code: TextStyle(
                          backgroundColor: isUser
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.7),
                          color: isUser
                              ? Colors.white.withOpacity(0.9)
                              : Theme.of(context).colorScheme.primary,
                          fontFamily: 'monospace',
                          fontSize: 14.0,
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: isUser
                              ? Theme.of(context).colorScheme.primary.withOpacity(0.5)
                              : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(
                            color: isUser
                                ? Colors.white.withOpacity(0.2)
                                : Theme.of(context).dividerColor,
                            width: 1.0,
                          ),
                        ),
                        codeblockPadding: const EdgeInsets.all(12.0),
                        blockSpacing: 8.0,
                      ),
                      selectable: true,
                    ),
                    
                    // Loading indicator or error message
                    if (message.isLoading)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: SpinKitThreeBounce(
                          color: isUser ? Colors.white : Theme.of(context).colorScheme.primary,
                          size: 16.0,
                        ),
                      )
                    else if (message.error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Error: ${message.error}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12.0,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    
                    // Timestamp
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 10.0,
                          color: isUser
                              ? Colors.white.withOpacity(0.7)
                              : Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
} 