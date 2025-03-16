import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../models/message.dart';
import '../models/token_usage.dart';
import '../services/message_renderer.dart';
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
  List<Message> _renderedMessages = [];

  @override
  void initState() {
    super.initState();

    // Pre-render initial messages
    _preRenderMessages();

    // Always scroll to bottom when the widget is first built
    _needsScroll = true;

    // Set up post-frame callback for initial scroll
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // First attempt immediately after first frame
      if (mounted) {
        Future.microtask(() {
          if (mounted && _scrollController.hasClients) {
            _scrollToBottom(animate: false);
          }

          // Second attempt with delay
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted && _scrollController.hasClients) {
              _scrollToBottom(animate: false);
            }
          });
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(ChatMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);

    // For web: lock the current URL to prevent it from disappearing during scroll
    if (kIsWeb) {
      _webUrlHandler.lockCurrentUrl();
    }

    // Pre-render messages if they've changed
    if (widget.messages != oldWidget.messages) {
      _preRenderMessages();
    }

    // Check if messages were added or changed
    final bool messagesChanged =
        widget.messages.length != oldWidget.messages.length ||
        (widget.messages.isNotEmpty &&
            oldWidget.messages.isNotEmpty &&
            widget.messages.last.id != oldWidget.messages.last.id);

    // Check for streaming message (a message is currently loading)
    final bool hasStreamingMessage =
        widget.messages.isNotEmpty &&
        widget.messages.any((message) => message.isLoading);

    // Check if last message content has changed (for streaming updates)
    bool streamingContentChanged = false;
    if (widget.messages.isNotEmpty &&
        oldWidget.messages.isNotEmpty &&
        widget.messages.length == oldWidget.messages.length) {
      // Compare each message content to detect streaming changes
      for (int i = 0; i < widget.messages.length; i++) {
        if (widget.messages[i].id == oldWidget.messages[i].id &&
            widget.messages[i].content != oldWidget.messages[i].content &&
            widget.messages[i].isLoading) {
          streamingContentChanged = true;
          break;
        }
      }
    }

    final bool isNewMessage =
        widget.messages.length > oldWidget.messages.length;

    // Check if we're already at the bottom (with a small tolerance)
    bool isAlreadyAtBottom = false;
    if (mounted && _scrollController.hasClients) {
      try {
        final currentOffset = _scrollController.offset;
        final maxExtent = _scrollController.position.maxScrollExtent;
        isAlreadyAtBottom = (maxExtent - currentOffset).abs() < 20.0;
      } catch (e) {
        // Ignore error (might happen during layout changes)
      }
    }

    // Scroll to bottom when messages change or during streaming updates
    if ((messagesChanged || streamingContentChanged || hasStreamingMessage) &&
        (!isAlreadyAtBottom || isNewMessage)) {
      _needsScroll = true;

      // For new messages or streaming updates, try to scroll immediately to reduce visible delay
      if ((isNewMessage || streamingContentChanged || hasStreamingMessage) &&
          mounted &&
          _scrollController.hasClients) {
        try {
          // Try to immediately jump to bottom first
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        } catch (e) {
          // Ignore errors here, will be handled in the post-frame callback
          debugPrint('Initial scroll attempt failed: $e');
        }
      }
    }

    // Scroll after the frame is rendered
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted && _needsScroll) {
        // Use full retry mechanism for reliability
        // Don't animate during streaming for smoother updates
        _scrollToBottomWithRetry(
          animate:
              messagesChanged &&
              !isNewMessage &&
              !streamingContentChanged &&
              !hasStreamingMessage,
        );
        _needsScroll = false;
      }

      // For web: ensure the URL is preserved after all updates are complete
      if (kIsWeb) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _webUrlHandler.lockCurrentUrl();
        });
      }
    });
  }

  // Pre-render messages for improved scrolling performance
  void _preRenderMessages() {
    if (!mounted) return;

    _renderedMessages = MessageRenderer.renderMessages(
      widget.messages,
      context,
    );
  }

  // Enhanced scrolling mechanism with retry
  void _scrollToBottomWithRetry({bool animate = true}) {
    if (!mounted) return;

    // For web: ensure the URL is locked before scrolling
    if (kIsWeb) {
      _webUrlHandler.lockCurrentUrl();
    }

    // Use microtask to ensure we're not in the middle of a frame
    Future.microtask(() {
      if (!mounted) return;

      // First attempt immediately
      if (_scrollController.hasClients) {
        _scrollToBottom(animate: animate);
      }

      // Sequence of retries with increasing delays - faster sequence for better responsiveness
      Future.delayed(const Duration(milliseconds: 10), () {
        if (!mounted) return;
        if (_scrollController.hasClients) {
          _scrollToBottom(animate: animate);
        }

        Future.delayed(const Duration(milliseconds: 50), () {
          if (!mounted) return;
          if (_scrollController.hasClients) {
            _scrollToBottom(animate: false);
          }

          Future.delayed(const Duration(milliseconds: 100), () {
            if (!mounted) return;
            if (_scrollController.hasClients) {
              _scrollToBottom(animate: false);
            }

            // Extra attempt for very complex layouts
            Future.delayed(const Duration(milliseconds: 200), () {
              if (!mounted) return;
              if (_scrollController.hasClients) {
                _scrollToBottom(animate: false);
              }
            });
          });
        });
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

      // Check if we're already at the bottom (with a small tolerance)
      final double currentOffset = _scrollController.offset;
      final double targetOffset = maxExtent;
      final bool alreadyAtBottom = (targetOffset - currentOffset).abs() < 10.0;

      // If already at bottom, skip animation for smoother experience
      final bool shouldAnimate = animate && !alreadyAtBottom;

      if (shouldAnimate) {
        _scrollController.animateTo(
          maxExtent,
          duration: const Duration(milliseconds: 150), // Faster animation
          curve: Curves.easeOutQuart, // Smoother curve
        );
      } else {
        _scrollController.jumpTo(maxExtent);
      }
    } catch (e) {
      debugPrint('Error scrolling: $e');
      // Schedule another attempt if there was an error
      Future.delayed(const Duration(milliseconds: 50), () {
        // Faster retry
        if (mounted && _scrollController.hasClients) {
          try {
            _scrollController.jumpTo(
              _scrollController.position.maxScrollExtent,
            );
          } catch (e2) {
            debugPrint('Retry scroll error: $e2');
          }
        }
      });
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

    // Just return the ListView by itself, no Stack or buttons
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      itemCount: _renderedMessages.length,
      cacheExtent: 1000, // Cache more items for smoother scrolling
      physics: const ClampingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      clipBehavior: Clip.none,
      itemBuilder: (context, index) {
        final message = _renderedMessages[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: RepaintBoundary(
            // Add RepaintBoundary for improved performance
            child: MessageBubble(
              key: ValueKey(message.id),
              message: message,
              isUser: message.role == MessageRole.user,
            ),
          ),
        );
      },
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
                    // Message content - Use pre-rendered content if available
                    Builder(
                      builder: (context) {
                        if (message.renderedContent != null) {
                          // Use pre-rendered content
                          return message.renderedContent!;
                        } else {
                          // Fallback to rendering on-demand
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
                                          ? Theme.of(
                                            context,
                                          ).colorScheme.primary
                                          : Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerHighest
                                              .withOpacity(0.7),
                                  color:
                                      isUser
                                          ? Colors.white.withOpacity(0.9)
                                          : Theme.of(
                                            context,
                                          ).colorScheme.primary,
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
                              message.content.isNotEmpty
                                  ? message.content
                                  : ' ',
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
