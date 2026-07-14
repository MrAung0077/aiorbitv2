import 'chat_message.dart';

class Conversation {
  const Conversation({
    required this.id,
    required this.title,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final List<ChatMessage> messages;
  final DateTime createdAt;
  final DateTime updatedAt;

  Conversation copyWith({
    String? id,
    String? title,
    List<ChatMessage>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Conversation(
      id: id ?? this.id,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isEmpty => messages.isEmpty;

  String get preview {
    if (messages.isEmpty) {
      return 'No messages yet';
    }

    final text = messages.last.content.trim();

    if (text.length <= 80) {
      return text;
    }

    return '${text.substring(0, 80)}...';
  }

  static String generateTitleFromPrompt(String prompt) {
    final cleanPrompt = prompt.trim().replaceAll(RegExp(r'\s+'), ' ');

    if (cleanPrompt.isEmpty) {
      return 'New Chat';
    }

    if (cleanPrompt.length <= 36) {
      return cleanPrompt;
    }

    return '${cleanPrompt.substring(0, 36)}...';
  }
}
