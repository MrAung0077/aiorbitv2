import 'package:aiorbit/core/widgets/app_markdown.dart';
import 'package:aiorbit/core/widgets/app_message_bubble.dart';
import 'package:aiorbit/features/chat/models/chat_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const markdown = '''
### Research summary

This has **bold text** and a [source](https://example.com).

- First point
- Second point
''';

  testWidgets('assistant messages use the existing Markdown renderer', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppMessageBubble(
            message: ChatMessage(
              id: 'assistant-message',
              role: ChatRole.assistant,
              content: markdown,
              createdAt: DateTime(2026),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(AppMarkdown), findsOneWidget);
    expect(find.byType(MarkdownBody), findsOneWidget);

    final renderedText = tester.allWidgets.map(_plainText).join('\n');

    expect(renderedText, contains('Research summary'));
    expect(renderedText, contains('bold text'));
    expect(renderedText, contains('First point'));
    expect(renderedText, isNot(contains('###')));
    expect(renderedText, isNot(contains('**')));
  });

  testWidgets('user messages keep their original plain-text rendering', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppMessageBubble(
            message: ChatMessage(
              id: 'user-message',
              role: ChatRole.user,
              content: markdown,
              createdAt: DateTime(2026),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(AppMarkdown), findsNothing);
    expect(find.byType(SelectableText), findsOneWidget);
    expect(
      tester.widget<SelectableText>(find.byType(SelectableText)).data,
      markdown,
    );
  });

  testWidgets('neutral assistant information is not styled or controlled as an error', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppMessageBubble(
            message: ChatMessage(
              id: 'unsupported-capability',
              role: ChatRole.assistant,
              content: 'This feature is not available in this beta yet.',
              createdAt: DateTime(2026),
            ),
            onCopy: () {},
            onRetry: () {},
          ),
        ),
      ),
    );

    final context = tester.element(find.byType(AppMessageBubble));
    final container = tester.widget<Container>(find.byType(Container));
    final decoration = container.decoration! as BoxDecoration;

    expect(decoration.color, Theme.of(context).colorScheme.surface);
    expect(find.byTooltip('Retry'), findsNothing);
    expect(find.byTooltip('Copy'), findsOneWidget);
  });
}

String _plainText(Widget widget) {
  if (widget is Text) {
    return widget.data ?? widget.textSpan?.toPlainText() ?? '';
  }

  if (widget is SelectableText) {
    return widget.data ?? widget.textSpan?.toPlainText() ?? '';
  }

  if (widget is RichText) {
    return widget.text.toPlainText();
  }

  return '';
}
