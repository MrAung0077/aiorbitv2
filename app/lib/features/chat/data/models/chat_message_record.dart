import 'package:isar_community/isar.dart';

part 'chat_message_record.g.dart';

@embedded
class ChatMessageRecord {
  String messageId = '';

  String role = 'user';

  String content = '';

  DateTime createdAt = DateTime.now();

  bool isError = false;
}
