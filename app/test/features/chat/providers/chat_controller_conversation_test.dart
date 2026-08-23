import 'package:aiorbit/core/ai/ai.dart';
import 'package:aiorbit/features/chat/models/conversation.dart';
import 'package:aiorbit/features/chat/providers/chat_controller.dart';
import 'package:aiorbit/features/chat/repositories/conversation_repository.dart';
import 'package:aiorbit/features/chat/services/ai_chat_service.dart';
import 'package:aiorbit/features/chat/services/mission_suggestion_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatController conversation lifecycle', () {
    test('creates and persists a new empty conversation', () async {
      final repository = _MemoryConversationRepository();
      final controller = _createController(repository);
      addTearDown(controller.dispose);

      final created = await controller.createNewConversation();

      expect(created, isTrue);
      expect(controller.state.conversation, isNotNull);
      expect(controller.state.messages, isEmpty);
      expect(repository.conversations, hasLength(1));
      expect(repository.conversations.single.title, 'New Chat');
    });

    test('does not leak messages between conversations', () async {
      final repository = _MemoryConversationRepository();
      final controller = _createController(repository);
      addTearDown(controller.dispose);

      await controller.createNewConversation();
      await controller.sendMessage('First conversation prompt');
      final firstId = controller.state.conversation!.id;

      await controller.createNewConversation();
      expect(controller.state.messages, isEmpty);

      await controller.sendMessage('Second conversation prompt');
      final secondId = controller.state.conversation!.id;

      expect(secondId, isNot(firstId));

      final first = await repository.getConversation(firstId);
      final second = await repository.getConversation(secondId);

      expect(
        first!.messages.any(
          (message) => message.content == 'First conversation prompt',
        ),
        isTrue,
      );
      expect(
        first.messages.any(
          (message) => message.content == 'Second conversation prompt',
        ),
        isFalse,
      );
      expect(
        second!.messages.any(
          (message) => message.content == 'Second conversation prompt',
        ),
        isTrue,
      );
      expect(
        second.messages.any(
          (message) => message.content == 'First conversation prompt',
        ),
        isFalse,
      );
    });

    test('reopens the most recently updated conversation', () async {
      final repository = _MemoryConversationRepository();
      final controller = _createController(repository);
      addTearDown(controller.dispose);

      await controller.createNewConversation();
      await controller.sendMessage('Older conversation');

      await controller.createNewConversation();
      await controller.sendMessage('Most recent conversation');
      final mostRecentId = controller.state.conversation!.id;

      final restoredController = _createController(repository);
      addTearDown(restoredController.dispose);

      await restoredController.loadMostRecentConversation();

      expect(restoredController.state.conversation!.id, mostRecentId);
      expect(
        restoredController.state.messages.first.content,
        'Most recent conversation',
      );
    });

    test('preserves the first-prompt title after follow-up prompts', () async {
      final repository = _MemoryConversationRepository();
      final controller = _createController(repository);
      addTearDown(controller.dispose);

      await controller.createNewConversation();
      await controller.sendMessage(
        'Build a launch plan for a neighborhood coffee shop',
      );
      final originalTitle = controller.state.conversation!.title;

      await controller.sendMessage('Now add a two-week content calendar');

      expect(
        originalTitle,
        Conversation.generateTitleFromPrompt(
          'Build a launch plan for a neighborhood coffee shop',
        ),
      );
      expect(controller.state.conversation!.title, originalTitle);
    });

    test(
      'routes an image action with a subject away from text completion',
      () async {
        final repository = _MemoryConversationRepository();
        final aiChatService = _FakeAIChatService();
        final controller = _createController(
          repository,
          aiChatService: aiChatService,
        );
        addTearDown(controller.dispose);

        await controller.sendMessage(
          'Create a peaceful picture of Buddha meditating under a bodhi tree.',
        );

        expect(aiChatService.requests, isEmpty);
        expect(controller.state.imageActionRequest, isNotNull);
        expect(
          controller.state.imageActionRequest!.subject,
          'Buddha meditating under a bodhi tree',
        );
        expect(controller.state.messages, hasLength(1));
        expect(controller.state.messages.single.content, contains('Buddha'));
      },
    );

    test(
      'asks one concise question for an image action without a subject',
      () async {
        final repository = _MemoryConversationRepository();
        final aiChatService = _FakeAIChatService();
        final controller = _createController(
          repository,
          aiChatService: aiChatService,
        );
        addTearDown(controller.dispose);

        await controller.sendMessage('Create a picture');

        expect(aiChatService.requests, isEmpty);
        expect(controller.state.imageActionRequest, isNull);
        expect(
          controller.state.messages.map((message) => message.content),
          <String>['Create a picture', 'What should the image be of?'],
        );
      },
    );

    test(
      'asks exactly once for a Facebook post topic before completion',
      () async {
        final repository = _MemoryConversationRepository();
        final aiChatService = _FakeAIChatService();
        final controller = _createController(
          repository,
          aiChatService: aiChatService,
        );
        addTearDown(controller.dispose);

        await controller.sendMessage('Write a Facebook post');

        expect(aiChatService.requests, isEmpty);
        expect(
          controller.state.messages.last.content,
          'What should the Facebook post be about?',
        );
        expect(controller.state.pendingClarification?.requiredField, 'topic');

        await controller.sendMessage('Our summer sale');

        expect(aiChatService.requests, hasLength(1));
        expect(controller.state.pendingClarification, isNull);
        expect(
          aiChatService.requests.single
              .map((message) => message.content)
              .toList(),
          <String>[
            'Write a Facebook post',
            'What should the Facebook post be about?',
            'Our summer sale',
          ],
        );
        expect(
          (await repository.getConversation(
            controller.state.conversation!.id,
          ))?.messages.map((message) => message.content),
          contains('Our summer sale'),
        );
      },
    );

    test(
      'completes a Facebook post request when it already has a topic',
      () async {
        final repository = _MemoryConversationRepository();
        final aiChatService = _FakeAIChatService();
        final controller = _createController(
          repository,
          aiChatService: aiChatService,
        );
        addTearDown(controller.dispose);

        await controller.sendMessage(
          'Write a Facebook post about our summer sale',
        );

        expect(aiChatService.requests, hasLength(1));
        expect(controller.state.pendingClarification, isNull);
      },
    );

    test('asks one TikTok topic question only when a topic is missing', () async {
      final repository = _MemoryConversationRepository();
      final aiChatService = _FakeAIChatService();
      final controller = _createController(
        repository,
        aiChatService: aiChatService,
      );
      addTearDown(controller.dispose);

      await controller.sendMessage(
        'Help me make TikTok videos to get more views and earn money',
      );

      expect(aiChatService.requests, isEmpty);
      expect(
        controller.state.messages.last.content,
        'Do you already have a content topic, or should Ovexiq choose one for you?',
      );

      await controller.sendMessage('Easy home cooking');

      expect(aiChatService.requests, hasLength(1));
      expect(controller.state.pendingClarification, isNull);
    });

    test('completes a TikTok request when it already has a topic', () async {
      final repository = _MemoryConversationRepository();
      final aiChatService = _FakeAIChatService();
      final controller = _createController(
        repository,
        aiChatService: aiChatService,
      );
      addTearDown(controller.dispose);

      await controller.sendMessage(
        'Make TikTok videos about easy home cooking',
      );

      expect(aiChatService.requests, hasLength(1));
      expect(controller.state.pendingClarification, isNull);
    });

    test('keeps ordinary text chat on the existing completion path', () async {
      final repository = _MemoryConversationRepository();
      final aiChatService = _FakeAIChatService();
      final controller = _createController(
        repository,
        aiChatService: aiChatService,
      );
      addTearDown(controller.dispose);

      await controller.sendMessage('What is the capital of Thailand?');

      expect(aiChatService.requests, hasLength(1));
      expect(
        controller.state.messages.last.content,
        'Response to: What is the capital of Thailand?',
      );
    });

    test(
      'sends ordered context without duplicating the newest user message',
      () async {
        final repository = _MemoryConversationRepository();
        final aiChatService = _FakeAIChatService();
        final controller = _createController(
          repository,
          aiChatService: aiChatService,
        );
        addTearDown(controller.dispose);

        await controller.createNewConversation();
        await controller.sendMessage('Research Kaspa smart contracts');
        await controller.sendMessage('Summarize it in 3 bullets');

        expect(aiChatService.requests, hasLength(2));
        expect(
          aiChatService.requests.first
              .map((message) => (message.role, message.content))
              .toList(),
          <(AIMessageRole, String)>[
            (AIMessageRole.user, 'Research Kaspa smart contracts'),
          ],
        );
        expect(
          aiChatService.requests.last
              .map((message) => (message.role, message.content))
              .toList(),
          <(AIMessageRole, String)>[
            (AIMessageRole.user, 'Research Kaspa smart contracts'),
            (
              AIMessageRole.assistant,
              'Response to: Research Kaspa smart contracts',
            ),
            (AIMessageRole.user, 'Summarize it in 3 bullets'),
          ],
        );
        expect(
          aiChatService.requests.last.where(
            (message) => message.content == 'Summarize it in 3 bullets',
          ),
          hasLength(1),
        );
      },
    );

    test('uses restored history for a follow-up message', () async {
      final repository = _MemoryConversationRepository();
      final firstController = _createController(repository);
      addTearDown(firstController.dispose);

      await firstController.createNewConversation();
      await firstController.sendMessage('Research Kaspa smart contracts');

      final restoredAIChatService = _FakeAIChatService();
      final restoredController = _createController(
        repository,
        aiChatService: restoredAIChatService,
      );
      addTearDown(restoredController.dispose);

      await restoredController.loadMostRecentConversation();
      await restoredController.sendMessage('Summarize it in 3 bullets');

      expect(restoredAIChatService.requests.single, hasLength(3));
      expect(
        restoredAIChatService.requests.single
            .map((message) => message.role)
            .toList(),
        <AIMessageRole>[
          AIMessageRole.user,
          AIMessageRole.assistant,
          AIMessageRole.user,
        ],
      );
      expect(
        restoredAIChatService.requests.single.last.content,
        'Summarize it in 3 bullets',
      );
    });

    test(
      'retries the latest response with ordered context and no duplicate prompt',
      () async {
        final repository = _MemoryConversationRepository();
        final aiChatService = _FakeAIChatService(
          failingRequestNumbers: <int>{2},
        );
        final controller = _createController(
          repository,
          aiChatService: aiChatService,
        );
        addTearDown(controller.dispose);

        await controller.createNewConversation();
        await controller.sendMessage('Research Kaspa smart contracts');
        await controller.sendMessage('Summarize it in 3 bullets');

        expect(controller.state.error, isNotNull);
        expect(controller.state.error!.canRetryLastResponse, isTrue);
        expect(controller.state.messages.last.content, 'Partial response');

        await controller.regenerateLastResponse();

        expect(aiChatService.requests, hasLength(3));
        expect(
          aiChatService.requests.last
              .map((message) => (message.role, message.content))
              .toList(),
          <(AIMessageRole, String)>[
            (AIMessageRole.user, 'Research Kaspa smart contracts'),
            (
              AIMessageRole.assistant,
              'Response to: Research Kaspa smart contracts',
            ),
            (AIMessageRole.user, 'Summarize it in 3 bullets'),
          ],
        );
        expect(
          aiChatService.requests.last.where(
            (message) => message.content == 'Summarize it in 3 bullets',
          ),
          hasLength(1),
        );
        expect(controller.state.error, isNull);
        expect(
          controller.state.messages.map((message) => message.content),
          isNot(contains('Partial response')),
        );

        final persisted = await repository.getConversation(
          controller.state.conversation!.id,
        );
        expect(
          persisted!.messages
              .where(
                (message) => message.content == 'Summarize it in 3 bullets',
              )
              .length,
          1,
        );
        expect(
          persisted.messages.last.content,
          'Response to: Summarize it in 3 bullets',
        );
      },
    );

    test('validation errors are not response-retryable', () async {
      final repository = _MemoryConversationRepository();
      final controller = _createController(repository);
      addTearDown(controller.dispose);

      await controller.createNewConversation();
      await controller.loadConversation('');

      expect(controller.state.error, isNotNull);
      expect(controller.state.error!.canRetryLastResponse, isFalse);
    });
  });
}

