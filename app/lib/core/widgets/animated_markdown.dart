import 'package:flutter/material.dart';

import 'app_markdown.dart';

class AnimatedMarkdown extends StatelessWidget {
  const AnimatedMarkdown({super.key, required this.data, this.textColor});

  final String data;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return AppMarkdown(data, textColor: textColor);
  }
}
