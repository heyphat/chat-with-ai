import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'dart:math' as math;
import 'package:markdown/markdown.dart' as md;

/// A widget that renders markdown text with LaTeX math expressions
class MathMarkdown extends StatelessWidget {
  /// The text to display, potentially containing markdown and math
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
      // Check if content contains tables
      final containsTable = _containsMarkdownTable(data);
      
      // Check if content contains math expressions
      final containsMath = _containsMathExpression(data);
      
      // If the content contains math expressions, use our specialized renderer
      if (containsMath) {
        return _renderMathContent(context, data);
      }
      
      // Otherwise just use the standard markdown renderer
      return _renderStandardMarkdown(context, data);
    } catch (e) {
      // Fallback to simple markdown on error
      debugPrint('Error in MathMarkdown: $e');
      return _renderStandardMarkdown(context, data, fallback: true);
    }
  }
  
  /// Render content with math expressions
  Widget _renderMathContent(BuildContext context, String content) {
    // Step 1: Split content into segments (markdown vs math)
    final segments = <_ContentSegment>[];
    
    // Get all math expressions
    final mathExpressions = _extractMathExpressions(content);
    
    if (mathExpressions.isEmpty) {
      // No math expressions found, just render as standard markdown
      return _renderStandardMarkdown(context, content);
    }
    
    // Sort math expressions by their position in the content
    mathExpressions.sort((a, b) => a.startPosition.compareTo(b.startPosition));
    
    // Create segments
    int currentPosition = 0;
    
    for (final mathExpression in mathExpressions) {
      // Add text segment before math if there is any
      if (mathExpression.startPosition > currentPosition) {
        segments.add(
          _ContentSegment(
            content: content.substring(currentPosition, mathExpression.startPosition),
            type: _SegmentType.markdown,
          ),
        );
      }
      
      // Add math segment
      segments.add(
        _ContentSegment(
          content: mathExpression.content,
          type: _SegmentType.math,
          isDisplayMath: mathExpression.isDisplay,
        ),
      );
      
      currentPosition = mathExpression.endPosition;
    }
    
    // Add any remaining content after the last math expression
    if (currentPosition < content.length) {
      segments.add(
        _ContentSegment(
          content: content.substring(currentPosition),
          type: _SegmentType.markdown,
        ),
      );
    }
    
    // Step 2: Render each segment
    final widgets = <Widget>[];
    
    for (final segment in segments) {
      if (segment.type == _SegmentType.markdown) {
        // Skip empty markdown segments
        if (segment.content.trim().isEmpty) continue;
        
        // Render markdown segment
        widgets.add(
          _renderStandardMarkdown(context, segment.content),
        );
      } else {
        // Render math segment
        widgets.add(
          _renderMathExpression(context, segment.content, segment.isDisplayMath),
        );
      }
    }
    
    // Combine all segments
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: widgets,
    );
  }
  
  /// Extract all math expressions from the content
  List<_MathExpression> _extractMathExpressions(String content) {
    final expressions = <_MathExpression>[];
    
    // Define patterns for different types of math expressions
    final displayPatterns = [
      RegExp(r'\$\$(.*?)\$\$', dotAll: true),  // Display math: $$ ... $$
      RegExp(r'\\\[(.*?)\\\]', dotAll: true),  // Display math: \[ ... \]
    ];
    
    final inlinePatterns = [
      RegExp(r'\\\((.*?)\\\)', dotAll: true), // Inline math: \( ... \)
      RegExp(r'\$([^\$\n]+?)\$', dotAll: true), // Inline math: $ ... $
    ];
    
    // Find all matches for display math
    for (final regex in displayPatterns) {
      final matches = regex.allMatches(content);
      
      for (final match in matches) {
        expressions.add(
          _MathExpression(
            content: match.group(1)?.trim() ?? '',
            startPosition: match.start,
            endPosition: match.end,
            isDisplay: true,
          ),
        );
      }
    }
    
    // Find all matches for inline math
    for (final regex in inlinePatterns) {
      final matches = regex.allMatches(content);
      
      for (final match in matches) {
        expressions.add(
          _MathExpression(
            content: match.group(1)?.trim() ?? '',
            startPosition: match.start,
            endPosition: match.end,
            isDisplay: false,
          ),
        );
      }
    }
    
    return expressions;
  }
  
  /// Render a math expression
  Widget _renderMathExpression(BuildContext context, String content, bool isDisplay) {
    return Container(
      width: double.infinity,
      alignment: isDisplay ? Alignment.center : Alignment.centerLeft,
      padding: isDisplay 
          ? const EdgeInsets.symmetric(vertical: 12.0)
          : const EdgeInsets.symmetric(vertical: 4.0),
      child: Math.tex(
        content,
        textStyle: TextStyle(
          fontSize: isDisplay ? 18 : 16,
          color: Theme.of(context).textTheme.bodyMedium?.color,
        ),
        mathStyle: isDisplay ? MathStyle.display : MathStyle.text,
      ),
    );
  }
  
  /// Check if the content contains markdown tables
  bool _containsMarkdownTable(String text) {
    // Look for pipe characters that indicate table cells
    final containsPipes = text.contains('|');
    final containsNewlinePipe = text.contains('\n|');
    
    // Look for table header separator row (e.g., |-----|-----|)
    final hasHeaderSeparator = RegExp(r'\|[\s\-:]+\|').hasMatch(text);
    
    // Simple heuristic: if it has pipes and a header separator, it's likely a table
    return containsPipes && containsNewlinePipe && hasHeaderSeparator;
  }
  
  /// Check if a paragraph contains math expressions
  bool _containsMathExpression(String text) {
    final patterns = [
      r'\$\$(.*?)\$\$',
      r'\\\[(.*?)\\\]',
      r'\\\((.*?)\\\)',
      r'\$([^\$\n]+?)\$',
    ];
    
    for (final pattern in patterns) {
      if (RegExp(pattern, dotAll: true).hasMatch(text)) {
        return true;
      }
    }
    
    return false;
  }
  
  /// Render standard markdown content
  Widget _renderStandardMarkdown(BuildContext context, String content, {bool fallback = false}) {
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
    final baseStyle = styleSheet ?? MarkdownStyleSheet.fromTheme(Theme.of(context));
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
      strong: baseStyle.strong?.copyWith(
        fontWeight: FontWeight.bold,
      ),
      listBullet: baseStyle.listBullet?.copyWith(
        fontSize: 16,
      ),
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
        color: isDark ? Colors.white.withOpacity(0.9) : Theme.of(context).colorScheme.primary,
        backgroundColor: isDark 
            ? Colors.black.withOpacity(0.3) 
            : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.7),
      ),
      codeblockPadding: const EdgeInsets.all(12.0),
      codeblockDecoration: BoxDecoration(
        color: isDark 
            ? Colors.black.withOpacity(0.3) 
            : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: Theme.of(context).dividerColor,
          width: 1.0,
        ),
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
  Widget? visitElementAfterWithContext(BuildContext context, md.Element element, TextStyle? parentStyle, TextStyle? textStyle) {
    // Simple determination of code block vs inline code by tag
    final isCodeBlock = element.tag == 'pre';
    String codeContent = element.textContent;
    String language = '';
    
    // Format the code content
    codeContent = _formatCodeContent(codeContent);
    
    if (isCodeBlock) {
      // Multi-line code block
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        decoration: styleSheet.codeblockDecoration ?? BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
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
              padding: styleSheet.codeblockPadding ?? const EdgeInsets.all(16.0),
              child: SelectableText(
                codeContent,
                style: styleSheet.code ?? TextStyle(
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
          color: styleSheet.code?.backgroundColor ?? Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(4.0),
        ),
        child: Text(
          codeContent,
          style: styleSheet.code ?? TextStyle(
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

/// Types of content segments
enum _SegmentType {
  markdown,
  math,
}

/// Represents a segment of content (either markdown or math)
class _ContentSegment {
  final String content;
  final _SegmentType type;
  final bool isDisplayMath;
  
  _ContentSegment({
    required this.content,
    required this.type,
    this.isDisplayMath = false,
  });
}

/// Represents a math expression
class _MathExpression {
  final String content;
  final int startPosition;
  final int endPosition;
  final bool isDisplay;
  
  _MathExpression({
    required this.content,
    required this.startPosition,
    required this.endPosition,
    required this.isDisplay,
  });
} 