ChatController _createController(
  _MemoryConversationRepository repository, {
  _FakeAIChatService? aiChatService,
}) {
  return ChatController(
    aiChatService: aiChatService ?? _FakeAIChatService(),
    conversationRepository: repository,
    missionSuggestionService: const MissionSuggestionService(),
  );
}

class _FakeAIChatService extends AIChatService {
  _FakeAIChatService({Set<int> failingRequestNumbers = const <int>{}})
    : _failingRequestNumbers = <int>{...failingRequestNumbers};

  final List<List<AIMessage>> requests = <List<AIMessage>>[];
  final Set<int> _failingRequestNumbers;

  @override
  Stream<AIChunk> sendMessages(List<AIMessage> messages) async* {
    requests.add(List<AIMessage>.of(messages));
    final prompt = messages.last.content;

    yield const AIChunk.status(
      provider: ProviderType.openAI,
      text: 'Generating',
    );

    if (_failingRequestNumbers.remove(requests.length)) {
      yield const AIChunk.text(
        provider: ProviderType.openAI,
        text: 'Partial response',
      );
      yield const AIChunk.error(
        provider: ProviderType.openAI,
        error: 'Temporary failure',
      );
      return;
    }

    yield AIChunk.text(
      provider: ProviderType.openAI,
      text: 'Response to: $prompt',
    );
    yield const AIChunk.done(provider: ProviderType.openAI);
  }
}

class _MemoryConversationRepository extends ConversationRepository {
  final Map<String, Conversation> _items = <String, Conversation>{};

  List<Conversation> get conversations => _items.values.toList(growable: false);

  @override
  Future<List<Conversation>> getAllConversations() async {
    final conversations = _items.values.toList(growable: false)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return conversations;
  }

  @override
  Future<Conversation?> getConversation(String conversationId) async {
    return _items[conversationId];
  }

  @override
  Future<void> saveConversation(Conversation conversation) async {
    _items[conversation.id] = conversation;
  }
}
