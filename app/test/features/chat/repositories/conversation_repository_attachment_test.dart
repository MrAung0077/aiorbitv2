import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:aiorbit/core/database/isar_service.dart';
import 'package:aiorbit/features/chat/models/artifact.dart';
import 'package:aiorbit/features/chat/models/chat_message.dart';
import 'package:aiorbit/features/chat/models/conversation.dart';
import 'package:aiorbit/features/chat/repositories/conversation_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

void main() {
  late Directory databaseDirectory;
  late String databaseName;

  setUpAll(_initializeTestIsarCore);

  setUp(() async {
    databaseDirectory = await Directory.systemTemp.createTemp(
      'aiorbit-conversation-attachment-',
    );
    databaseName =
        'conversation-attachment-${DateTime.now().microsecondsSinceEpoch}';
    await IsarService.initialize(
      directoryPath: databaseDirectory.path,
      name: databaseName,
      inspector: false,
    );
  });

  tearDown(() async {
    await IsarService.close();
    if (await databaseDirectory.exists()) {
      await databaseDirectory.delete(recursive: true);
    }
  });

  test(
    'round-trips normal text and a generated image attachment through Isar',
    () async {
      final now = DateTime(2026, 8, 24, 12);
      final artifact = Artifact(
        id: 'image-artifact',
        conversationId: 'image-conversation',
        type: ArtifactType.image,
        createdAt: now,
      );
      final attachment = ChatAttachment(
        id: 'generated-image-result',
        mimeType: 'image/png',
        localFilePath: '/app/documents/ovexiq_generated_images/image.png',
        sourcePrompt: 'Buddha meditating beneath a bodhi tree',
        sourceMessageId: 'user-message',
        artifact: artifact,
        artifactVersion: ArtifactVersion(
          id: 'image-version-1',
          artifactId: artifact.id,
          mimeType: 'image/png',
          localPath: '/app/documents/ovexiq_generated_images/image.png',
          remoteStorageKey: 'artifacts/image-artifact/image-version-1.png',
          createdAt: now.add(const Duration(seconds: 1)),
        ),
      );
      final conversation = Conversation(
        id: 'image-conversation',
        title: 'Buddha image',
        messages: <ChatMessage>[
          ChatMessage(
            id: 'user-message',
            role: ChatRole.user,
            content: 'Create a picture of Buddha',
            createdAt: now,
          ),
          ChatMessage(
            id: 'image-message',
            role: ChatRole.assistant,
            content: 'Done',
            createdAt: now.add(const Duration(seconds: 1)),
            attachment: attachment,
          ),
        ],
        createdAt: now,
        updatedAt: now.add(const Duration(seconds: 1)),
      );

      await ConversationRepository().saveConversation(conversation);
      await IsarService.close();
      await IsarService.initialize(
        directoryPath: databaseDirectory.path,
        name: databaseName,
        inspector: false,
      );

      final restored = await ConversationRepository().getConversation(
        conversation.id,
      );

      expect(restored?.messages.first.content, 'Create a picture of Buddha');
      expect(restored?.messages.last.content, 'Done');
      expect(restored?.messages.last.attachment?.id, attachment.id);
      expect(restored?.messages.last.attachment?.mimeType, attachment.mimeType);
      expect(
        restored?.messages.last.attachment?.localFilePath,
        attachment.localFilePath,
      );
      expect(
        restored?.messages.last.attachment?.sourcePrompt,
        attachment.sourcePrompt,
      );
      expect(
        restored?.messages.last.attachment?.sourceMessageId,
        attachment.sourceMessageId,
      );
      expect(restored?.messages.last.attachment?.artifact?.id, artifact.id);
      expect(
        restored?.messages.last.attachment?.artifact?.conversationId,
        conversation.id,
      );
      expect(
        restored?.messages.last.attachment?.artifactVersion?.id,
        attachment.artifactVersion?.id,
      );
      expect(
        restored?.messages.last.attachment?.artifactVersion?.remoteStorageKey,
        attachment.artifactVersion?.remoteStorageKey,
      );
    },
  );

  test('reads legacy image attachments without artifact metadata', () async {
    final now = DateTime(2026, 8, 24, 12);
    final conversation = Conversation(
      id: 'legacy-image-conversation',
      title: 'Legacy image',
      messages: <ChatMessage>[
        ChatMessage(
          id: 'legacy-image-message',
          role: ChatRole.assistant,
          content: 'Done',
          createdAt: now,
          attachment: const ChatAttachment(
            id: 'legacy-image-result',
            mimeType: 'image/png',
            localFilePath: '/app/documents/legacy-image.png',
          ),
        ),
      ],
      createdAt: now,
      updatedAt: now,
    );

    await ConversationRepository().saveConversation(conversation);
    await IsarService.close();
    await IsarService.initialize(
      directoryPath: databaseDirectory.path,
      name: databaseName,
      inspector: false,
    );

    final restored = await ConversationRepository().getConversation(
      conversation.id,
    );

    expect(
      restored?.messages.single.attachment?.localFilePath,
      endsWith('.png'),
    );
    expect(restored?.messages.single.attachment?.artifact, isNull);
    expect(restored?.messages.single.attachment?.artifactVersion, isNull);
  });

  test(
    'reopens a persisted local video artifact without re-selecting it',
    () async {
      final now = DateTime(2026, 8, 26, 12);
      final artifact = Artifact(
        id: 'video-artifact',
        conversationId: 'video-conversation',
        type: ArtifactType.video,
        createdAt: now,
      );
      final conversation = Conversation(
        id: 'video-conversation',
        title: 'Video',
        messages: <ChatMessage>[
          ChatMessage(
            id: 'video-message',
            role: ChatRole.user,
            content: 'Video added',
            createdAt: now,
            attachment: ChatAttachment(
              id: 'video-attachment',
              mimeType: 'video/mp4',
              localFilePath: '/app/documents/ovexiq_media/videos/video.mp4',
              artifact: artifact,
              artifactVersion: ArtifactVersion(
                id: 'video-version',
                artifactId: artifact.id,
                mimeType: 'video/mp4',
                localPath: '/app/documents/ovexiq_media/videos/video.mp4',
                fileName: 'video.mp4',
                byteSize: 4096,
                createdAt: now,
              ),
            ),
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      await ConversationRepository().saveConversation(conversation);
      await IsarService.close();
      await IsarService.initialize(
        directoryPath: databaseDirectory.path,
        name: databaseName,
        inspector: false,
      );

      final restored = await ConversationRepository().getConversation(
        conversation.id,
      );
      final attachment = restored?.messages.single.attachment;
      expect(attachment?.artifact?.type, ArtifactType.video);
      expect(attachment?.artifactVersion?.fileName, 'video.mp4');
      expect(attachment?.artifactVersion?.byteSize, 4096);
      expect(attachment?.localFilePath, contains('ovexiq_media'));
    },
  );
}

Future<void> _initializeTestIsarCore() async {
  final packageConfigFile = File('.dart_tool/package_config.json').absolute;
  final packageConfig = jsonDecode(await packageConfigFile.readAsString());
  final packages = packageConfig['packages'] as List<dynamic>;
  final flutterLibraries = packages.cast<Map<String, dynamic>>().firstWhere(
    (package) => package['name'] == 'isar_community_flutter_libs',
  );
  final rootUri = packageConfigFile.uri.resolve(
    flutterLibraries['rootUri'] as String,
  );
  final libraryUri = Directory.fromUri(
    rootUri,
  ).uri.resolve(_platformLibraryPath());

  await Isar.initializeIsarCore(
    libraries: <Abi, String>{Abi.current(): File.fromUri(libraryUri).path},
  );
}

String _platformLibraryPath() {
  if (Platform.isWindows) {
    return 'windows/libisar.dll';
  }

  if (Platform.isLinux) {
    return 'linux/libisar.so';
  }

  if (Platform.isMacOS) {
    return 'macos/libisar.dylib';
  }

  throw UnsupportedError('Isar attachment tests are desktop-only.');
}
