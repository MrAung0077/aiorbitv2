import 'package:isar_community/isar.dart';

import 'chat_message_record.dart';

part 'conversation_record.g.dart';

@collection
class ConversationRecord {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  String conversationId = '';

  String title = 'New Chat';

  List<ChatMessageRecord> messages = [];

  DateTime createdAt = DateTime.now();

  DateTime updatedAt = DateTime.now();
}
