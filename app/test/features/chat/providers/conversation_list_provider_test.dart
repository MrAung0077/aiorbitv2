import 'package:aiorbit/core/ai/ai.dart';
import 'package:aiorbit/features/chat/models/chat_message.dart';
import 'package:aiorbit/features/chat/models/conversation.dart';
import 'package:aiorbit/features/chat/providers/chat_controller.dart';
import 'package:aiorbit/features/chat/providers/conversation_list_provider.dart';
import 'package:aiorbit/features/chat/repositories/conversation_repository.dart';
import 'package:aiorbit/features/chat/services/ai_chat_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Continue conversation is excluded from the five Recent items', () {
    final conversations = List<Conversation>.generate(
      7,
      (index) => _conversation(
        id: 'conversation-$index',
        updatedAt: DateTime(2026, 1, 7 - index),
      ),
    );

    final recent = selectRecentConversations(conversations);

    expect(recent, hasLength(5));
    expect(recent.map((conversation) => conversation.id), <String>[
      'conversation-1',
      'conversation-2',
      'conversation-3',
      'conversation-4',
      'conversation-5',
    ]);
    expect(
      recent.any((conversation) => conversation.id == 'conversation-0'),
      isFalse,
    );
  });

  test('conversations are ordered by updatedAt descending', () {
    final ordered = orderConversationsByUpdatedAt(<Conversation>[
      _conversation(id: 'oldest', updatedAt: DateTime(2026, 1, 1)),
      _conversation(id: 'newest', updatedAt: DateTime(2026, 1, 3)),
      _conversation(id: 'middle', updatedAt: DateTime(2026, 1, 2)),
    ]);

    expect(ordered.map((conversation) => conversation.id), <String>[
      'newest',
      'middle',
      'oldest',
    ]);
  });

  test('list refreshes and reorders after a conversation update', () async {
    final repository = _MemoryConversationRepository(<Conversation>[
      _conversation(id: 'older', updatedAt: DateTime(2026, 1, 1)),
      _conversation(id: 'latest', updatedAt: DateTime(2026, 1, 2)),
    ]);
    final container = ProviderContainer(
      overrides: <Override>[
        conversationRepositoryProvider.overrideWithValue(repository),
        aiChatServiceProvider.overrideWithValue(_FakeAIChatService()),
      ],
    );
    addTearDown(container.dispose);

    final initial = await container.read(conversationListProvider.future);
    expect(initial.first.id, 'latest');

    final controller = container.read(chatControllerProvider.notifier);
    await controller.loadConversation('older');
    await controller.sendMessage('A new follow-up');

    final refreshed = await container.read(conversationListProvider.future);

    expect(refreshed.first.id, 'older');
    expect(refreshed.first.updatedAt.isAfter(DateTime(2026, 1, 2)), isTrue);
    expect(refreshed.first.preview, 'Response to: A new follow-up');
  });
}

Conversation _conversation({required String id, required DateTime updatedAt}) {
  return Conversation(
    id: id,
    title: 'Title $id',
    messages: <ChatMessage>[
      ChatMessage(
        id: 'message-$id',
        role: ChatRole.user,
        content: 'Preview $id',
        createdAt: updatedAt,
      ),
    ],
    createdAt: updatedAt,
    updatedAt: updatedAt,
  );
}

class _FakeAIChatService extends AIChatService {
  @override
  Stream<AIChunk> sendMessages(List<AIMessage> messages) async* {
    yield AIChunk.text(
      provider: ProviderType.openAI,
      text: 'Response to: ${messages.last.content}',
    );
    yield const AIChunk.done(provider: ProviderType.openAI);
  }
}

class _MemoryConversationRepository extends ConversationRepository {
  _MemoryConversationRepository(Iterable<Conversation> conversations)
    : _items = <String, Conversation>{
        for (final conversation in conversations) conversation.id: conversation,
      };

  final Map<String, Conversation> _items;

  @override
  Future<List<Conversation>> getAllConversations() async {
    return _items.values.toList(growable: false);
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
