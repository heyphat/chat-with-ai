import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

/// A widget that renders markdown text
class MathMarkdown extends StatelessWidget {
  /// The text to display in markdown format
  final String data;

  /// Optional style sheet for markdown
  final MarkdownStyleSheet? styleSheet;

  /// Whether the text should be selectable
  final bool selectable;

  const MathMarkdown({
    super.key,
    required this.data,
    this.styleSheet,
    this.selectable = true,
  });

  @override
  Widget build(BuildContext context) {
    // Safety check for empty data
    if (data.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    try {
      return _renderStandardMarkdown(context, data);
    } catch (e) {
      // Fallback to simple markdown on error
      debugPrint('Error in MathMarkdown: $e');
      return _renderStandardMarkdown(context, data, fallback: true);
    }
  }

  /// Render standard markdown content
  Widget _renderStandardMarkdown(
    BuildContext context,
    String content, {
    bool fallback = false,
  }) {
    return Container(
      width: double.infinity,
      alignment: Alignment.topLeft,
      child: MarkdownBody(
        data: content,
        selectable: selectable && !fallback,
        styleSheet: _getEnhancedStyleSheet(context),
        softLineBreak: false, // Force hard line breaks
        builders: {
          'code': CodeElementBuilder(context, _getEnhancedStyleSheet(context)),
          'pre': CodeElementBuilder(context, _getEnhancedStyleSheet(context)),
        },
        extensionSet: md.ExtensionSet.gitHubWeb,
      ),
    );
  }

  /// Enhanced style sheet for the markdown
  MarkdownStyleSheet _getEnhancedStyleSheet(BuildContext context) {
    final baseStyle =
        styleSheet ?? MarkdownStyleSheet.fromTheme(Theme.of(context));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return baseStyle.copyWith(
      h1: baseStyle.h1?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
      h2: baseStyle.h2?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
      h3: baseStyle.h3?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
      strong: baseStyle.strong?.copyWith(fontWeight: FontWeight.bold),
      listBullet: baseStyle.listBullet?.copyWith(fontSize: 16),
      listIndent: 24.0, // Adjusted indent for better list alignment
      blockSpacing: 12.0, // Better spacing between blocks
      textAlign: WrapAlignment.start,
      p: baseStyle.p?.copyWith(
        height: 1.4, // Better line height for paragraphs
      ),
      // Improved code block styling
      code: baseStyle.code?.copyWith(
        fontSize: 14.0,
        fontFamily: 'monospace',
        color:
            isDark
                ? Colors.white.withOpacity(0.9)
                : Theme.of(context).colorScheme.primary,
        backgroundColor:
            isDark
                ? Colors.black.withOpacity(0.3)
                : Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withOpacity(0.7),
      ),
      codeblockPadding: const EdgeInsets.all(12.0),
      codeblockDecoration: BoxDecoration(
        color:
            isDark
                ? Colors.black.withOpacity(0.3)
                : Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Theme.of(context).dividerColor, width: 1.0),
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
            width: 4.0,
          ),
        ),
      ),
      blockquotePadding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 8.0,
      ),
      tableHead: TextStyle(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
      tableBorder: TableBorder.all(
        color: Theme.of(context).dividerColor,
        width: 1,
      ),
      tableBody: TextStyle(
        color: Theme.of(context).textTheme.bodyMedium?.color,
      ),
    );
  }
}

/// Custom builder for code blocks to improve rendering and support syntax highlighting
class CodeElementBuilder extends MarkdownElementBuilder {
  final BuildContext context;
  final MarkdownStyleSheet styleSheet;

  CodeElementBuilder(this.context, this.styleSheet);

  /// Format code content for better display
  String _formatCodeContent(String code) {
    // Trim leading and trailing whitespace while preserving internal indentation
    String formatted = code.trim();

    // Replace tabs with spaces for consistent display
    formatted = formatted.replaceAll('\t', '    ');

    return formatted;
  }

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? parentStyle,
    TextStyle? textStyle,
  ) {
    // Simple determination of code block vs inline code by tag
    final isCodeBlock = element.tag == 'pre';
    String codeContent = element.textContent;
    // String language = '';

    // Format the code content
    codeContent = _formatCodeContent(codeContent);

    if (isCodeBlock) {
      // Multi-line code block
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        decoration:
            styleSheet.codeblockDecoration ??
            BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(
                color: Theme.of(context).dividerColor,
                width: 1.0,
              ),
            ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding:
                  styleSheet.codeblockPadding ?? const EdgeInsets.all(16.0),
              child: SelectableText(
                codeContent,
                style:
                    styleSheet.code ??
                    TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14.0,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ],
        ),
      );
    } else if (element.tag == 'code') {
      // Inline code
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
        decoration: BoxDecoration(
          color:
              styleSheet.code?.backgroundColor ??
              Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(4.0),
        ),
        child: Text(
          codeContent,
          style:
              styleSheet.code ??
              TextStyle(
                fontFamily: 'monospace',
                fontSize: 14.0,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }

    // Let other elements be handled by the default builder
    return null;
  }
}
