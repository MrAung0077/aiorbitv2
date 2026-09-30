import 'dart:async';

import 'package:aiorbit/core/ai/ai.dart';
import 'package:aiorbit/features/chat/models/artifact.dart';
import 'package:aiorbit/features/chat/models/chat_message.dart';
import 'package:aiorbit/features/chat/models/conversation.dart';
import 'package:aiorbit/features/chat/providers/chat_controller.dart';
import 'package:aiorbit/features/chat/repositories/conversation_repository.dart';
import 'package:aiorbit/features/chat/services/ai_chat_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatController conversation lifecycle', () {
    test('creates and persists a new empty conversation', () async {
      final repository = _MemoryConversationRepository();
      final controller = _createController(repository);
      addTearDown(controller.dispose);

      final created = await controller.createNewConversation();

      expect(created, isTrue);
      expect(controller.state.conversation, isNotNull);
      expect(controller.state.messages, isEmpty);
      expect(repository.conversations, hasLength(1));
      expect(repository.conversations.single.title, 'New Chat');
    });

    test('does not leak messages between conversations', () async {
      final repository = _MemoryConversationRepository();
      final controller = _createController(repository);
      addTearDown(controller.dispose);

      await controller.createNewConversation();
      await controller.sendMessage('First conversation prompt');
      final firstId = controller.state.conversation!.id;

      await controller.createNewConversation();
      expect(controller.state.messages, isEmpty);

      await controller.sendMessage('Second conversation prompt');
      final secondId = controller.state.conversation!.id;

      expect(secondId, isNot(firstId));

      final first = await repository.getConversation(firstId);
      final second = await repository.getConversation(secondId);

      expect(
        first!.messages.any(
          (message) => message.content == 'First conversation prompt',
        ),
        isTrue,
      );
      expect(
        first.messages.any(
          (message) => message.content == 'Second conversation prompt',
        ),
        isFalse,
      );
      expect(
        second!.messages.any(
          (message) => message.content == 'Second conversation prompt',
        ),
        isTrue,
      );
      expect(
        second.messages.any(
          (message) => message.content == 'First conversation prompt',
        ),
        isFalse,
      );
    });

    test('reopens the most recently updated conversation', () async {
      final repository = _MemoryConversationRepository();
      final controller = _createController(repository);
      addTearDown(controller.dispose);

      await controller.createNewConversation();
      await controller.sendMessage('Older conversation');

      await controller.createNewConversation();
      await controller.sendMessage('Most recent conversation');
      final mostRecentId = controller.state.conversation!.id;

      final restoredController = _createController(repository);
      addTearDown(restoredController.dispose);

      await restoredController.loadMostRecentConversation();

      expect(restoredController.state.conversation!.id, mostRecentId);
      expect(
        restoredController.state.messages.first.content,
        'Most recent conversation',
      );
    });

    test('preserves the first-prompt title after follow-up prompts', () async {
      final repository = _MemoryConversationRepository();
      final controller = _createController(repository);
      addTearDown(controller.dispose);

      await controller.createNewConversation();
      await controller.sendMessage(
        'Build a launch plan for a neighborhood coffee shop',
      );
      final originalTitle = controller.state.conversation!.title;

      await controller.sendMessage('Now add a two-week content calendar');

      expect(
        originalTitle,
        Conversation.generateTitleFromPrompt(
          'Build a launch plan for a neighborhood coffee shop',
        ),
      );
      expect(controller.state.conversation!.title, originalTitle);
    });

    test(
      'routes an image action with a subject away from text completion',
      () async {
        final repository = _MemoryConversationRepository();
        final aiChatService = _FakeAIChatService();
        final controller = _createController(
          repository,
          aiChatService: aiChatService,
        );
        addTearDown(controller.dispose);

        await controller.sendMessage(
          'Create a peaceful sunset over a mountain lake.',
        );

        expect(aiChatService.requests, isEmpty);
        expect(controller.state.imageActionRequest, isNotNull);
        expect(
          controller.state.imageActionRequest!.subject,
          'peaceful sunset over a mountain lake',
        );
        expect(controller.state.messages, hasLength(1));
        expect(controller.state.messages.single.content, contains('sunset'));
      },
    );

    test(
      'asks one concise question for an image action without a subject',
      () async {
        final repository = _MemoryConversationRepository();
        final aiChatService = _FakeAIChatService();
        final controller = _createController(
          repository,
          aiChatService: aiChatService,
        );
        addTearDown(controller.dispose);

        await controller.sendMessage('Create a picture');

        expect(aiChatService.requests, isEmpty);
        expect(controller.state.imageActionRequest, isNull);
        expect(
          controller.state.messages.map((message) => message.content),
          <String>['Create a picture', 'What should the image be of?'],
        );
      },
    );

    test('persists exactly one generated image-result message', () async {
      final repository = _MemoryConversationRepository();
      final controller = _createController(repository);
      addTearDown(controller.dispose);

      await controller.sendMessage('Create a picture of Buddha');
      final conversationId = controller.state.conversation!.id;
      final sourceMessageId = controller.state.messages.single.id;
      const attachment = ChatAttachment(
        id: 'image-result',
        mimeType: 'image/png',
        localFilePath: '/safe/local/image.png',
      );

      expect(
        await controller.persistGeneratedImageResult(
          conversationId: conversationId,
          sourceMessageId: sourceMessageId,
          attachment: attachment,
        ),
        isTrue,
      );
      expect(
        await controller.persistGeneratedImageResult(
          conversationId: conversationId,
          sourceMessageId: sourceMessageId,
          attachment: attachment,
        ),
        isTrue,
      );

      final persisted = await repository.getConversation(conversationId);
      expect(
        persisted!.messages.where((message) => message.attachment != null),
        hasLength(1),
      );
      expect(persisted.messages.last.content, 'Done');
      expect(
        persisted.messages.last.attachment?.localFilePath,
        contains('image.png'),
      );
    });

    test('persists exactly one local video artifact attachment', () async {
      final repository = _MemoryConversationRepository();
      final controller = _createController(repository);
      addTearDown(controller.dispose);
      await controller.createNewConversation();
      final conversationId = controller.state.conversation!.id;
      final createdAt = DateTime(2026, 8, 26);
      final artifact = Artifact(
        id: 'video-artifact',
        conversationId: conversationId,
        type: ArtifactType.video,
        createdAt: createdAt,
      );
      final attachment = ChatAttachment(
        id: 'video-attachment',
        mimeType: 'video/mp4',
        localFilePath: '/safe/ovexiq-media/video.mp4',
        artifact: artifact,
        artifactVersion: ArtifactVersion(
          id: 'video-version',
          artifactId: artifact.id,
          mimeType: 'video/mp4',
          localPath: '/safe/ovexiq-media/video.mp4',
          fileName: 'video.mp4',
          byteSize: 1024,
          createdAt: createdAt,
        ),
      );

      expect(
        await controller.persistVideoAttachment(
          conversationId: conversationId,
          attachment: attachment,
        ),
        isTrue,
      );
      expect(
        await controller.persistVideoAttachment(
          conversationId: conversationId,
          attachment: attachment,
        ),
        isTrue,
      );

      final persisted = await repository.getConversation(conversationId);
      final videoMessages = persisted!.messages
          .where(
            (message) =>
                message.attachment?.artifact?.type == ArtifactType.video,
          )
          .toList(growable: false);
      expect(videoMessages, hasLength(1));
      expect(videoMessages.single.role, ChatRole.user);
      expect(videoMessages.single.content, 'Video added');
      expect(
        videoMessages.single.attachment?.artifactVersion?.id,
        'video-version',
      );
    });

    test(
      'refines a persisted image with one new prompt-based version',
      () async {
        final repository = _MemoryConversationRepository();
        final aiChatService = _FakeAIChatService();
        final controller = _createController(
          repository,
          aiChatService: aiChatService,
        );
        addTearDown(controller.dispose);

        await controller.sendMessage(
          'Create a peaceful sunset over a mountain lake.',
        );
        final conversationId = controller.state.conversation!.id;
        final originalSourceMessageId = controller.state.messages.single.id;
        final originalAttachment = ChatAttachment(
          id: 'original-image',
          mimeType: 'image/png',
          localFilePath: '/safe/original.png',
          sourcePrompt: 'peaceful sunset over a mountain lake',
          sourceMessageId: originalSourceMessageId,
        );
        expect(
          await controller.persistGeneratedImageResult(
            conversationId: conversationId,
            sourceMessageId: originalSourceMessageId,
            attachment: originalAttachment,
          ),
          isTrue,
        );
        final originalResultMessageId = controller.state.messages.last.id;

        expect(
          await controller.beginImageRevision(
            resultMessageId: originalResultMessageId,
          ),
          isTrue,
        );
        expect(aiChatService.requests, isEmpty);
        expect(
          controller.state.messages.last.content,
          'What would you like to change?',
        );
        expect(
          controller.state.pendingImageRevision?.sourcePrompt,
          'peaceful sunset over a mountain lake',
        );

        await controller.sendMessage(
          'Make the sky more purple and add two birds.',
        );

        expect(aiChatService.requests, isEmpty);
        expect(controller.state.pendingImageRevision, isNull);
        expect(controller.state.imageActionRequest, isNotNull);
        final refinedPrompt = controller.state.imageActionRequest!.subject;
        expect(refinedPrompt, contains('peaceful sunset over a mountain lake'));
        expect(
          refinedPrompt,
          contains('Make the sky more purple and add two birds.'),
        );

        final refinedSourceMessageId = controller.state.messages.last.id;
        final refinedAttachment = ChatAttachment(
          id: 'refined-image',
          mimeType: 'image/png',
          localFilePath: '/safe/refined.png',
          sourcePrompt: refinedPrompt,
          sourceMessageId: refinedSourceMessageId,
        );
        expect(
          await controller.persistGeneratedImageResult(
            conversationId: conversationId,
            sourceMessageId: refinedSourceMessageId,
            attachment: refinedAttachment,
          ),
          isTrue,
        );

        final restoredController = _createController(repository);
        addTearDown(restoredController.dispose);
        await restoredController.loadConversation(conversationId);
        final restoredAttachments = restoredController.state.messages
            .where((message) => message.attachment != null)
            .map((message) => message.attachment!)
            .toList(growable: false);

        expect(restoredAttachments, hasLength(2));
        expect(restoredAttachments.first.localFilePath, '/safe/original.png');
        expect(restoredAttachments.last.localFilePath, '/safe/refined.png');
        final refinedResultMessage = restoredController.state.messages
            .lastWhere((message) => message.attachment?.id == 'refined-image');
        expect(
          await restoredController.beginImageRevision(
            resultMessageId: refinedResultMessage.id,
          ),
          isTrue,
        );
        expect(
          restoredController.state.pendingImageRevision?.sourcePrompt,
          refinedPrompt,
        );
      },
    );

    test(
      'refine and regenerate retain one logical artifact identity',
      () async {
        final repository = _MemoryConversationRepository();
        final controller = _createController(repository);
        addTearDown(controller.dispose);

        await controller.sendMessage('Create a picture of Buddha');
        final conversationId = controller.state.conversation!.id;
        final sourceMessageId = controller.state.messages.single.id;
        final artifact = Artifact(
          id: 'artifact-image-1',
          conversationId: conversationId,
          type: ArtifactType.image,
          createdAt: DateTime(2026, 8, 26),
        );
        final originalAttachment = ChatAttachment(
          id: 'original-image',
          mimeType: 'image/png',
          localFilePath: '/safe/original.png',
          sourcePrompt: 'Buddha',
          sourceMessageId: sourceMessageId,
          artifact: artifact,
          artifactVersion: ArtifactVersion(
            id: 'artifact-version-1',
            artifactId: artifact.id,
            mimeType: 'image/png',
            localPath: '/safe/original.png',
            createdAt: artifact.createdAt,
          ),
        );
        await controller.persistGeneratedImageResult(
          conversationId: conversationId,
          sourceMessageId: sourceMessageId,
          attachment: originalAttachment,
        );

        expect(
          await controller.beginImageRevision(
            resultMessageId: controller.state.messages.last.id,
          ),
          isTrue,
        );
        await controller.sendMessage('Make the sky purple');
        final refineRequest = controller.state.imageActionRequest!;
        expect(refineRequest.artifactId, artifact.id);
        expect(refineRequest.artifactCreatedAt, artifact.createdAt);
        expect(refineRequest.sourceArtifactVersionId, 'artifact-version-1');

        controller.cancelImageGeneration(requestId: refineRequest.requestId!);
        expect(
          await controller.regenerateImage(
            resultMessageId: controller.state.messages
                .firstWhere(
                  (message) => message.attachment?.id == 'original-image',
                )
                .id,
          ),
          isTrue,
        );
        final regenerateRequest = controller.state.imageActionRequest!;
        expect(regenerateRequest.artifactId, artifact.id);
        expect(regenerateRequest.sourceArtifactVersionId, 'artifact-version-1');
      },
    );

    test('an unrelated request cancels a pending image revision', () async {
      final repository = _MemoryConversationRepository();
      final aiChatService = _FakeAIChatService();
      final controller = _createController(
        repository,
        aiChatService: aiChatService,
      );
      addTearDown(controller.dispose);

      await controller.sendMessage('Create a picture of Buddha');
      final conversationId = controller.state.conversation!.id;
      final sourceMessageId = controller.state.messages.single.id;
      await controller.persistGeneratedImageResult(
        conversationId: conversationId,
        sourceMessageId: sourceMessageId,
        attachment: ChatAttachment(
          id: 'buddha-image',
          mimeType: 'image/png',
          localFilePath: '/safe/buddha.png',
          sourcePrompt: 'Buddha',
          sourceMessageId: sourceMessageId,
        ),
      );
      await controller.beginImageRevision(
        resultMessageId: controller.state.messages.last.id,
      );

      await controller.sendMessage(
        'Write a Facebook post about our summer sale',
      );

      expect(controller.state.pendingImageRevision, isNull);
      expect(controller.state.imageActionRequest, isNull);
      expect(aiChatService.requests, hasLength(1));
    });

    test('regenerates a persisted image as one separate version', () async {
      final repository = _MemoryConversationRepository();
      final aiChatService = _FakeAIChatService();
      final controller = _createController(
        repository,
        aiChatService: aiChatService,
      );
      addTearDown(controller.dispose);

      await controller.sendMessage('Create a picture of Buddha');
      final conversationId = controller.state.conversation!.id;
      final sourceMessageId = controller.state.messages.single.id;
      final originalAttachment = ChatAttachment(
        id: 'original-image',
        mimeType: 'image/png',
        localFilePath: '/safe/original.png',
        sourcePrompt: 'Buddha',
        sourceMessageId: sourceMessageId,
      );
      await controller.persistGeneratedImageResult(
        conversationId: conversationId,
        sourceMessageId: sourceMessageId,
        attachment: originalAttachment,
      );
      final originalResultMessageId = controller.state.messages.last.id;
      final messageCountBeforeRegenerate = controller.state.messages.length;

      expect(
        await controller.regenerateImage(
          resultMessageId: originalResultMessageId,
        ),
        isTrue,
      );
      expect(aiChatService.requests, isEmpty);
      expect(
        controller.state.messages,
        hasLength(messageCountBeforeRegenerate),
      );
      expect(controller.state.imageActionRequest?.subject, 'Buddha');
      final regenerationRequest = controller.state.imageActionRequest!;
      expect(regenerationRequest.requestId, startsWith('regenerate-'));
      expect(regenerationRequest.sourceMessageId, sourceMessageId);
      expect(
        await controller.regenerateImage(
          resultMessageId: originalResultMessageId,
        ),
        isFalse,
      );

      final regeneratedAttachment = ChatAttachment(
        id: 'image-$conversationId-${regenerationRequest.requestId}',
        mimeType: 'image/png',
        localFilePath: '/safe/regenerated.png',
        sourcePrompt: regenerationRequest.subject,
        sourceMessageId: regenerationRequest.sourceMessageId,
      );
      expect(
        await controller.persistGeneratedImageResult(
          conversationId: conversationId,
          sourceMessageId: regenerationRequest.sourceMessageId!,
          attachment: regeneratedAttachment,
        ),
        isTrue,
      );

      final restoredController = _createController(repository);
      addTearDown(restoredController.dispose);
      await restoredController.loadConversation(conversationId);
      final restoredAttachments = restoredController.state.messages
          .where((message) => message.attachment != null)
          .map((message) => message.attachment!)
          .toList(growable: false);
      expect(restoredAttachments, hasLength(2));
      expect(restoredAttachments.first.localFilePath, '/safe/original.png');
      expect(restoredAttachments.last.localFilePath, '/safe/regenerated.png');

      final regeneratedResultMessage = restoredController.state.messages
          .lastWhere(
            (message) => message.attachment?.id == regeneratedAttachment.id,
          );
      expect(
        await restoredController.regenerateImage(
          resultMessageId: regeneratedResultMessage.id,
        ),
        isTrue,
      );
      expect(restoredController.state.imageActionRequest?.subject, 'Buddha');
    });

    test(
      'does not regenerate when a historical source prompt is unavailable',
      () async {
        final repository = _MemoryConversationRepository();
        final now = DateTime(2026, 8, 25);
        final conversation = Conversation(
          id: 'missing-image-source',
          title: 'Missing source',
          messages: <ChatMessage>[
            ChatMessage(
              id: 'result-message',
              role: ChatRole.assistant,
              content: 'Done',
              createdAt: now,
              attachment: const ChatAttachment(
                id: 'missing-source-image',
                mimeType: 'image/png',
                localFilePath: '/safe/missing-source.png',
              ),
            ),
          ],
          createdAt: now,
          updatedAt: now,
        );
        await repository.saveConversation(conversation);
        final controller = _createController(repository);
        addTearDown(controller.dispose);
        await controller.loadConversation(conversation.id);

        expect(
          await controller.regenerateImage(resultMessageId: 'result-message'),
          isFalse,
        );
        expect(controller.state.imageActionRequest, isNull);
      },
    );

    test(
      'cancelling regeneration preserves the existing image result',
      () async {
        final repository = _MemoryConversationRepository();
        final controller = _createController(repository);
        addTearDown(controller.dispose);

        await controller.sendMessage('Create a picture of Buddha');
        final conversationId = controller.state.conversation!.id;
        final sourceMessageId = controller.state.messages.single.id;
        await controller.persistGeneratedImageResult(
          conversationId: conversationId,
          sourceMessageId: sourceMessageId,
          attachment: ChatAttachment(
            id: 'original-image',
            mimeType: 'image/png',
            localFilePath: '/safe/original.png',
            sourcePrompt: 'Buddha',
            sourceMessageId: sourceMessageId,
          ),
        );
        final originalMessages = List<ChatMessage>.of(
          controller.state.messages,
        );

        expect(
          await controller.regenerateImage(
            resultMessageId: controller.state.messages.last.id,
          ),
          isTrue,
        );
        final requestId = controller.state.activeImageRequestId!;

        controller.cancelImageGeneration(requestId: requestId);
        controller.cancelImageGeneration(requestId: requestId);

        expect(controller.state.isImageGenerationInProgress, isFalse);
        expect(controller.state.activeImageRequestId, isNull);
        expect(controller.state.imageActionRequest, isNull);
        expect(controller.state.messages, originalMessages);
        expect(controller.state.messages.last.attachment?.id, 'original-image');
      },
    );

    test(
      'asks exactly once for a Facebook post topic before completion',
      () async {
        final repository = _MemoryConversationRepository();
        final aiChatService = _FakeAIChatService();
        final controller = _createController(
          repository,
          aiChatService: aiChatService,
        );
        addTearDown(controller.dispose);

        await controller.sendMessage('Write a Facebook post');

        expect(aiChatService.requests, isEmpty);
        expect(
          controller.state.messages.last.content,
          'What should the Facebook post be about?',
        );
        expect(controller.state.pendingClarification?.requiredField, 'topic');

        await controller.sendMessage('Our summer sale');

        expect(aiChatService.requests, hasLength(1));
        expect(controller.state.pendingClarification, isNull);
        expect(
          aiChatService.requests.single
              .map((message) => message.content)
              .toList(),
          <String>[
            'Write a Facebook post',
            'What should the Facebook post be about?',
            'Our summer sale',
          ],
        );
        expect(
          (await repository.getConversation(
            controller.state.conversation!.id,
          ))?.messages.map((message) => message.content),
          contains('Our summer sale'),
        );
      },
    );

    test(
      'completes a Facebook post request when it already has a topic',
      () async {
        final repository = _MemoryConversationRepository();
        final aiChatService = _FakeAIChatService();
        final controller = _createController(
          repository,
          aiChatService: aiChatService,
        );
        addTearDown(controller.dispose);

        await controller.sendMessage(
          'Write a Facebook post about our summer sale',
        );

        expect(aiChatService.requests, hasLength(1));
        expect(controller.state.pendingClarification, isNull);
      },
    );

    test('asks one TikTok topic question only when a topic is missing', () async {
      final repository = _MemoryConversationRepository();
      final aiChatService = _FakeAIChatService();
      final controller = _createController(
        repository,
        aiChatService: aiChatService,
      );
      addTearDown(controller.dispose);

      await controller.sendMessage(
        'Help me make TikTok videos to get more views and earn money',
      );

      expect(aiChatService.requests, isEmpty);
      expect(
        controller.state.messages.last.content,
        'Do you already have a content topic, or should Ovexiq choose one for you?',
      );

      await controller.sendMessage('Easy home cooking');

      expect(aiChatService.requests, isEmpty);
      expect(controller.state.pendingClarification, isNull);
      expect(
        controller.state.messages.last.content,
        'This feature isn’t available in the current Ovexiq beta yet.\n\n'
        'Reel and video creation features are coming soon.\n\n'
        'For now, Ovexiq can help with the script, caption, shot list, and '
        'content plan.',
      );
      expect(controller.state.missionSuggestion, isNull);
    });

    test(
      'returns neutral information instead of executing TikTok video creation',
      () async {
        final repository = _MemoryConversationRepository();
        final aiChatService = _FakeAIChatService();
        final controller = _createController(
          repository,
          aiChatService: aiChatService,
        );
        addTearDown(controller.dispose);

        await controller.sendMessage(
          'Make TikTok videos about easy home cooking',
        );

        expect(aiChatService.requests, isEmpty);
        expect(controller.state.pendingClarification, isNull);
        expect(
          controller.state.messages.last.content,
          'This feature isn’t available in the current Ovexiq beta yet.\n\n'
          'Reel and video creation features are coming soon.\n\n'
          'For now, Ovexiq can help with the script, caption, shot list, and '
          'content plan.',
        );
      },
    );

    test(
      'stores unsupported video execution as neutral information without AI work',
      () async {
        final repository = _MemoryConversationRepository();
        final aiChatService = _FakeAIChatService();
        final controller = _createController(
          repository,
          aiChatService: aiChatService,
        );
        addTearDown(controller.dispose);

        await controller.sendMessage('Edit these 5 videos into one video');

        expect(aiChatService.requests, isEmpty);
        expect(controller.state.missionSuggestion, isNull);
        expect(controller.state.error, isNull);
        expect(controller.state.isSending, isFalse);
        expect(
          controller.state.messages.map((message) => message.content),
          <String>[
            'Edit these 5 videos into one video',
            'This feature isn’t available in the current Ovexiq beta yet.\n\n'
                'Reel and video creation features are coming soon.\n\n'
                'For now, Ovexiq can help with the script, caption, shot list, '
                'and content plan.',
          ],
        );
        expect(controller.state.messages.last.isError, isFalse);
      },
    );

    test('stores Burmese unsupported execution as neutral information', () async {
      final repository = _MemoryConversationRepository();
      final aiChatService = _FakeAIChatService();
      final controller = _createController(
        repository,
        aiChatService: aiChatService,
      );
      addTearDown(controller.dispose);

      await controller.sendMessage('ဒီ Reel ကို video အဖြစ်ဖန်တီးပေးပါ။');

      expect(aiChatService.requests, isEmpty);
      expect(controller.state.messages.last.isError, isFalse);
      expect(
        controller.state.messages.last.content,
        'ဒီ feature ကို လက်ရှိ Ovexiq beta မှာ မရသေးပါ။\n\n'
        'Reel / video creation features တွေ မကြာခင် ထည့်သွင်းသွားမယ်။\n\n'
        'အခုတော့ script, caption, shot list နဲ့ content plan ကို ပြင်ဆင်ပေးနိုင်ပါတယ်။',
      );
    });

    test(
      'keeps a direct Burmese Reel request local without provider work',
      () async {
        final repository = _MemoryConversationRepository();
        final aiChatService = _FakeAIChatService();
        final controller = _createController(
          repository,
          aiChatService: aiChatService,
        );
        addTearDown(controller.dispose);

        await controller.sendMessage('Facebook အတွက် reel ထုတ်ပေးပါ');

        expect(aiChatService.requests, isEmpty);
        expect(controller.state.missionSuggestion, isNull);
        expect(controller.state.error, isNull);
        expect(controller.state.messages.last.isError, isFalse);
        expect(
          controller.state.messages.last.content,
          contains('ဒီ feature ကို လက်ရှိ Ovexiq beta မှာ မရသေးပါ။'),
        );
      },
    );

    test('keeps Burmese Reel planning on the normal AI path', () async {
      final repository = _MemoryConversationRepository();
      final aiChatService = _FakeAIChatService();
      final controller = _createController(
        repository,
        aiChatService: aiChatService,
      );
      addTearDown(controller.dispose);

      await controller.sendMessage('reel idea ပေးပါ');

      expect(aiChatService.requests, hasLength(1));
      expect(controller.state.messages.last.isError, isFalse);
    });

    test('keeps ordinary text chat on the existing completion path', () async {
      final repository = _MemoryConversationRepository();
      final aiChatService = _FakeAIChatService();
      final controller = _createController(
        repository,
        aiChatService: aiChatService,
      );
      addTearDown(controller.dispose);

      await controller.sendMessage('What is the capital of Thailand?');

      expect(aiChatService.requests, hasLength(1));
      expect(
        controller.state.messages.last.content,
        'Response to: What is the capital of Thailand?',
      );
    });

    test(
      'sends ordered context without duplicating the newest user message',
      () async {
        final repository = _MemoryConversationRepository();
        final aiChatService = _FakeAIChatService();
        final controller = _createController(
          repository,
          aiChatService: aiChatService,
        );
        addTearDown(controller.dispose);

        await controller.createNewConversation();
        await controller.sendMessage('Research Kaspa smart contracts');
        await controller.sendMessage('Summarize it in 3 bullets');

        expect(aiChatService.requests, hasLength(2));
        expect(
          aiChatService.requests.first
              .map((message) => (message.role, message.content))
              .toList(),
          <(AIMessageRole, String)>[
            (AIMessageRole.user, 'Research Kaspa smart contracts'),
          ],
        );
        expect(
          aiChatService.requests.last
              .map((message) => (message.role, message.content))
              .toList(),
          <(AIMessageRole, String)>[
            (AIMessageRole.user, 'Research Kaspa smart contracts'),
            (
              AIMessageRole.assistant,
              'Response to: Research Kaspa smart contracts',
            ),
            (AIMessageRole.user, 'Summarize it in 3 bullets'),
          ],
        );
        expect(
          aiChatService.requests.last.where(
            (message) => message.content == 'Summarize it in 3 bullets',
          ),
          hasLength(1),
        );
      },
    );

    test('uses restored history for a follow-up message', () async {
      final repository = _MemoryConversationRepository();
      final firstController = _createController(repository);
      addTearDown(firstController.dispose);

      await firstController.createNewConversation();
      await firstController.sendMessage('Research Kaspa smart contracts');

      final restoredAIChatService = _FakeAIChatService();
      final restoredController = _createController(
        repository,
        aiChatService: restoredAIChatService,
      );
      addTearDown(restoredController.dispose);

      await restoredController.loadMostRecentConversation();
      await restoredController.sendMessage('Summarize it in 3 bullets');

      expect(restoredAIChatService.requests.single, hasLength(3));
      expect(
        restoredAIChatService.requests.single
            .map((message) => message.role)
            .toList(),
        <AIMessageRole>[
          AIMessageRole.user,
          AIMessageRole.assistant,
          AIMessageRole.user,
        ],
      );
      expect(
        restoredAIChatService.requests.single.last.content,
        'Summarize it in 3 bullets',
      );
    });

    test(
      'retries the latest response with ordered context and no duplicate prompt',
      () async {
        final repository = _MemoryConversationRepository();
        final aiChatService = _FakeAIChatService(
          failingRequestNumbers: <int>{2},
        );
        final controller = _createController(
          repository,
          aiChatService: aiChatService,
        );
        addTearDown(controller.dispose);

        await controller.createNewConversation();
        await controller.sendMessage('Research Kaspa smart contracts');
        await controller.sendMessage('Summarize it in 3 bullets');

        expect(controller.state.error, isNotNull);
        expect(controller.state.error!.canRetryLastResponse, isTrue);
        expect(
          controller.state.messages.last.content,
          "Ovexiq couldn't finish that request. Please try again.",
        );
        expect(controller.state.messages.last.isError, isTrue);

        await controller.regenerateLastResponse();

        expect(aiChatService.requests, hasLength(3));
        expect(
          aiChatService.requests.last
              .map((message) => (message.role, message.content))
              .toList(),
          <(AIMessageRole, String)>[
            (AIMessageRole.user, 'Research Kaspa smart contracts'),
            (
              AIMessageRole.assistant,
              'Response to: Research Kaspa smart contracts',
            ),
            (AIMessageRole.user, 'Summarize it in 3 bullets'),
          ],
        );
        expect(
          aiChatService.requests.last.where(
            (message) => message.content == 'Summarize it in 3 bullets',
          ),
          hasLength(1),
        );
        expect(controller.state.error, isNull);
        expect(
          controller.state.messages.map((message) => message.content),
          isNot(contains('Partial response')),
        );

        final persisted = await repository.getConversation(
          controller.state.conversation!.id,
        );
        expect(
          persisted!.messages
              .where(
                (message) => message.content == 'Summarize it in 3 bullets',
              )
              .length,
          1,
        );
        expect(
          persisted.messages.last.content,
          'Response to: Summarize it in 3 bullets',
        );
      },
    );

    test(
      'rate limits use a localized cooldown instead of immediate retry',
      () async {
        final repository = _MemoryConversationRepository();
        final aiChatService = _FakeAIChatService(
          failingRequestNumbers: <int>{1},
          failure: const AIRequestFailure(
            category: AIRequestFailureCategory.rateLimited,
            retryable: true,
            executionStage: 'gateway_response',
            diagnosticReason: 'http_429',
            statusCode: 429,
            retryAfter: Duration(seconds: 60),
          ),
        );
        final controller = _createController(
          repository,
          aiChatService: aiChatService,
        );
        addTearDown(controller.dispose);

        await controller.sendMessage('Facebook အတွက် post တစ်ခုရေးပေးပါ။');

        expect(controller.state.error!.canRetryLastResponse, isFalse);
        expect(
          controller.state.messages.last.content,
          'ခဏလောက်စောင့်ပြီး ပြန်စမ်းပေးပါ။',
        );

        await controller.regenerateLastResponse();
        expect(aiChatService.requests, hasLength(1));
      },
    );

    test('validation errors are not response-retryable', () async {
      final repository = _MemoryConversationRepository();
      final controller = _createController(repository);
      addTearDown(controller.dispose);

      await controller.createNewConversation();
      await controller.loadConversation('');

      expect(controller.state.error, isNotNull);
      expect(controller.state.error!.canRetryLastResponse, isFalse);
    });

    test('non-retryable typed request failures keep the error safe', () async {
      final repository = _MemoryConversationRepository();
      final aiChatService = _FakeAIChatService(
        failingRequestNumbers: <int>{1},
        failure: const AIRequestFailure(
          category: AIRequestFailureCategory.authentication,
          retryable: false,
          executionStage: 'gateway_response',
          diagnosticReason: 'http_403',
          statusCode: 403,
        ),
      );
      final controller = _createController(
        repository,
        aiChatService: aiChatService,
      );
      addTearDown(controller.dispose);

      await controller.sendMessage('A private prompt must not be logged.');

      expect(controller.state.error, isNotNull);
      expect(controller.state.error!.canRetryLastResponse, isFalse);
      expect(
        controller.state.error!.toString(),
        'This Ovexiq beta access is not authorized.',
      );
      expect(
        controller.state.messages.last.content,
        "Ovexiq couldn't finish that request. Please try again.",
      );
    });

    test('cancellation ignores a late success and a later request works', () async {
      final repository = _MemoryConversationRepository();
      final aiChatService = _ControlledAIChatService();
      final controller = _createController(
        repository,
        aiChatService: aiChatService,
      );
      addTearDown(controller.dispose);

      final firstRequest = controller.sendMessage('What is a good writing habit?');
      await aiChatService.firstRequestStarted.future;

      await controller.cancelActiveResponse();
      aiChatService.completeFirstWithText('Late answer must be ignored.');
      await firstRequest;

      expect(controller.state.isSending, isFalse);
      expect(controller.state.error, isNull);
      expect(controller.state.messages.where((message) => message.isError),
          isEmpty);
      expect(
        controller.state.messages.map((message) => message.content),
        <String>['What is a good writing habit?'],
      );

      await controller.sendMessage('What is a useful next step?');

      expect(aiChatService.requests, hasLength(2));
      expect(controller.state.error, isNull);
      expect(controller.state.messages.last.content, 'Fresh response');
    });

    test(
      'explicit cancellation resume uses the original request and ignores a late failure',
      () async {
        final repository = _MemoryConversationRepository();
        final aiChatService = _CancelledResumeAIChatService();
        final controller = _createController(
          repository,
          aiChatService: aiChatService,
        );
        addTearDown(controller.dispose);

        final firstRequest = controller.sendMessage(
          'What is a good writing habit?',
        );
        await aiChatService.firstRequestStarted.future;
        await controller.cancelActiveResponse();

        final resumedRequest = controller.resumeCancelledResponse();
        await aiChatService.retryRequestStarted.future;
        aiChatService.failCancelledRequestLate();
        aiChatService.succeedRetry();
        await firstRequest;
        expect(await resumedRequest, isTrue);

        expect(aiChatService.requests, hasLength(2));
        expect(
          aiChatService.requests.last.map((message) => message.content),
          orderedEquals(<String>['What is a good writing habit?']),
        );
        expect(controller.state.error, isNull);
        expect(controller.state.isSending, isFalse);
        expect(
          controller.state.messages.map((message) => message.content),
          <String>['What is a good writing habit?', 'Fresh resumed response'],
        );
        expect(
          (await repository.getConversation(controller.state.conversation!.id))!
              .messages
              .where((message) => message.isError),
          isEmpty,
        );
      },
    );

    test('cancellation wins when a late provider failure is persisting', () async {
      final repository = _DelayedErrorConversationRepository();
      final aiChatService = _ControlledAIChatService();
      final controller = _createController(
        repository,
        aiChatService: aiChatService,
      );
      addTearDown(controller.dispose);

      final request = controller.sendMessage('Explain a practical writing tip.');
      await aiChatService.firstRequestStarted.future;
      repository.holdNextErrorSave();

      aiChatService.failFirst(StateError('late provider failure'));
      await repository.errorSaveStarted.future;
      await controller.cancelActiveResponse();
      repository.releaseErrorSave();
      await request;

      expect(controller.state.error, isNull);
      expect(controller.state.messages.where((message) => message.isError),
          isEmpty);
      expect(
        (await repository.getConversation(controller.state.conversation!.id))!
            .messages
            .where((message) => message.isError),
        isEmpty,
      );
    });

    test('cancellation ignores a late timeout', () async {
      final repository = _MemoryConversationRepository();
      final aiChatService = _ControlledAIChatService();
      final controller = _createController(
        repository,
        aiChatService: aiChatService,
      );
      addTearDown(controller.dispose);

      final request = controller.sendMessage('Share one helpful writing idea.');
      await aiChatService.firstRequestStarted.future;

      await controller.cancelActiveResponse();
      aiChatService.failFirst(TimeoutException('late timeout'));
      await request;

      expect(controller.state.isSending, isFalse);
      expect(controller.state.error, isNull);
      expect(controller.state.messages.where((message) => message.isError),
          isEmpty);
    });
  });
}

