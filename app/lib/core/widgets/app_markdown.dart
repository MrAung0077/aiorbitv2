import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class AppMarkdown extends StatelessWidget {
  const AppMarkdown(this.data, {super.key, this.textColor});

  final String data;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final effectiveTextColor = textColor ?? theme.textTheme.bodyMedium?.color;

    return MarkdownBody(
      data: data,
      selectable: true,
      softLineBreak: true,
      styleSheet: MarkdownStyleSheet(
        p: theme.textTheme.bodyMedium?.copyWith(
          color: effectiveTextColor,
          height: 1.5,
        ),
        h1: theme.textTheme.headlineMedium?.copyWith(
          color: effectiveTextColor,
          fontWeight: FontWeight.w700,
        ),
        h2: theme.textTheme.headlineSmall?.copyWith(
          color: effectiveTextColor,
          fontWeight: FontWeight.w700,
        ),
        h3: theme.textTheme.titleLarge?.copyWith(
          color: effectiveTextColor,
          fontWeight: FontWeight.w600,
        ),
        strong: TextStyle(
          color: effectiveTextColor,
          fontWeight: FontWeight.w700,
        ),
        em: TextStyle(color: effectiveTextColor, fontStyle: FontStyle.italic),
        listBullet: theme.textTheme.bodyMedium?.copyWith(
          color: effectiveTextColor,
        ),
        code: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontFamily: 'monospace',
          height: 1.4,
        ),
        codeblockDecoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        codeblockPadding: const EdgeInsets.all(12),
        blockquote: theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
        blockquoteDecoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(color: colorScheme.primary, width: 4),
          ),
        ),
        blockquotePadding: const EdgeInsets.all(12),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
        ),
      ),
    );
  }
}
