import 'package:isar_community/isar.dart';

import '../../../core/database/isar_service.dart';
import '../data/models/chat_message_record.dart';
import '../data/models/conversation_record.dart';
import '../models/artifact.dart';
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
      ..isError = message.isError
      ..attachmentId = message.attachment?.id
      ..attachmentMimeType = message.attachment?.mimeType
      ..attachmentLocalFilePath = message.attachment?.localFilePath
      ..attachmentSourcePrompt = message.attachment?.sourcePrompt
      ..attachmentSourceMessageId = message.attachment?.sourceMessageId
      ..storedAttachmentArtifactId = message.attachment?.artifact?.id
      ..storedAttachmentArtifactType = message.attachment?.artifact?.type.name
      ..storedAttachmentArtifactCreatedAt =
          message.attachment?.artifact?.createdAt
      ..storedAttachmentArtifactVersionId =
          message.attachment?.artifactVersion?.id
      ..storedAttachmentRemoteStorageKey =
          message.attachment?.artifactVersion?.remoteStorageKey
      ..storedAttachmentSourceArtifactVersionId =
          message.attachment?.artifactVersion?.sourceArtifactVersionId
      ..storedAttachmentArtifactVersionCreatedAt =
          message.attachment?.artifactVersion?.createdAt
      ..zStoredAttachmentArtifactVersionByteSize =
          message.attachment?.artifactVersion?.byteSize
      ..zStoredAttachmentArtifactVersionFileName =
          message.attachment?.artifactVersion?.fileName;
  }

  Conversation _recordToConversation(ConversationRecord record) {
    return Conversation(
      id: record.conversationId,
      title: record.title,
      messages: record.messages
          .map((message) => _recordToMessage(message, record.conversationId))
          .toList(growable: false),
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
    );
  }

  ChatMessage _recordToMessage(
    ChatMessageRecord record,
    String conversationId,
  ) {
    return ChatMessage(
      id: record.messageId,
      role: _parseRole(record.role),
      content: record.content,
      createdAt: record.createdAt,
      isError: record.isError,
      attachment: _recordToAttachment(record, conversationId),
    );
  }

  ChatAttachment? _recordToAttachment(
    ChatMessageRecord record,
    String conversationId,
  ) {
    final id = record.attachmentId?.trim();
    final mimeType = record.attachmentMimeType?.trim();
    final localFilePath = record.attachmentLocalFilePath?.trim();

    if (id == null ||
        id.isEmpty ||
        mimeType == null ||
        mimeType.isEmpty ||
        localFilePath == null ||
        localFilePath.isEmpty) {
      return null;
    }

    final artifact = _recordToArtifact(record, conversationId);
    final artifactVersion = _recordToArtifactVersion(
      record,
      artifactId: artifact?.id,
      mimeType: mimeType,
      localFilePath: localFilePath,
    );

    return ChatAttachment(
      id: id,
      mimeType: mimeType,
      localFilePath: localFilePath,
      sourcePrompt: _optionalValue(record.attachmentSourcePrompt),
      sourceMessageId: _optionalValue(record.attachmentSourceMessageId),
      artifact: artifact,
      artifactVersion: artifactVersion,
    );
  }

  Artifact? _recordToArtifact(ChatMessageRecord record, String conversationId) {
    final artifactId = _optionalValue(record.storedAttachmentArtifactId);
    final typeName = _optionalValue(record.storedAttachmentArtifactType);
    final createdAt = record.storedAttachmentArtifactCreatedAt;
    if (artifactId == null || typeName == null || createdAt == null) {
      return null;
    }

    final type = ArtifactType.values.where((type) => type.name == typeName);
    if (type.isEmpty) {
      return null;
    }

    return Artifact(
      id: artifactId,
      conversationId: conversationId,
      type: type.first,
      createdAt: createdAt,
    );
  }

  ArtifactVersion? _recordToArtifactVersion(
    ChatMessageRecord record, {
    required String? artifactId,
    required String mimeType,
    required String localFilePath,
  }) {
    final versionId = _optionalValue(record.storedAttachmentArtifactVersionId);
    final createdAt = record.storedAttachmentArtifactVersionCreatedAt;
    if (artifactId == null || versionId == null || createdAt == null) {
      return null;
    }

    return ArtifactVersion(
      id: versionId,
      artifactId: artifactId,
      mimeType: mimeType,
      localPath: localFilePath,
      remoteStorageKey: _optionalValue(record.storedAttachmentRemoteStorageKey),
      sourceArtifactVersionId: _optionalValue(
        record.storedAttachmentSourceArtifactVersionId,
      ),
      fileName: _optionalValue(record.zStoredAttachmentArtifactVersionFileName),
      byteSize: record.zStoredAttachmentArtifactVersionByteSize,
      createdAt: createdAt,
    );
  }

  String? _optionalValue(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  ChatRole _parseRole(String value) {
    return ChatRole.values.firstWhere(
      (role) => role.name == value,
      orElse: () => ChatRole.assistant,
    );
  }
}
