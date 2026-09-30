import 'artifact.dart';

enum ChatRole { user, assistant, system }

/// Provider-neutral metadata for a finished Chat result stored on this device.
class ChatAttachment {
  const ChatAttachment({
    required this.id,
    required this.mimeType,
    required this.localFilePath,
    this.sourcePrompt,
    this.sourceMessageId,
    this.artifact,
    this.artifactVersion,
  });

  final String id;
  final String mimeType;
  final String localFilePath;

  /// The provider-neutral prompt that created this result, retained for a
  /// future prompt-based revision.
  final String? sourcePrompt;

  /// The user message that initiated this result, when available.
  final String? sourceMessageId;

  /// Nullable while existing persisted image results migrate naturally on
  /// their next creation. The local attachment fields remain authoritative for
  /// legacy records.
  final Artifact? artifact;
  final ArtifactVersion? artifactVersion;

  String? get artifactId => artifact?.id;
  String? get artifactVersionId => artifactVersion?.id;
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

  // Local status marker stored in existing message fields, never AI context.
  bool get isStopped =>
      role == ChatRole.assistant && id.startsWith('chat-stopped-');

  ChatMessage copyWith({
    String? content,
    String? providerName,
    bool? isError,
    ChatAttachment? attachment,
  }) {
    return ChatMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      createdAt: createdAt,
      providerName: providerName ?? this.providerName,
      isError: isError ?? this.isError,
      attachment: attachment ?? this.attachment,
    );
  }
}
