import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../models/message.dart';
import '../models/token_usage.dart';
import 'math_markdown.dart';
import '../router/web_url_handler.dart';

// Create a single instance of WebUrlHandler to use throughout this file
final _webUrlHandler = WebUrlHandler();

class ChatMessageList extends StatefulWidget {
  final List<Message> messages;

  const ChatMessageList({super.key, required this.messages});

  @override
  State<ChatMessageList> createState() => _ChatMessageListState();
}

class _ChatMessageListState extends State<ChatMessageList> {
  final ScrollController _scrollController = ScrollController();
  bool _needsScroll = false;
  // int _previousMessageCount = 0;
  bool _showScrollToBottomButton = false; // Track whether to show the button

  @override
  void initState() {
    super.initState();
    // _previousMessageCount = widget.messages.length;

    // Always scroll to bottom when the widget is first built
    _needsScroll = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        // Use delayed scrolling to ensure content is properly laid out first
        _scrollToBottomWithRetry(animate: false);
      }
    });

    // Add scroll listener to detect when to show the scroll-to-bottom button
    _scrollController.addListener(_scrollListener);
  }

  // Detect when user has scrolled up from the bottom
  void _scrollListener() {
    if (!mounted || !_scrollController.hasClients) return;

    // Check if content is actually scrollable
    final isScrollable = _scrollController.position.maxScrollExtent > 0;

    // Only show button when:
    // 1. Content is scrollable (longer than screen)
    // 2. User has scrolled up significantly from the bottom
    final distanceFromBottom =
        _scrollController.position.maxScrollExtent -
        _scrollController.position.pixels;
    final shouldShowButton = isScrollable && distanceFromBottom > 100;

    if (_showScrollToBottomButton != shouldShowButton) {
      setState(() {
        _showScrollToBottomButton = shouldShowButton;
      });
    }
  }

  @override
  void didUpdateWidget(ChatMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);

    // For web: lock the current URL to prevent it from disappearing during scroll
    if (kIsWeb) {
      _webUrlHandler.lockCurrentUrl();
    }

    // Always scroll to bottom when chat is loaded or when new messages are added
    _needsScroll = true;
    // _previousMessageCount = widget.messages.length;

    // Reset the scroll-to-bottom button state when switching to a new chat
    setState(() {
      _showScrollToBottomButton = false;
    });

    // Scroll after the frame is rendered
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted && _needsScroll) {
        // Use delayed scrolling to ensure content is properly laid out first
        // Use animate: false to instantly jump to bottom without animation when switching chats
        _scrollToBottomWithRetry(animate: false);
        _needsScroll = false;
      }

      // Re-evaluate if the button should be shown based on new content
      if (mounted && _scrollController.hasClients) {
        _scrollListener();
      }

      // For web: ensure the URL is preserved after all updates are complete
      if (kIsWeb) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _webUrlHandler.lockCurrentUrl();
        });
      }
    });
  }

  // Enhanced scrolling mechanism with retry
  void _scrollToBottomWithRetry({bool animate = true}) {
    if (!mounted || !_scrollController.hasClients) return;

    // For web: ensure the URL is locked before scrolling
    if (kIsWeb) {
      _webUrlHandler.lockCurrentUrl();
    }

    // First attempt with a small delay to allow layout
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollToBottom(animate: animate);

      // Second attempt with a longer delay to catch any layout updates
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted || !_scrollController.hasClients) return;
        // Always use immediate jump for second attempt
        _scrollToBottom(
          animate: false,
        ); // Use immediate jump for second attempt
      });
    });
  }

  void _scrollToBottom({bool animate = true}) {
    if (!mounted || !_scrollController.hasClients) return;

    // For web: ensure URL is preserved during scroll
    if (kIsWeb) {
      _webUrlHandler.lockCurrentUrl();
    }

    try {
      // Get current max extent - this might be incorrect if layout is still happening
      final maxExtent = _scrollController.position.maxScrollExtent;

      if (animate) {
        _scrollController.animateTo(
          maxExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(maxExtent);
      }
    } catch (e) {
      debugPrint('Error scrolling: $e');
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
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

    return Stack(
      children: [
        // ListView for messages
        ListView.builder(
          key: ValueKey('chat_list_${widget.messages.length}'),
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          itemCount: widget.messages.length,
          // Use physics that won't affect the app bar
          physics: const ClampingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          clipBehavior: Clip.none,
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
        ),

        // Scroll to bottom button
        if (_showScrollToBottomButton)
          Positioned(
            left: 0,
            right: 0,
            bottom: 40, // Position above the message input
            child: Center(
              child: AnimatedOpacity(
                opacity: _showScrollToBottomButton ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _scrollToBottomWithRetry(animate: true),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                          size: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isUser;

  const MessageBubble({super.key, required this.message, required this.isUser});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Determine the maximum width for the bubble
          final maxBubbleWidth = constraints.maxWidth * 0.75;

          return ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxBubbleWidth),
            child: UnconstrainedBox(
              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
              constrainedAxis: Axis.horizontal,
              child: Container(
                decoration: BoxDecoration(
                  color:
                      isUser
                          ? Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.8)
                          : Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
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
                    Builder(
                      builder: (context) {
                        try {
                          return MathMarkdown(
                            data:
                                message.content.isNotEmpty
                                    ? message.content
                                    : ' ', // Ensure there's always something to render
                            styleSheet: MarkdownStyleSheet(
                              p: TextStyle(
                                color:
                                    isUser
                                        ? Colors.white
                                        : Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                              ),
                              code: TextStyle(
                                backgroundColor:
                                    isUser
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest
                                            .withOpacity(0.7),
                                color:
                                    isUser
                                        ? Colors.white.withOpacity(0.9)
                                        : Theme.of(context).colorScheme.primary,
                                fontFamily: 'monospace',
                                fontSize: 14.0,
                              ),
                              codeblockDecoration: BoxDecoration(
                                color:
                                    isUser
                                        ? Theme.of(
                                          context,
                                        ).colorScheme.primary.withOpacity(0.5)
                                        : Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest
                                            .withOpacity(0.5),
                                borderRadius: BorderRadius.circular(8.0),
                                border: Border.all(
                                  color:
                                      isUser
                                          ? Colors.white.withOpacity(0.2)
                                          : Theme.of(context).dividerColor,
                                  width: 1.0,
                                ),
                              ),
                              codeblockPadding: const EdgeInsets.all(12.0),
                              blockSpacing: 8.0,
                            ),
                            selectable: true,
                          );
                        } catch (e) {
                          // Fallback to simple text display on error
                          debugPrint('Error rendering message markdown: $e');
                          return Text(
                            message.content.isNotEmpty ? message.content : ' ',
                            style: TextStyle(
                              color:
                                  isUser
                                      ? Colors.white
                                      : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                            ),
                          );
                        }
                      },
                    ),

                    // Loading indicator or error message
                    if (message.isLoading)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: SpinKitThreeBounce(
                          color:
                              isUser
                                  ? Colors.white
                                  : Theme.of(context).colorScheme.primary,
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

                    // Timestamp and token usage
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Timestamp
                          Text(
                            '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontSize: 10.0,
                              color:
                                  isUser
                                      ? Colors.white.withOpacity(0.7)
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant
                                          .withOpacity(0.7),
                            ),
                          ),

                          // Token usage info - only show for AI messages that aren't loading
                          if (!isUser &&
                              !message.isLoading &&
                              message.tokenUsage != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 6.0),
                              child: Tooltip(
                                message: _buildTokenUsageTooltip(
                                  message.tokenUsage!,
                                ),
                                preferBelow: false,
                                showDuration: const Duration(seconds: 5),
                                child: InkWell(
                                  onTap: () {
                                    // Show a SnackBar with more detailed information
                                    ScaffoldMessenger.of(
                                      context,
                                    ).clearSnackBars();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text('Token Usage:'),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Input: ${message.tokenUsage!.promptTokens ?? 0}',
                                            ),
                                            Text(
                                              'Output: ${message.tokenUsage!.completionTokens ?? 0}',
                                            ),
                                            Text(
                                              'Total: ${message.tokenUsage!.totalTokens ?? 0}',
                                            ),
                                            if (message.tokenUsage!.totalCost !=
                                                null)
                                              Text(
                                                'Cost: \$${message.tokenUsage!.totalCost!.toStringAsFixed(5)}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                          ],
                                        ),
                                        duration: const Duration(seconds: 5),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4.0,
                                      vertical: 1.0,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest
                                          .withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(4.0),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${message.tokenUsage!.totalTokens ?? '?'} tokens',
                                          style: TextStyle(
                                            fontSize: 10.0,
                                            fontFamily: 'monospace',
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant
                                                .withOpacity(0.9),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
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

  String _buildTokenUsageTooltip(TokenUsage usage) {
    final StringBuffer buffer = StringBuffer();

    buffer.writeln('Input: ${usage.promptTokens ?? 0} tokens');
    buffer.writeln('Output: ${usage.completionTokens ?? 0} tokens');
    buffer.writeln('Total: ${usage.totalTokens ?? 0} tokens');

    if (usage.totalCost != null) {
      buffer.writeln('Cost: \$${usage.totalCost!.toStringAsFixed(5)}');
    }

    return buffer.toString();
  }
}
