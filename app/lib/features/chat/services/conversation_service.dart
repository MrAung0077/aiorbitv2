import '../models/chat_message.dart';
import '../models/conversation.dart';

class ConversationService {
  final List<Conversation> _conversations = [];

  List<Conversation> get conversations {
    final items = List<Conversation>.from(_conversations);
    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return items;
  }

  Conversation createConversation({String? firstPrompt}) {
    final now = DateTime.now();

    final conversation = Conversation(
      id: now.microsecondsSinceEpoch.toString(),
      title: firstPrompt == null || firstPrompt.trim().isEmpty
          ? 'New Chat'
          : Conversation.generateTitleFromPrompt(firstPrompt),
      messages: const [],
      createdAt: now,
      updatedAt: now,
    );

    _conversations.add(conversation);
    return conversation;
  }

  Conversation? getConversationById(String id) {
    try {
      return _conversations.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }

  Conversation addMessage({
    required String conversationId,
    required ChatMessage message,
  }) {
    final index = _conversations.indexWhere(
      (item) => item.id == conversationId,
    );

    if (index == -1) {
      throw Exception('Conversation not found.');
    }

    final current = _conversations[index];

    final updated = current.copyWith(
      messages: [...current.messages, message],
      updatedAt: DateTime.now(),
    );

    _conversations[index] = updated;
    return updated;
  }

  Conversation renameConversation({
    required String conversationId,
    required String title,
  }) {
    final index = _conversations.indexWhere(
      (item) => item.id == conversationId,
    );

    if (index == -1) {
      throw Exception('Conversation not found.');
    }

    final updated = _conversations[index].copyWith(
      title: title.trim().isEmpty ? 'New Chat' : title.trim(),
      updatedAt: DateTime.now(),
    );

    _conversations[index] = updated;
    return updated;
  }

  void deleteConversation(String conversationId) {
    _conversations.removeWhere((item) => item.id == conversationId);
  }

  void clearAll() {
    _conversations.clear();
  }
}
