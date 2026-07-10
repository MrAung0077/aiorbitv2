import 'dart:async';

class AIChatService {
  Future<String> sendMessage(String prompt) async {
    await Future.delayed(const Duration(milliseconds: 700));

    final text = prompt.trim();

    if (text.isEmpty) {
      throw Exception('Message cannot be empty.');
    }

    return '''
I understand.

For AIOrbit V2, this request should be handled by the best available AI model depending on task type.

Your prompt:
"$text"

Next production step: connect this service to your real BrainService / AI router.
''';
  }
}
