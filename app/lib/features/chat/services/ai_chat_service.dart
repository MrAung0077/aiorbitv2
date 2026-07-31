import 'package:aiorbit/core/ai/ai.dart';

class AIChatService {
  AIChatService({AIService? aiService})
    : _aiService =
          aiService ??
          AIService(
            router: AIRouter(providers: AIProviderRegistry.providers()),
          );

  final AIService _aiService;

  /// New streaming API
  Stream<AIChunk> sendMessage(String prompt) {
    final text = prompt.trim();

    if (text.isEmpty) {
      return Stream<AIChunk>.error(Exception('Message cannot be empty.'));
    }

    return sendMessages(<AIMessage>[
      AIMessage(role: AIMessageRole.user, content: text),
    ]);
  }

  Stream<AIChunk> sendMessages(List<AIMessage> messages) {
    final request = AIRequest(messages: List<AIMessage>.unmodifiable(messages));

    if (request.latestUserPrompt.trim().isEmpty) {
      return Stream<AIChunk>.error(Exception('Message cannot be empty.'));
    }

    return _aiService.stream(request);
  }

  /// Compatibility API
  ///
  /// Existing code can continue calling this
  /// until ChatController is migrated.
  Future<String> sendMessageLegacy(String prompt) async {
    final buffer = StringBuffer();

    await for (final chunk in sendMessage(prompt)) {
      if (chunk.type == AIChunkType.text) {
        buffer.write(chunk.text);
      }
    }

    return buffer.toString();
  }
}
