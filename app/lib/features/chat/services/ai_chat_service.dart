import 'package:aiorbit/core/ai/ai.dart';

class AIChatService {
  AIChatService({AIService? aiService})
    : _aiService =
          aiService ??
          AIService(
            router: AIRouter(providers: AIProviderRegistry.providers()),
          );

  final AIService _aiService;

  static const AIMessage _responsePolicy = AIMessage(
    role: AIMessageRole.system,
    content:
        'Give the usable answer or finished result first. Be concise by '
        'default and use plain, beginner-friendly language. Avoid unnecessary '
        'tutorials, frameworks, repeated context, long background '
        'explanations, and consultant-style reports. Avoid filler such as '
        '"If you want, I can..." unless it is genuinely necessary. Use '
        'sensible defaults for non-critical choices and ask only when required '
        'information is truly missing. Provide longer explanations, detailed '
        'reports, step-by-step instructions, or extensive examples only when '
        'the user explicitly asks for detail.',
  );

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
    final request = AIRequest(
      messages: List<AIMessage>.unmodifiable(<AIMessage>[
        _responsePolicy,
        ...messages,
      ]),
    );

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