ChatController _createController(
  _MemoryConversationRepository repository, {
  AIChatService? aiChatService,
}) {
  return ChatController(
    aiChatService: aiChatService ?? _FakeAIChatService(),
    conversationRepository: repository,
  );
}

class _FakeAIChatService extends AIChatService {
  _FakeAIChatService({
    Set<int> failingRequestNumbers = const <int>{},
    this.failure,
  }) : _failingRequestNumbers = <int>{...failingRequestNumbers};

  final List<List<AIMessage>> requests = <List<AIMessage>>[];
  final Set<int> _failingRequestNumbers;
  final AIRequestFailure? failure;

  @override
  Stream<AIChunk> sendMessages(List<AIMessage> messages) async* {
    requests.add(List<AIMessage>.of(messages));
    final prompt = messages.last.content;

    yield const AIChunk.status(
      provider: ProviderType.openAI,
      text: 'Generating',
    );

    if (_failingRequestNumbers.remove(requests.length)) {
      yield const AIChunk.text(
        provider: ProviderType.openAI,
        text: 'Partial response',
      );
      yield AIChunk.error(
        provider: ProviderType.openAI,
        error: 'Temporary failure',
        failure: failure,
      );
      return;
    }

    yield AIChunk.text(
      provider: ProviderType.openAI,
      text: 'Response to: $prompt',
    );
    yield const AIChunk.done(provider: ProviderType.openAI);
  }
}

