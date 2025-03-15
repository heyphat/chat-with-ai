import 'package:flutter/material.dart';

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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Expand to take the maximum width available
            Expanded(
              child: TextField(
                controller: widget.controller,
                onChanged: (text) {
                  setState(() {});
                },
                enabled: !widget.isLoading,
                decoration: InputDecoration(
                  hintText: widget.isLoading ? 'Waiting for response...' : 'Type a message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24.0),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceVariant,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                ),
                textInputAction: TextInputAction.send,
                keyboardType: TextInputType.multiline,
                maxLines: null,
                onSubmitted: _isComposing && !widget.isLoading
                    ? (value) => _handleSubmitted(value)
                    : null,
              ),
            ),
            
            // Send button
            const SizedBox(width: 8),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              child: IconButton(
                icon: const Icon(Icons.send),
                onPressed: _isComposing && !widget.isLoading
                    ? () => _handleSubmitted(widget.controller.text)
                    : null,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
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