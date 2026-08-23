import 'package:aiorbit/core/ai/ai.dart';
import 'package:aiorbit/core/ai/ai_capability.dart';
import 'package:aiorbit/features/chat/services/ai_chat_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'prepends one concise result-first policy without altering history',
    () async {
      final provider = _CapturingProvider();
      final service = AIChatService(
        aiService: AIService(
          router: AIRouter(providers: <AIProvider>[provider]),
        ),
      );
      const history = <AIMessage>[
        AIMessage(role: AIMessageRole.user, content: 'Explain baking bread.'),
        AIMessage(
          role: AIMessageRole.assistant,
          content: 'Use yeast and flour.',
        ),
        AIMessage(
          role: AIMessageRole.user,
          content: 'Give a detailed step-by-step guide with examples.',
        ),
      ];

      await service.sendMessages(history).toList();

      final request = provider.requests.single;
      expect(request.messages, hasLength(history.length + 1));
      expect(request.messages.first.role, AIMessageRole.system);
      expect(
        request.messages.where(
          (message) => message.role == AIMessageRole.system,
        ),
        hasLength(1),
      );
      expect(request.messages.skip(1), orderedEquals(history));
      expect(
        request.messages.last.content,
        'Give a detailed step-by-step guide with examples.',
      );

      final policy = request.messages.first.content;
      expect(policy, contains('usable answer or finished result first'));
      expect(policy, contains('concise by default'));
      expect(policy, contains('beginner-friendly language'));
      expect(policy, contains('explicitly asks for detail'));

      const retryHistory = <AIMessage>[
        AIMessage(role: AIMessageRole.user, content: 'What is a budget?'),
        AIMessage(role: AIMessageRole.user, content: 'Please try again.'),
      ];
      await service.sendMessages(retryHistory).toList();

      final retryRequest = provider.requests.last;
      expect(
        retryRequest.messages.where(
          (message) => message.role == AIMessageRole.system,
        ),
        hasLength(1),
      );
      expect(retryRequest.messages.skip(1), orderedEquals(retryHistory));
    },
  );
}

class _CapturingProvider implements AIProvider {
  final List<AIRequest> requests = <AIRequest>[];

  @override
  String get displayName => 'Test provider';

  @override
  bool get isConfigured => true;

  @override
  AIProviderMetadata get metadata => const AIProviderMetadata(
    supportedTasks: <AITaskType>{AITaskType.generalChat},
  );

  @override
  ProviderType get type => ProviderType.openAI;

  @override
  Future<AIResponse> complete(AIRequest request) async {
    requests.add(request);
    return const AIResponse(provider: ProviderType.openAI, content: 'Done');
  }

  @override
  Stream<AIChunk> stream(AIRequest request) async* {
    requests.add(request);
    yield const AIChunk.text(provider: ProviderType.openAI, text: 'Done');
    yield const AIChunk.done(provider: ProviderType.openAI);
  }

  @override
  bool supports(AIRequest request) => request.messages.isNotEmpty;
}
