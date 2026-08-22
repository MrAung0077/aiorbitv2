import 'package:aiorbit/features/chat/services/chat_action_dispatcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const dispatcher = ChatActionDispatcher();

  group('ChatActionDispatcher', () {
    test('detects an explicit image creation request with a subject', () {
      for (final prompt in <String>[
        'Create an image of Buddha',
        'Create a picture of Buddha',
        'Make an image of Buddha',
        'Make a picture of Buddha',
        'Generate an image of Buddha',
        'Generate a picture of Buddha',
        'Draw a picture of Buddha',
      ]) {
        final result = dispatcher.dispatch(prompt);

        expect(result, isA<ChatImageActionRequested>(), reason: prompt);
        expect(
          (result as ChatImageActionRequested).subject,
          'Buddha',
          reason: prompt,
        );
      }
    });

    test('keeps informational image questions on the text-chat path', () {
      expect(
        dispatcher.dispatch('How do I create a picture?'),
        isA<ChatActionPassThrough>(),
      );
      expect(
        dispatcher.dispatch('What is image generation?'),
        isA<ChatActionPassThrough>(),
      );
    });

    test('asks one short question when an image subject is missing', () {
      final result = dispatcher.dispatch('Generate an image');

      expect(result, isA<ChatActionClarification>());
      expect(
        (result as ChatActionClarification).message,
        'What should the image be of?',
      );
    });
  });
}
