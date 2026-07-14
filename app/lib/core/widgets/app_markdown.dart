import 'package:flutter/material.dart';

class AppMarkdown extends StatelessWidget {
  const AppMarkdown(this.data, {super.key, this.textColor});

  final String data;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SelectableText(
      data,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: textColor,
        height: 1.5,
      ),
    );
  }
}
