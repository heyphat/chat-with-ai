import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class KeyboardShortcutsHelp extends StatelessWidget {
  const KeyboardShortcutsHelp({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.keyboard),
      tooltip: 'Keyboard Shortcuts',
      onPressed: () {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Keyboard Shortcuts'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildShortcutRow(context, 'Enter', 'Send message'),
                    const SizedBox(height: 12),
                    _buildShortcutRow(
                      context,
                      kIsWeb ? 'Cmd+B / Ctrl+B' : '⌘+B / Ctrl+B',
                      'Toggle sidebar',
                    ),
                    const SizedBox(height: 12),
                    _buildShortcutRow(
                      context,
                      kIsWeb ? 'Cmd+I / Ctrl+I' : '⌘+I / Ctrl+I',
                      'Focus on message input',
                    ),
                    const SizedBox(height: 12),
                    _buildShortcutRow(
                      context,
                      'Shift+Enter',
                      'Insert new line in message',
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
        );
      },
    );
  }

  Widget _buildShortcutRow(
    BuildContext context,
    String shortcut,
    String description,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline,
              width: 1,
            ),
          ),
          child: Text(
            shortcut,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(description)),
      ],
    );
  }
}
