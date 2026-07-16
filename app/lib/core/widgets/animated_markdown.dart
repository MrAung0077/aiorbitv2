import 'package:flutter/material.dart';

import 'app_markdown.dart';
import 'streaming_text.dart';

class AnimatedMarkdown extends StatefulWidget {
  const AnimatedMarkdown({super.key, required this.data, this.textColor});

  final String data;
  final Color? textColor;

  @override
  State<AnimatedMarkdown> createState() => _AnimatedMarkdownState();
}

class _AnimatedMarkdownState extends State<AnimatedMarkdown> {
  bool _streamFinished = false;

  @override
  void didUpdateWidget(covariant AnimatedMarkdown oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.data != widget.data) {
      setState(() {
        _streamFinished = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_streamFinished) {
      return AppMarkdown(widget.data, textColor: widget.textColor);
    }

    return StreamingText(
      text: widget.data,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: widget.textColor, height: 1.5),
      onCompleted: () {
        if (!mounted) {
          return;
        }

        setState(() {
          _streamFinished = true;
        });
      },
    );
  }
}
