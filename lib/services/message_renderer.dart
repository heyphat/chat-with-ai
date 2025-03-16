import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/message.dart';
import '../widgets/math_markdown.dart';

/// A service to pre-render and cache message content
class MessageRenderer {
  /// Pre-renders the content of a message and returns a new message with the rendered content
  static Message renderMessage(
    Message message,
    BuildContext context, {
    MarkdownStyleSheet? styleSheet,
  }) {
    // Don't pre-render if message is loading or has an error
    if (message.isLoading || message.error != null) {
      return message;
    }

    // Skip if content is empty
    if (message.content.trim().isEmpty) {
      return message;
    }

    // If already rendered, return as is
    if (message.renderedContent != null) {
      return message;
    }

    // Create a repaint boundary to prevent unnecessary repaints during scrolling
    final renderedWidget = RepaintBoundary(
      child: MathMarkdown(
        key: ValueKey('md_${message.id}'),
        data: message.content,
        styleSheet: styleSheet,
        selectable: true,
      ),
    );

    // Return a new message with the rendered content
    return message.copyWith(renderedContent: renderedWidget);
  }

  /// Pre-renders content for a list of messages
  static List<Message> renderMessages(
    List<Message> messages,
    BuildContext context, {
    MarkdownStyleSheet? styleSheet,
  }) {
    return messages
        .map(
          (message) => renderMessage(message, context, styleSheet: styleSheet),
        )
        .toList();
  }
}
