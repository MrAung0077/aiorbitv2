import 'package:isar_community/isar.dart';

import '../../../core/database/isar_service.dart';
import '../data/models/chat_message_record.dart';
import '../data/models/conversation_record.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';

class ConversationRepository {
  Isar get _isar => IsarService.instance;

  Future<List<Conversation>> getAllConversations() async {
    final records = await _isar.conversationRecords
        .where()
        .sortByUpdatedAtDesc()
        .findAll();

    return records.map(_recordToConversation).toList(growable: false);
  }

  Future<Conversation?> getConversation(String conversationId) async {
    final record = await _isar.conversationRecords
        .filter()
        .conversationIdEqualTo(conversationId)
        .findFirst();

    if (record == null) {
      return null;
    }

    return _recordToConversation(record);
  }

  Future<void> saveConversation(Conversation conversation) async {
    final existing = await _isar.conversationRecords
        .filter()
        .conversationIdEqualTo(conversation.id)
        .findFirst();

    final record = _conversationToRecord(
      conversation,
      databaseId: existing?.id,
    );

    await _isar.writeTxn(() async {
      await _isar.conversationRecords.put(record);
    });
  }

  Future<void> deleteConversation(String conversationId) async {
    final record = await _isar.conversationRecords
        .filter()
        .conversationIdEqualTo(conversationId)
        .findFirst();

    if (record == null) {
      return;
    }

    await _isar.writeTxn(() async {
      await _isar.conversationRecords.delete(record.id);
    });
  }

  Future<void> deleteAllConversations() async {
    await _isar.writeTxn(() async {
      await _isar.conversationRecords.clear();
    });
  }

  ConversationRecord _conversationToRecord(
    Conversation conversation, {
    Id? databaseId,
  }) {
    return ConversationRecord()
      ..id = databaseId ?? Isar.autoIncrement
      ..conversationId = conversation.id
      ..title = conversation.title
      ..createdAt = conversation.createdAt
      ..updatedAt = conversation.updatedAt
      ..messages = conversation.messages
          .map(_messageToRecord)
          .toList(growable: false);
  }

  ChatMessageRecord _messageToRecord(ChatMessage message) {
    return ChatMessageRecord()
      ..messageId = message.id
      ..role = message.role.name
      ..content = message.content
      ..createdAt = message.createdAt
      ..isError = message.isError;
  }

  Conversation _recordToConversation(ConversationRecord record) {
    return Conversation(
      id: record.conversationId,
      title: record.title,
      messages: record.messages.map(_recordToMessage).toList(growable: false),
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
    );
  }

  ChatMessage _recordToMessage(ChatMessageRecord record) {
    return ChatMessage(
      id: record.messageId,
      role: _parseRole(record.role),
      content: record.content,
      createdAt: record.createdAt,
      isError: record.isError,
    );
  }

  ChatRole _parseRole(String value) {
    return ChatRole.values.firstWhere(
      (role) => role.name == value,
      orElse: () => ChatRole.assistant,
    );
  }
}
