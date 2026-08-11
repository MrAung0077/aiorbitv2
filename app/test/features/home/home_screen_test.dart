import 'package:aiorbit/features/chat/models/chat_message.dart';
import 'package:aiorbit/features/chat/models/conversation.dart';
import 'package:aiorbit/features/chat/providers/chat_controller.dart';
import 'package:aiorbit/features/chat/repositories/conversation_repository.dart';
import 'package:aiorbit/features/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Home keeps its core actions without a placeholder Account action',
    (tester) async {
      final updatedAt = DateTime(2026, 8, 11);
      final conversation = Conversation(
        id: 'continue-conversation',
        title: 'Continue beta mission',
        messages: <ChatMessage>[
          ChatMessage(
            id: 'user-message',
            role: ChatRole.user,
            content: 'Prepare my beta launch plan',
            createdAt: updatedAt,
          ),
        ],
        createdAt: updatedAt,
        updatedAt: updatedAt,
      );
      final container = ProviderContainer(
        overrides: <Override>[
          conversationRepositoryProvider.overrideWithValue(
            _MemoryConversationRepository(<Conversation>[conversation]),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Account'), findsNothing);
      expect(
        find.text(
          'Tell Ovexiq your goal. It will help you move from idea to finished result.',
        ),
        findsOneWidget,
      );
      expect(find.byTooltip('Send'), findsOneWidget);
      expect(find.text('Quick start'), findsOneWidget);
      expect(find.text('Create'), findsOneWidget);
      expect(find.text('Research'), findsOneWidget);
      expect(find.text('Write'), findsOneWidget);
      expect(find.text('Plan'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Continue beta mission'),
        400,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Continue beta mission'), findsOneWidget);
    },
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