class _MemoryConversationRepository extends ConversationRepository {
  final Map<String, Conversation> _items = <String, Conversation>{};

  List<Conversation> get conversations => _items.values.toList(growable: false);

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

class _DelayedErrorConversationRepository extends _MemoryConversationRepository {
  final errorSaveStarted = Completer<void>();
  final _releaseErrorSave = Completer<void>();
  var _holdErrorSave = false;

  void holdNextErrorSave() {
    _holdErrorSave = true;
  }

  void releaseErrorSave() {
    if (!_releaseErrorSave.isCompleted) {
      _releaseErrorSave.complete();
    }
  }

  @override
  Future<void> saveConversation(Conversation conversation) async {
    if (_holdErrorSave && conversation.messages.lastOrNull?.isError == true) {
      _holdErrorSave = false;
      if (!errorSaveStarted.isCompleted) {
        errorSaveStarted.complete();
      }
      await _releaseErrorSave.future;
    }
    await super.saveConversation(conversation);
  }
}

class _ControlledAIChatService extends AIChatService {
  final List<List<AIMessage>> requests = <List<AIMessage>>[];
  final firstRequestStarted = Completer<void>();
  StreamController<AIChunk>? _firstResponse;

  @override
  Stream<AIChunk> sendMessages(List<AIMessage> messages) {
    requests.add(List<AIMessage>.of(messages));
    if (requests.length > 1) {
      return Stream<AIChunk>.fromIterable(const <AIChunk>[
        AIChunk.text(provider: ProviderType.openAI, text: 'Fresh response'),
        AIChunk.done(provider: ProviderType.openAI),
      ]);
    }

    final response = StreamController<AIChunk>();
    _firstResponse = response;
    firstRequestStarted.complete();
    return response.stream;
  }

