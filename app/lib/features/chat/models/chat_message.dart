enum ChatRole { user, assistant, system }

/// Provider-neutral metadata for a finished Chat result stored on this device.
class ChatAttachment {
  const ChatAttachment({
    required this.id,
    required this.mimeType,
    required this.localFilePath,
  });

  final String id;
  final String mimeType;
  final String localFilePath;
}

class ChatMessage {
  final String id;
  final ChatRole role;
  final String content;
  final DateTime createdAt;
  final String? providerName;
  final bool isError;
  final ChatAttachment? attachment;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.providerName,
    this.isError = false,
    this.attachment,
  });

  bool get isUser => role == ChatRole.user;
}
