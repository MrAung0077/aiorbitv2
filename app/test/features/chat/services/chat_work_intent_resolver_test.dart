import 'package:aiorbit/features/chat/services/chat_work_intent_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const resolver = ChatWorkIntentResolver();

  test('lets a supported one-shot text deliverable proceed', () {
    final result = resolver.resolve(
      'Write a Facebook post about our summer sale',
    );

    expect(result, isA<ChatWorkProceed>());
    expect(
      result.resolvedPrompt,
      'Write a Facebook post about our summer sale',
    );
  });

  test('orchestrates only explicit text-only multi-step work', () {
    final result = resolver.resolve(
      'Create a 30-day social media content calendar for a coffee shop',
    );

    expect(result, isA<ChatWorkOrchestrate>());
  });

  test('rejects unsupported video editing without a tutorial', () {
    final result = resolver.resolve('Edit these 5 videos into one video');

    expect(result, isA<ChatWorkUnsupportedAction>());
    final unsupported = result as ChatWorkUnsupportedAction;
    expect(unsupported.actionKind, ChatUnsupportedActionKind.videoEditing);
    expect(unsupported.userMessage, 'Video editing isn’t connected yet.');
    expect(unsupported.userMessage.toLowerCase(), isNot(contains('how')));
  });

  test('keeps informational video questions on normal text chat', () {
    expect(
      resolver.resolve('How do I edit these 5 videos into one video?'),
      isA<ChatWorkProceed>(),
    );
  });
}