  void completeFirstWithText(String text) {
    _firstResponse!
      ..add(AIChunk.text(provider: ProviderType.openAI, text: text))
      ..add(const AIChunk.done(provider: ProviderType.openAI))
      ..close();
  }

  void failFirst(Object error) {
    _firstResponse!
      ..addError(error)
      ..close();
  }
}

class _CancelledResumeAIChatService extends AIChatService {
  final List<List<AIMessage>> requests = <List<AIMessage>>[];
  final firstRequestStarted = Completer<void>();
  final retryRequestStarted = Completer<void>();
  final List<StreamController<AIChunk>> _responses =
      <StreamController<AIChunk>>[];

  @override
  Stream<AIChunk> sendMessages(List<AIMessage> messages) {
    requests.add(List<AIMessage>.of(messages));
    final response = StreamController<AIChunk>();
    _responses.add(response);
    if (requests.length == 1) {
      firstRequestStarted.complete();
    } else {
      retryRequestStarted.complete();
    }
    return response.stream;
  }

  void failCancelledRequestLate() {
    _responses.first
      ..addError(StateError('late cancelled provider error'))
      ..close();
  }

  void succeedRetry() {
    _responses[1]
      ..add(
        const AIChunk.text(
          provider: ProviderType.openAI,
          text: 'Fresh resumed response',
        ),
      )
      ..add(const AIChunk.done(provider: ProviderType.openAI))
      ..close();
  }
}
