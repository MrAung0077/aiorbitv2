import 'package:aiorbit/core/ai/ai.dart';
import 'package:aiorbit/features/chat/models/chat_message.dart';
import 'package:aiorbit/features/chat/models/conversation.dart';
import 'package:aiorbit/features/chat/providers/chat_controller.dart';
import 'package:aiorbit/features/chat/repositories/conversation_repository.dart';
import 'package:aiorbit/features/chat/services/ai_chat_service.dart';
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
          'Create a peaceful sunset over a mountain lake.',
        );

        expect(aiChatService.requests, isEmpty);
        expect(controller.state.imageActionRequest, isNotNull);
        expect(
          controller.state.imageActionRequest!.subject,
          'peaceful sunset over a mountain lake',
        );
        expect(controller.state.messages, hasLength(1));
        expect(controller.state.messages.single.content, contains('sunset'));
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

    test('persists exactly one generated image-result message', () async {
      final repository = _MemoryConversationRepository();
      final controller = _createController(repository);
      addTearDown(controller.dispose);

      await controller.sendMessage('Create a picture of Buddha');
      final conversationId = controller.state.conversation!.id;
      final sourceMessageId = controller.state.messages.single.id;
      const attachment = ChatAttachment(
        id: 'image-result',
        mimeType: 'image/png',
        localFilePath: '/safe/local/image.png',
      );

      expect(
        await controller.persistGeneratedImageResult(
          conversationId: conversationId,
          sourceMessageId: sourceMessageId,
          attachment: attachment,
        ),
        isTrue,
      );
      expect(
        await controller.persistGeneratedImageResult(
          conversationId: conversationId,
          sourceMessageId: sourceMessageId,
          attachment: attachment,
        ),
        isTrue,
      );

      final persisted = await repository.getConversation(conversationId);
      expect(
        persisted!.messages.where((message) => message.attachment != null),
        hasLength(1),
      );
      expect(persisted.messages.last.content, 'Done');
      expect(
        persisted.messages.last.attachment?.localFilePath,
        contains('image.png'),
      );
    });

    test(
      'refines a persisted image with one new prompt-based version',
      () async {
        final repository = _MemoryConversationRepository();
        final aiChatService = _FakeAIChatService();
        final controller = _createController(
          repository,
          aiChatService: aiChatService,
        );
        addTearDown(controller.dispose);

        await controller.sendMessage(
          'Create a peaceful sunset over a mountain lake.',
        );
        final conversationId = controller.state.conversation!.id;
        final originalSourceMessageId = controller.state.messages.single.id;
        final originalAttachment = ChatAttachment(
          id: 'original-image',
          mimeType: 'image/png',
          localFilePath: '/safe/original.png',
          sourcePrompt: 'peaceful sunset over a mountain lake',
          sourceMessageId: originalSourceMessageId,
        );
        expect(
          await controller.persistGeneratedImageResult(
            conversationId: conversationId,
            sourceMessageId: originalSourceMessageId,
            attachment: originalAttachment,
          ),
          isTrue,
        );
        final originalResultMessageId = controller.state.messages.last.id;

        expect(
          await controller.beginImageRevision(
            resultMessageId: originalResultMessageId,
          ),
          isTrue,
        );
        expect(aiChatService.requests, isEmpty);
        expect(
          controller.state.messages.last.content,
          'What would you like to change?',
        );
        expect(
          controller.state.pendingImageRevision?.sourcePrompt,
          'peaceful sunset over a mountain lake',
        );

        await controller.sendMessage(
          'Make the sky more purple and add two birds.',
        );

        expect(aiChatService.requests, isEmpty);
        expect(controller.state.pendingImageRevision, isNull);
        expect(controller.state.imageActionRequest, isNotNull);
        final refinedPrompt = controller.state.imageActionRequest!.subject;
        expect(refinedPrompt, contains('peaceful sunset over a mountain lake'));
        expect(
          refinedPrompt,
          contains('Make the sky more purple and add two birds.'),
        );

        final refinedSourceMessageId = controller.state.messages.last.id;
        final refinedAttachment = ChatAttachment(
          id: 'refined-image',
          mimeType: 'image/png',
          localFilePath: '/safe/refined.png',
          sourcePrompt: refinedPrompt,
          sourceMessageId: refinedSourceMessageId,
        );
        expect(
          await controller.persistGeneratedImageResult(
            conversationId: conversationId,
            sourceMessageId: refinedSourceMessageId,
            attachment: refinedAttachment,
          ),
          isTrue,
        );

        final restoredController = _createController(repository);
        addTearDown(restoredController.dispose);
        await restoredController.loadConversation(conversationId);
        final restoredAttachments = restoredController.state.messages
            .where((message) => message.attachment != null)
            .map((message) => message.attachment!)
            .toList(growable: false);

        expect(restoredAttachments, hasLength(2));
        expect(restoredAttachments.first.localFilePath, '/safe/original.png');
        expect(restoredAttachments.last.localFilePath, '/safe/refined.png');
        final refinedResultMessage = restoredController.state.messages
            .lastWhere((message) => message.attachment?.id == 'refined-image');
        expect(
          await restoredController.beginImageRevision(
            resultMessageId: refinedResultMessage.id,
          ),
          isTrue,
        );
        expect(
          restoredController.state.pendingImageRevision?.sourcePrompt,
          refinedPrompt,
        );
      },
    );

    test('an unrelated request cancels a pending image revision', () async {
      final repository = _MemoryConversationRepository();
      final aiChatService = _FakeAIChatService();
      final controller = _createController(
        repository,
        aiChatService: aiChatService,
      );
      addTearDown(controller.dispose);

      await controller.sendMessage('Create a picture of Buddha');
      final conversationId = controller.state.conversation!.id;
      final sourceMessageId = controller.state.messages.single.id;
      await controller.persistGeneratedImageResult(
        conversationId: conversationId,
        sourceMessageId: sourceMessageId,
        attachment: ChatAttachment(
          id: 'buddha-image',
          mimeType: 'image/png',
          localFilePath: '/safe/buddha.png',
          sourcePrompt: 'Buddha',
          sourceMessageId: sourceMessageId,
        ),
      );
      await controller.beginImageRevision(
        resultMessageId: controller.state.messages.last.id,
      );

      await controller.sendMessage(
        'Write a Facebook post about our summer sale',
      );

      expect(controller.state.pendingImageRevision, isNull);
      expect(controller.state.imageActionRequest, isNull);
      expect(aiChatService.requests, hasLength(1));
    });

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

      expect(aiChatService.requests, isEmpty);
      expect(controller.state.pendingClarification, isNull);
      expect(
        controller.state.messages.last.content,
        'Video creation isn’t connected yet.',
      );
      expect(controller.state.missionSuggestion, isNull);
    });

    test(
      'does not claim to create TikTok videos when a topic is provided',
      () async {
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

        expect(aiChatService.requests, isEmpty);
        expect(controller.state.pendingClarification, isNull);
        expect(
          controller.state.messages.last.content,
          'Video creation isn’t connected yet.',
        );
      },
    );

    test(
      'rejects video editing without text completion or Mission work',
      () async {
        final repository = _MemoryConversationRepository();
        final aiChatService = _FakeAIChatService();
        final controller = _createController(
          repository,
          aiChatService: aiChatService,
        );
        addTearDown(controller.dispose);

        await controller.sendMessage('Edit these 5 videos into one video');

        expect(aiChatService.requests, isEmpty);
        expect(controller.state.missionSuggestion, isNull);
        expect(
          controller.state.messages.map((message) => message.content),
          <String>[
            'Edit these 5 videos into one video',
            'Video editing isn’t connected yet.',
          ],
        );
        expect(
          controller.state.messages.last.content,
          isNot(contains('Mission')),
        );
        expect(controller.state.messages.last.content, isNot(contains('Task')));
      },
    );

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
