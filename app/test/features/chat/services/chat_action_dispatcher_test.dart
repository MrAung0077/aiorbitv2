import 'package:aiorbit/features/chat/services/chat_action_dispatcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const dispatcher = ChatActionDispatcher();

  group('ChatActionDispatcher', () {
    test('detects an explicit image creation request with a subject', () {
      for (final entry in <(String, String)>[
        ('Create an image of Buddha', 'Buddha'),
        ('Create a picture of Buddha', 'Buddha'),
        ('Make an image of Buddha', 'Buddha'),
        ('Make a picture of Buddha', 'Buddha'),
        ('Generate an image of Buddha', 'Buddha'),
        ('Generate a picture of Buddha', 'Buddha'),
        ('Draw a picture of Buddha', 'Buddha'),
        (
          'Create a peaceful picture of Buddha meditating under a bodhi tree.',
          'Buddha meditating under a bodhi tree',
        ),
        ('Make a beautiful image of a sunset', 'a sunset'),
        ('Generate a cinematic picture of Tokyo', 'Tokyo'),
        ('Draw a simple picture of a cat', 'a cat'),
        ('Please create me a realistic image of a car', 'a car'),
      ]) {
        final result = dispatcher.dispatch(entry.$1);

        expect(result, isA<ChatImageActionRequested>(), reason: entry.$1);
        expect(
          (result as ChatImageActionRequested).subject,
          entry.$2,
          reason: entry.$1,
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
      expect(
        dispatcher.dispatch('Tell me how image generation works'),
        isA<ChatActionPassThrough>(),
      );
      expect(
        dispatcher.dispatch('Can you explain how to make an image?'),
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
