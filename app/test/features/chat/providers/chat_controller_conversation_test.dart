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
  final List<List<AIMessage>> requests = <List<AIMessage>>[];

  @override
  Stream<AIChunk> sendMessages(List<AIMessage> messages) async* {
    requests.add(List<AIMessage>.of(messages));
    final prompt = messages.last.content;

    yield const AIChunk.status(
      provider: ProviderType.openAI,
      text: 'Generating',
    );
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
