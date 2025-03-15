import 'package:flutter/material.dart';
import 'dart:ui';

class MessageInput extends StatefulWidget {
  final TextEditingController controller;
  final Function(String) onSend;
  final bool isLoading;

  const MessageInput({
    super.key,
    required this.controller,
    required this.onSend,
    required this.isLoading,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  bool get _isComposing => widget.controller.text.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    // final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Create the main input widget
    final inputWidget = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.2),
          width: 1.0,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Text input row - expandable
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 4.0),
            child: TextField(
              controller: widget.controller,
              onChanged: (text) {
                setState(() {});
              },
              enabled: !widget.isLoading,
              decoration: InputDecoration(
                hintText:
                    widget.isLoading
                        ? 'Waiting for response...'
                        : 'Type a message...',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              textInputAction: TextInputAction.newline,
              keyboardType: TextInputType.multiline,
              minLines: 1,
              maxLines: 5,
              style: const TextStyle(fontSize: 16.0),
            ),
          ),

          // Icons row - fixed height
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Calculate available width
                final availableWidth = constraints.maxWidth;
                // Decide which icons to show based on available width
                final bool showAllIcons = availableWidth > 250;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Plus button - only show on larger screens
                    // if (showAllIcons)
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        // Handle attachment functionality
                      },
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      iconSize: 20,
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                    ),

                    // Globe button - only show on larger screens
                    if (showAllIcons)
                      IconButton(
                        icon: const Icon(Icons.language),
                        onPressed: () {
                          // Handle language selection
                        },
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        iconSize: 20,
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(8),
                      ),

                    // Code/refresh button - always show
                    if (showAllIcons)
                      IconButton(
                        icon: const Icon(Icons.code),
                        onPressed: () {
                          // Handle code formatting
                        },
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        iconSize: 20,
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(8),
                      ),

                    // Spacer
                    const Spacer(),

                    // Microphone button - only show on larger screens
                    if (showAllIcons)
                      IconButton(
                        icon: const Icon(Icons.mic),
                        onPressed: () {
                          // Handle voice input
                        },
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        iconSize: 20,
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(8),
                      ),

                    // Send button - always show
                    Padding(
                      padding: const EdgeInsets.only(left: 4.0),
                      child: Container(
                        height: 32,
                        width: 32,
                        decoration: BoxDecoration(
                          color:
                              _isComposing
                                  ? Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white
                                      : Colors.black
                                  : Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(4.0),
                          onTap:
                              _isComposing && !widget.isLoading
                                  ? () =>
                                      _handleSubmitted(widget.controller.text)
                                  : null,
                          child: Icon(
                            Icons.send,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.black
                                    : Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );

    // Main container with gradient blur overlay
    return SizedBox(
      height: 200, // Fixed height container to avoid layout issues
      child: Stack(
        children: [
          // Positioned(
          //   left: 0,
          //   right: 0,
          //   bottom: 0,
          //   height: 200, // Full height, but with gradient opacity
          //   child: ShaderMask(
          //     shaderCallback: (Rect bounds) {
          //       return LinearGradient(
          //         begin: Alignment.topCenter,
          //         end: Alignment.bottomCenter,
          //         colors: [
          //           Colors.transparent, // Start transparent at top
          //           Colors.white.withOpacity(0.7), // Gradually becoming opaque
          //           Colors.white, // Fully opaque at bottom
          //         ],
          //         stops: const [0.0, 0.3, 0.8],
          //       ).createShader(bounds);
          //     },
          //     blendMode: BlendMode.dstIn,
          //     child: BackdropFilter(
          //       filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          //       child: Container(color: Colors.transparent),
          //     ),
          //   ),
          // ),

          // Input area at the bottom with blur background
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    // color:
                    //     isDarkMode
                    //         ? Colors.black.withOpacity(0.2)
                    //         : Colors.white.withOpacity(0.2),
                    // border: Border(
                    //   top: BorderSide(
                    //     color: Theme.of(context).dividerColor.withOpacity(0.1),
                    //     width: 1,
                    //   ),
                    // ),
                  ),
                  child: inputWidget,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleSubmitted(String text) {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) return;

    widget.onSend(trimmedText);
    setState(() {});
  }
}
