import 'package:aiorbit/features/chat/ai_chat_screen.dart';
import 'package:aiorbit/features/chat/conversation_history_screen.dart';
import 'package:aiorbit/features/chat/models/chat_message.dart';
import 'package:aiorbit/features/chat/models/conversation.dart';
import 'package:aiorbit/features/chat/providers/chat_controller.dart';
import 'package:aiorbit/features/chat/repositories/conversation_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tapping a History item reopens the exact conversation', (
    tester,
  ) async {
    final selectedConversation = _conversation(
      id: 'selected',
      title: 'Selected conversation',
      updatedAt: DateTime(2026, 1, 1),
      prompt: 'Research the latest AI trends',
    );
    final container = ProviderContainer(
      overrides: <Override>[
        conversationRepositoryProvider.overrideWithValue(
          _MemoryConversationRepository(<Conversation>[
            _conversation(
              id: 'latest',
              title: 'Latest conversation',
              updatedAt: DateTime(2026, 1, 2),
              prompt: 'Hello',
            ),
            selectedConversation,
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ConversationHistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Selected conversation'));
    await tester.pumpAndSettle();

    final chatState = container.read(chatControllerProvider);

    expect(chatState.conversation?.id, selectedConversation.id);
    expect(chatState.messages.single.content, 'Research the latest AI trends');
    expect(chatState.missionSuggestion, isNotNull);
    expect(find.byType(AIChatScreen), findsOneWidget);
  });

  testWidgets('shows an empty state when no conversations exist', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: <Override>[
        conversationRepositoryProvider.overrideWithValue(
          _MemoryConversationRepository(const <Conversation>[]),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ConversationHistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No conversations yet'), findsOneWidget);
    expect(find.text('Your conversations will appear here.'), findsOneWidget);
  });
}

Conversation _conversation({
  required String id,
  required String title,
  required DateTime updatedAt,
  required String prompt,
}) {
  return Conversation(
    id: id,
    title: title,
    messages: <ChatMessage>[
      ChatMessage(
        id: 'message-$id',
        role: ChatRole.user,
        content: prompt,
        createdAt: updatedAt,
      ),
    ],
    createdAt: updatedAt,
    updatedAt: updatedAt,
  );
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
}
