import 'dart:async';

import 'package:aiorbit/core/ai/ai.dart';
import 'package:aiorbit/core/text/response_language.dart';
import 'package:aiorbit/features/mission/models/mission_suggestion.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../beta_access/providers/beta_access_provider.dart';
import '../models/chat_message.dart';
import '../models/artifact.dart';
import '../models/conversation.dart';
import '../models/pending_chat_clarification.dart';
import '../models/pending_image_revision.dart';
import '../repositories/conversation_repository.dart';
import '../services/ai_chat_service.dart';
import '../services/chat_action_dispatcher.dart';
import '../services/chat_clarification_policy.dart';
import '../services/chat_work_intent_resolver.dart';
import '../services/mission_suggestion_service.dart';
import '../models/message_feedback.dart';

final aiChatServiceProvider = Provider<AIChatService>((ref) {
  ref.watch(betaAccessControllerProvider);
  final betaAccess = ref.read(betaAccessControllerProvider.notifier);
  return AIChatService(
    aiService: AIService(
      router: AIRouter(
        providers: AIProviderRegistry.providers(
          deviceSession: betaAccess.deviceSession,
          onAuthorizationRejected: betaAccess.invalidateSession,
        ),
      ),
    ),
  );
});

final missionSuggestionServiceProvider = Provider<MissionSuggestionService>((
  ref,
) {
  return const MissionSuggestionService();
});

final chatWorkIntentResolverProvider = Provider<ChatWorkIntentResolver>((ref) {
  return ChatWorkIntentResolver(
    missionSuggestionService: ref.watch(missionSuggestionServiceProvider),
  );
});

final conversationRepositoryProvider = Provider<ConversationRepository>((ref) {
  return ConversationRepository();
});

final chatControllerProvider = StateNotifierProvider<ChatController, ChatState>(
  (ref) {
    return ChatController(
      aiChatService: ref.watch(aiChatServiceProvider),
      conversationRepository: ref.watch(conversationRepositoryProvider),
      chatWorkIntentResolver: ref.watch(chatWorkIntentResolverProvider),
    );
  },
);

class ChatController extends StateNotifier<ChatState> {
  ChatController({
    required AIChatService aiChatService,
    required ConversationRepository conversationRepository,
    ChatActionDispatcher chatActionDispatcher = const ChatActionDispatcher(),
    ChatClarificationPolicy chatClarificationPolicy =
        const ChatClarificationPolicy(),
    ChatWorkIntentResolver chatWorkIntentResolver =
        const ChatWorkIntentResolver(),
  }) : _aiChatService = aiChatService,
       _conversationRepository = conversationRepository,
       _chatActionDispatcher = chatActionDispatcher,
       _chatClarificationPolicy = chatClarificationPolicy,
       _chatWorkIntentResolver = chatWorkIntentResolver,
       super(const ChatState());

  final AIChatService _aiChatService;
  final ConversationRepository _conversationRepository;
  final ChatActionDispatcher _chatActionDispatcher;
  final ChatClarificationPolicy _chatClarificationPolicy;
  final ChatWorkIntentResolver _chatWorkIntentResolver;

  int _operationRevision = 0;
  int _lastConversationIdMicros = 0;
  int _lastActivityMicros = 0;
  Timer? _retryCooldownTimer;

  static const Duration _fallbackRateLimitCooldown = Duration(seconds: 30);

  static final RegExp _standaloneRequestDuringImageRevision = RegExp(
    r'^\s*(?:(?:please\s+)?(?:write|draft|summarize|explain|tell|help|research|analyze)\b|(?:how|what|why|where|when|who)\b|(?:create|make)\s+(?:a\s+)?(?:facebook\s+post|marketing\s+plan|content\s+calendar|(?:tiktok\s+)?video|email|(?:blog\s+)?article|script)\b)',
    caseSensitive: false,
  );

  Future<bool> createNewConversation() async {
    final revision = ++_operationRevision;
    final now = _nextActivityTime();
    final previousState = state;

    final conversation = Conversation(
      id: _nextConversationId(now),
      title: 'New Chat',
      messages: const [],
      createdAt: now,
      updatedAt: now,
    );

    state = ChatState(conversation: conversation, isLoading: true);

    try {
      await _conversationRepository.saveConversation(conversation);

      if (!mounted || revision != _operationRevision) {
        return false;
      }

      state = ChatState(conversation: conversation);
      return true;
    } catch (error, stackTrace) {
      debugPrint('CREATE CONVERSATION ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted || revision != _operationRevision) {
        return false;
      }

      state = previousState.copyWith(
        isLoading: false,
        error: ChatControllerException(
          error.toString(),
          cause: error,
          stackTrace: stackTrace,
        ),
      );
      return false;
    }
  }

  Future<void> loadConversation(String conversationId) async {
    final normalizedId = conversationId.trim();

    if (normalizedId.isEmpty) {
      state = state.copyWith(
        error: const ChatControllerException('A conversation ID is required.'),
      );
      return;
    }

    final revision = ++_operationRevision;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final conversation = await _conversationRepository.getConversation(
        normalizedId,
      );

      if (!mounted || revision != _operationRevision) {
        return;
      }

      if (conversation == null) {
        state = ChatState(
          error: ChatControllerException(
            'Conversation "$normalizedId" was not found.',
          ),
        );
        return;
      }

      _trackActivity(conversation.updatedAt);

      state = ChatState(conversation: conversation);
    } catch (error, stackTrace) {
      if (!mounted || revision != _operationRevision) {
        return;
      }

      state = ChatState(
        error: ChatControllerException(
          'Could not load the conversation.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<void> loadMostRecentConversation() async {
    final revision = ++_operationRevision;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final conversations = await _conversationRepository.getAllConversations();

      if (!mounted || revision != _operationRevision) {
        return;
      }

      if (conversations.isEmpty) {
        state = const ChatState();
        return;
      }

      final conversation = conversations.first;

      _trackActivity(conversation.updatedAt);

      state = ChatState(conversation: conversation);
    } catch (error, stackTrace) {
      if (!mounted || revision != _operationRevision) {
        return;
      }

      state = ChatState(
        error: ChatControllerException(
          'Could not restore the latest conversation.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<void> sendMessage(String content) async {
    final text = content.trim();

    if (text.isEmpty || state.isSending || state.isImageGenerationInProgress) {
      return;
    }

    ++_operationRevision;

    var conversation = state.conversation;

    if (conversation == null) {
      final now = _nextActivityTime();

      conversation = Conversation(
        id: _nextConversationId(now),
        title: Conversation.generateTitleFromPrompt(text),
        messages: const [],
        createdAt: now,
        updatedAt: now,
      );
    }

    final conversationId = conversation.id;
    final pendingClarification = state.pendingClarification;
    final pendingImageRevision = state.pendingImageRevision;
    final now = _nextActivityTime();

    final userMessage = ChatMessage(
      id: now.microsecondsSinceEpoch.toString(),
      role: ChatRole.user,
      content: text,
      createdAt: now,
    );

    final title = conversation.messages.isEmpty
        ? Conversation.generateTitleFromPrompt(text)
        : conversation.title;

    conversation = conversation.copyWith(
      title: title,
      messages: <ChatMessage>[...conversation.messages, userMessage],
      updatedAt: now,
    );

    state = state.copyWith(
      conversation: conversation,
      isSending: true,
      clearError: true,
      clearMissionSuggestion: true,
      clearImageActionRequest: true,
    );

    try {
      await _conversationRepository.saveConversation(conversation);

      if (!mounted || state.conversation?.id != conversationId) {
        return;
      }

      final action = _chatActionDispatcher.dispatch(text);

      if (pendingImageRevision != null &&
          !_isNewRequestDuringImageRevision(text, action)) {
        state = state.copyWith(
          conversation: conversation,
          isSending: false,
          imageActionRequest: ChatImageActionRequested(
            subject: _combineImageRevisionPrompt(
              sourcePrompt: pendingImageRevision.sourcePrompt,
              revision: text,
            ),
            requestId: userMessage.id,
            sourceMessageId: userMessage.id,
            artifactId: pendingImageRevision.artifactId,
            artifactCreatedAt: pendingImageRevision.artifactCreatedAt,
            sourceArtifactVersionId:
                pendingImageRevision.sourceArtifactVersionId,
          ),
          isImageGenerationInProgress: true,
          activeImageRequestId: userMessage.id,
          clearMissionSuggestion: true,
          clearPendingClarification: true,
          clearPendingImageRevision: true,
        );
        return;
      }

      if (pendingImageRevision != null) {
        state = state.copyWith(clearPendingImageRevision: true);
      }

      if (action is ChatImageActionRequested) {
        state = state.copyWith(
          conversation: conversation,
          isSending: false,
          imageActionRequest: ChatImageActionRequested(
            subject: action.subject,
            requestId: userMessage.id,
            sourceMessageId: userMessage.id,
          ),
          isImageGenerationInProgress: true,
          activeImageRequestId: userMessage.id,
          clearMissionSuggestion: true,
          clearPendingImageRevision: true,
        );
        return;
      }

      if (action is ChatActionClarification) {
        final assistantCreatedAt = _nextActivityTime();
        final clarifiedConversation = conversation.copyWith(
          messages: <ChatMessage>[
            ...conversation.messages,
            ChatMessage(
              id: assistantCreatedAt.microsecondsSinceEpoch.toString(),
              role: ChatRole.assistant,
              content: action.message,
              createdAt: assistantCreatedAt,
            ),
          ],
          updatedAt: _nextActivityTime(),
        );

        await _conversationRepository.saveConversation(clarifiedConversation);

        if (!mounted || state.conversation?.id != conversationId) {
          return;
        }

        state = state.copyWith(
          conversation: clarifiedConversation,
          isSending: false,
          clearMissionSuggestion: true,
          clearImageActionRequest: true,
          clearPendingImageRevision: true,
        );
        return;
      }

      final clarification = _chatClarificationPolicy.resolve(
        prompt: text,
        pendingClarification: pendingClarification,
      );

      if (clarification is ChatClarificationRequest) {
        final assistantCreatedAt = _nextActivityTime();
        final clarifiedConversation = conversation.copyWith(
          messages: <ChatMessage>[
            ...conversation.messages,
            ChatMessage(
              id: assistantCreatedAt.microsecondsSinceEpoch.toString(),
              role: ChatRole.assistant,
              content: clarification.question,
              createdAt: assistantCreatedAt,
            ),
          ],
          updatedAt: _nextActivityTime(),
        );

        await _conversationRepository.saveConversation(clarifiedConversation);

        if (!mounted || state.conversation?.id != conversationId) {
          return;
        }

        state = state.copyWith(
          conversation: clarifiedConversation,
          isSending: false,
          pendingClarification: clarification.pendingIntent,
          clearMissionSuggestion: true,
          clearImageActionRequest: true,
          clearPendingImageRevision: true,
        );
        return;
      }

      final resolvedPrompt =
          (clarification as ChatClarificationProceed).resolvedPrompt;
      state = state.copyWith(
        clearPendingClarification: true,
        clearPendingImageRevision: true,
      );

      final workIntent = _chatWorkIntentResolver.resolve(resolvedPrompt);

      if (workIntent is ChatWorkUnsupported) {
        final assistantCreatedAt = _nextActivityTime();
        final unavailableConversation = conversation.copyWith(
          messages: <ChatMessage>[
            ...conversation.messages,
            ChatMessage(
              id: assistantCreatedAt.microsecondsSinceEpoch.toString(),
              role: ChatRole.assistant,
              content: workIntent.message,
              createdAt: assistantCreatedAt,
            ),
          ],
          updatedAt: _nextActivityTime(),
        );

        await _conversationRepository.saveConversation(unavailableConversation);

        if (!mounted) {
          return;
        }

        state = state.copyWith(
          conversation: unavailableConversation,
          isSending: false,
          clearMissionSuggestion: true,
          clearImageActionRequest: true,
        );
        return;
      }

      if (workIntent is ChatWorkOrchestrate) {
        state = state.copyWith(
          conversation: conversation,
          isSending: false,
          missionSuggestion: workIntent.missionSuggestion,
          clearImageActionRequest: true,
        );
        return;
      }

      final assistantCreatedAt = _nextActivityTime();
      final assistantMessageId = assistantCreatedAt.microsecondsSinceEpoch
          .toString();

      var assistantContent = '';
      String? currentProviderName;

      var streamingConversation = conversation.copyWith(
        messages: <ChatMessage>[
          ...conversation.messages,
          ChatMessage(
            id: assistantMessageId,
            role: ChatRole.assistant,
            content: assistantContent,
            createdAt: assistantCreatedAt,
          ),
        ],
        updatedAt: _nextActivityTime(),
      );

      state = state.copyWith(
        conversation: streamingConversation,
        isSending: true,
      );

      final responseGuidance = workIntent is ChatWorkProceed
          ? workIntent.responseGuidance
          : null;
      final conversationAiMessages = conversation.messages
          .map(_toAIMessage)
          .toList(growable: false);
      final aiMessages = <AIMessage>[
        ...conversationAiMessages.take(conversationAiMessages.length - 1),
        if (responseGuidance != null && responseGuidance.trim().isNotEmpty)
          AIMessage(role: AIMessageRole.system, content: responseGuidance),
        if (conversationAiMessages.isNotEmpty) conversationAiMessages.last,
      ];

      await for (final chunk in _aiChatService.sendMessages(aiMessages)) {
        if (!mounted || state.conversation?.id != conversationId) {
          return;
        }

        switch (chunk.type) {
          case AIChunkType.status:
            currentProviderName = _providerDisplayName(chunk.provider);

            // Keep provider metadata only.
            // Don't display internal routing/status messages.
            break;

          case AIChunkType.text:
            assistantContent += chunk.text;

            final assistantMessage = ChatMessage(
              id: assistantMessageId,
              role: ChatRole.assistant,
              content: assistantContent,
              createdAt: assistantCreatedAt,
              providerName: currentProviderName,
            );

            streamingConversation = conversation.copyWith(
              messages: <ChatMessage>[
                ...conversation.messages,
                assistantMessage,
              ],
              updatedAt: _nextActivityTime(),
            );

            state = state.copyWith(
              conversation: streamingConversation,
              isSending: true,
            );

            break;
          case AIChunkType.error:
            throw chunk.failure ??
                StateError(
                  chunk.error ?? 'The AI provider returned an unknown error.',
                );

          case AIChunkType.usage:
          case AIChunkType.done:
            break;
        }
      }

      await _conversationRepository.saveConversation(streamingConversation);

      if (!mounted || state.conversation?.id != conversationId) {
        return;
      }

      state = state.copyWith(
        conversation: streamingConversation,
        isSending: false,
        clearMissionSuggestion: true,
      );
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }

      _logRequestFailure(error, stackTrace);

      await _recordRetryableFailure(
        conversation: state.conversation ?? conversation,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Clears a transient image action after the Chat UI has started it.
  void consumeImageActionRequest() {
    if (state.imageActionRequest == null) {
      return;
    }

    state = state.copyWith(clearImageActionRequest: true);
  }

  /// Adds the one concise revision question for a persisted image result.
  Future<bool> beginImageRevision({required String resultMessageId}) async {
    if (state.isSending ||
        state.pendingClarification != null ||
        state.pendingImageRevision != null) {
      return false;
    }

    final conversation = state.conversation;
    if (conversation == null) {
      return false;
    }

    final resultIndex = conversation.messages.indexWhere(
      (message) => message.id == resultMessageId,
    );
    if (resultIndex < 0) {
      return false;
    }

    final resultMessage = conversation.messages[resultIndex];
    final attachment = resultMessage.attachment;
    if (attachment == null) {
      return false;
    }

    final imageSource = _imageSourceForResult(
      conversation: conversation,
      resultIndex: resultIndex,
      attachment: attachment,
    );
    if (imageSource == null) {
      return false;
    }

    const question = 'What would you like to change?';
    final createdAt = _nextActivityTime();
    final updatedConversation = conversation.copyWith(
      messages: <ChatMessage>[
        ...conversation.messages,
        ChatMessage(
          id: createdAt.microsecondsSinceEpoch.toString(),
          role: ChatRole.assistant,
          content: question,
          createdAt: createdAt,
        ),
      ],
      updatedAt: createdAt,
    );

    await _conversationRepository.saveConversation(updatedConversation);

    if (!mounted || state.conversation?.id != conversation.id) {
      return false;
    }

    state = state.copyWith(
      conversation: updatedConversation,
      isSending: false,
      pendingImageRevision: PendingImageRevision(
        sourcePrompt: imageSource.prompt,
        sourceResultMessageId: resultMessageId,
        sourceMessageId: imageSource.sourceMessageId,
        question: question,
        artifactId: imageSource.artifactId,
        artifactCreatedAt: imageSource.artifactCreatedAt,
        sourceArtifactVersionId: imageSource.artifactVersionId,
      ),
      clearError: true,
      clearMissionSuggestion: true,
      clearImageActionRequest: true,
    );
    return true;
  }

  /// Starts one explicit prompt-based version of a finished image.
  Future<bool> regenerateImage({required String resultMessageId}) async {
    if (state.isSending ||
        state.isImageGenerationInProgress ||
        state.pendingClarification != null ||
        state.pendingImageRevision != null) {
      return false;
    }

    final conversation = state.conversation;
    if (conversation == null) {
      return false;
    }

    final resultIndex = conversation.messages.indexWhere(
      (message) => message.id == resultMessageId,
    );
    if (resultIndex < 0) {
      return false;
    }

    final attachment = conversation.messages[resultIndex].attachment;
    if (attachment == null) {
      return false;
    }

    final imageSource = _imageSourceForResult(
      conversation: conversation,
      resultIndex: resultIndex,
      attachment: attachment,
    );
    if (imageSource == null) {
      return false;
    }

    final requestId =
        'regenerate-${_nextActivityTime().microsecondsSinceEpoch}';
    state = state.copyWith(
      conversation: conversation,
      isSending: false,
      isImageGenerationInProgress: true,
      imageActionRequest: ChatImageActionRequested(
        subject: imageSource.prompt,
        requestId: requestId,
        sourceMessageId: imageSource.sourceMessageId,
        artifactId: imageSource.artifactId,
        artifactCreatedAt: imageSource.artifactCreatedAt,
        sourceArtifactVersionId: imageSource.artifactVersionId,
      ),
      activeImageRequestId: requestId,
      clearError: true,
      clearMissionSuggestion: true,
      clearPendingClarification: true,
      clearPendingImageRevision: true,
    );
    return true;
  }

  void cancelImageGeneration({required String requestId}) {
    if (state.activeImageRequestId != requestId) {
      return;
    }

    state = state.copyWith(
      isImageGenerationInProgress: false,
      clearActiveImageRequestId: true,
      clearImageActionRequest: true,
    );
  }

  void finishImageGeneration({required String requestId}) {
    if (state.activeImageRequestId != requestId) {
      return;
    }

    state = state.copyWith(
      isImageGenerationInProgress: false,
      clearActiveImageRequestId: true,
    );
  }

  bool _isNewRequestDuringImageRevision(
    String text,
    ChatActionDispatchResult action,
  ) {
    return action is! ChatActionPassThrough ||
        _standaloneRequestDuringImageRevision.hasMatch(text);
  }

  String _combineImageRevisionPrompt({
    required String sourcePrompt,
    required String revision,
  }) {
    return '$sourcePrompt\n\nApply these requested changes: $revision';
  }

  _ImageResultSource? _imageSourceForResult({
    required Conversation conversation,
    required int resultIndex,
    required ChatAttachment attachment,
  }) {
    final storedPrompt = attachment.sourcePrompt?.trim();
    final storedSourceMessageId = attachment.sourceMessageId;
    if (storedSourceMessageId != null && storedSourceMessageId.isNotEmpty) {
      ChatMessage? sourceMessage;
      for (final message in conversation.messages) {
        if (message.id == storedSourceMessageId) {
          sourceMessage = message;
          break;
        }
      }

      if (storedPrompt != null &&
          storedPrompt.isNotEmpty &&
          sourceMessage?.role == ChatRole.user) {
        return _ImageResultSource(
          prompt: storedPrompt,
          sourceMessageId: storedSourceMessageId,
          artifactId: attachment.artifactId,
          artifactCreatedAt: attachment.artifact?.createdAt,
          artifactVersionId: attachment.artifactVersionId,
        );
      }

      final sourcePrompt = _imagePromptFromMessage(sourceMessage);
      if (sourcePrompt != null) {
        return _ImageResultSource(
          prompt: sourcePrompt,
          sourceMessageId: storedSourceMessageId,
          artifactId: attachment.artifactId,
          artifactCreatedAt: attachment.artifact?.createdAt,
          artifactVersionId: attachment.artifactVersionId,
        );
      }
    }

    for (var index = resultIndex - 1; index >= 0; index--) {
      final sourceMessage = conversation.messages[index];
      final sourcePrompt = _imagePromptFromMessage(sourceMessage);
      if (sourcePrompt != null) {
        return _ImageResultSource(
          prompt: sourcePrompt,
          sourceMessageId: sourceMessage.id,
          artifactId: attachment.artifactId,
          artifactCreatedAt: attachment.artifact?.createdAt,
          artifactVersionId: attachment.artifactVersionId,
        );
      }
    }

    return null;
  }

  String? _imagePromptFromMessage(ChatMessage? message) {
    if (message == null || message.role != ChatRole.user) {
      return null;
    }

    final action = _chatActionDispatcher.dispatch(message.content);
    return action is ChatImageActionRequested ? action.subject : null;
  }

  /// Adds one durable image-result message after its file has been saved.
  Future<bool> persistGeneratedImageResult({
    required String conversationId,
    required String sourceMessageId,
    required ChatAttachment attachment,
    String? requestId,
  }) async {
    if (requestId != null && state.activeImageRequestId != requestId) {
      return false;
    }

    final conversation = await _conversationRepository.getConversation(
      conversationId,
    );

    if (conversation == null) {
      return false;
    }

    final sourceMessageExists = conversation.messages.any(
      (message) =>
          message.id == sourceMessageId && message.role == ChatRole.user,
    );
    if (!sourceMessageExists) {
      return false;
    }

    final alreadyPersisted = conversation.messages.any(
      (message) => message.attachment?.id == attachment.id,
    );
    if (alreadyPersisted) {
      return true;
    }

    final createdAt = _nextActivityTime();
    final updatedConversation = conversation.copyWith(
      messages: <ChatMessage>[
        ...conversation.messages,
        ChatMessage(
          id: 'image-result-${attachment.id}',
          role: ChatRole.assistant,
          content: 'Done',
          createdAt: createdAt,
          attachment: attachment,
        ),
      ],
      updatedAt: createdAt,
    );

    await _conversationRepository.saveConversation(updatedConversation);

    if (mounted &&
        state.conversation?.id == conversationId &&
        (requestId == null || state.activeImageRequestId == requestId)) {
      state = state.copyWith(
        conversation: updatedConversation,
        isImageGenerationInProgress: false,
        clearActiveImageRequestId: requestId != null,
      );
    }

    return true;
  }

  /// Adds one durable, local-only video attachment after it has been copied
  /// into Ovexiq-owned storage.
  Future<bool> persistVideoAttachment({
    required String conversationId,
    required ChatAttachment attachment,
  }) async {
    if (attachment.artifact?.type != ArtifactType.video ||
        attachment.artifactVersion == null) {
      return false;
    }

    final conversation = await _conversationRepository.getConversation(
      conversationId,
    );
    if (conversation == null) {
      return false;
    }

    final alreadyPersisted = conversation.messages.any(
      (message) => message.attachment?.id == attachment.id,
    );
    if (alreadyPersisted) {
      return true;
    }

    final createdAt = _nextActivityTime();
    final updatedConversation = conversation.copyWith(
      messages: <ChatMessage>[
        ...conversation.messages,
        ChatMessage(
          id: 'video-attachment-${attachment.id}',
          role: ChatRole.user,
          content: 'Video added',
          createdAt: createdAt,
          attachment: attachment,
        ),
      ],
      updatedAt: createdAt,
    );

    await _conversationRepository.saveConversation(updatedConversation);

    if (mounted && state.conversation?.id == conversationId) {
      state = state.copyWith(
        conversation: updatedConversation,
        isSending: false,
        clearError: true,
      );
    }
    return true;
  }

  Future<void> regenerateLastResponse() async {
    if (state.isSending) {
      return;
    }

    // A rate-limited request is retryable, but not immediately. This also
    // protects against stale or programmatic Retry taps during the cooldown.
    if (state.error != null && !state.error!.canRetryLastResponse) {
      return;
    }

    final currentConversation = state.conversation;

    if (currentConversation == null || currentConversation.messages.isEmpty) {
      state = state.copyWith(
        error: const ChatControllerException(
          'There is no response to regenerate.',
        ),
      );
      return;
    }

    var lastUserMessageIndex = -1;

    for (
      var index = currentConversation.messages.length - 1;
      index >= 0;
      index--
    ) {
      if (currentConversation.messages[index].role == ChatRole.user) {
        lastUserMessageIndex = index;
        break;
      }
    }

    if (lastUserMessageIndex == -1) {
      state = state.copyWith(
        error: const ChatControllerException(
          'The last user message could not be found.',
        ),
      );
      return;
    }

    final userPrompt = currentConversation
        .messages[lastUserMessageIndex]
        .content
        .trim();

    if (userPrompt.isEmpty) {
      state = state.copyWith(
        error: const ChatControllerException('The last user message is empty.'),
      );
      return;
    }

    final conversationId = currentConversation.id;

    final baseMessages = currentConversation.messages.sublist(
      0,
      lastUserMessageIndex + 1,
    );

    var conversation = currentConversation.copyWith(
      messages: <ChatMessage>[...baseMessages],
      updatedAt: _nextActivityTime(),
    );

    ++_operationRevision;

    state = state.copyWith(
      conversation: conversation,
      isSending: true,
      clearError: true,
      clearMissionSuggestion: true,
    );

    try {
      await _conversationRepository.saveConversation(conversation);

      if (!mounted || state.conversation?.id != conversationId) {
        return;
      }

      final assistantCreatedAt = _nextActivityTime();
      final assistantMessageId = assistantCreatedAt.microsecondsSinceEpoch
          .toString();

      var assistantContent = '';
      String? currentProviderName;

      var streamingConversation = conversation.copyWith(
        messages: <ChatMessage>[
          ...conversation.messages,
          ChatMessage(
            id: assistantMessageId,
            role: ChatRole.assistant,
            content: assistantContent,
            createdAt: assistantCreatedAt,
          ),
        ],
        updatedAt: _nextActivityTime(),
      );

      state = state.copyWith(
        conversation: streamingConversation,
        isSending: true,
      );

      await for (final chunk in _aiChatService.sendMessages(
        conversation.messages.map(_toAIMessage).toList(growable: false),
      )) {
        if (!mounted || state.conversation?.id != conversationId) {
          return;
        }

        switch (chunk.type) {
          case AIChunkType.status:
            currentProviderName = _providerDisplayName(chunk.provider);

            // Keep provider metadata only.
            // Don't display internal routing/status messages.
            break;

          case AIChunkType.text:
            assistantContent += chunk.text;

            final assistantMessage = ChatMessage(
              id: assistantMessageId,
              role: ChatRole.assistant,
              content: assistantContent,
              createdAt: assistantCreatedAt,
              providerName: currentProviderName,
            );

            streamingConversation = conversation.copyWith(
              messages: <ChatMessage>[
                ...conversation.messages,
                assistantMessage,
              ],
              updatedAt: _nextActivityTime(),
            );

            state = state.copyWith(
              conversation: streamingConversation,
              isSending: true,
            );

            break;

          case AIChunkType.error:
            throw chunk.failure ??
                StateError(
                  chunk.error ?? 'The AI provider returned an unknown error.',
                );

          case AIChunkType.usage:
          case AIChunkType.done:
            break;
        }
      }

      await _conversationRepository.saveConversation(streamingConversation);

      if (!mounted || state.conversation?.id != conversationId) {
        return;
      }

      state = state.copyWith(
        conversation: streamingConversation,
        isSending: false,
        clearMissionSuggestion: true,
      );
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }

      _logRequestFailure(error, stackTrace);

      await _recordRetryableFailure(
        conversation: state.conversation ?? conversation,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _recordRetryableFailure({
    required Conversation conversation,
    required Object error,
    required StackTrace stackTrace,
  }) async {
    final lastUserIndex = conversation.messages.lastIndexWhere(
      (message) => message.role == ChatRole.user,
    );
    final responseLanguage = lastUserIndex < 0
        ? ResponseLanguage.english
        : responseLanguageFor(conversation.messages[lastUserIndex].content);
    final typedFailure = error is AIRequestFailure ? error : null;
    final retryCooldown =
        typedFailure?.category == AIRequestFailureCategory.rateLimited
        ? (typedFailure?.retryAfter ?? _fallbackRateLimitCooldown)
        : null;
    final retryAvailableAt = retryCooldown == null
        ? null
        : DateTime.now().add(retryCooldown);
    final message = _failureMessage(
      responseLanguage: responseLanguage,
      failure: typedFailure,
    );
    final lastAssistantIndex = conversation.messages.lastIndexWhere(
      (candidate) => candidate.role == ChatRole.assistant,
    );
    final messages = <ChatMessage>[...conversation.messages];
    if (lastAssistantIndex >= 0 && lastAssistantIndex > lastUserIndex) {
      messages[lastAssistantIndex] = messages[lastAssistantIndex].copyWith(
        content: message,
        isError: true,
      );
    } else {
      final createdAt = _nextActivityTime();
      messages.add(
        ChatMessage(
          id: createdAt.microsecondsSinceEpoch.toString(),
          role: ChatRole.assistant,
          content: message,
          createdAt: createdAt,
          isError: true,
        ),
      );
    }
    final failedConversation = conversation.copyWith(
      messages: messages,
      updatedAt: _nextActivityTime(),
    );
    try {
      await _conversationRepository.saveConversation(failedConversation);
    } catch (_) {
      // The visible state remains retryable when persistence is unavailable.
    }
    if (!mounted) {
      return;
    }
    state = state.copyWith(
      conversation: failedConversation,
      isSending: false,
      error: ChatControllerException(
        typedFailure?.category == AIRequestFailureCategory.rateLimited
            ? message
            : typedFailure?.userMessage ?? error.toString(),
        cause: error,
        stackTrace: stackTrace,
        canRetryLastResponse:
            (typedFailure?.retryable ?? true) && retryAvailableAt == null,
        retryAvailableAt: retryAvailableAt,
      ),
    );
    _scheduleRetryCooldown(retryAvailableAt);
  }

  String _failureMessage({
    required ResponseLanguage responseLanguage,
    required AIRequestFailure? failure,
  }) {
    if (failure?.category == AIRequestFailureCategory.rateLimited) {
      return responseLanguage == ResponseLanguage.burmese
          ? 'ခဏလောက်စောင့်ပြီး ပြန်စမ်းပေးပါ။'
          : 'Please wait a moment and try again.';
    }
    return responseLanguage == ResponseLanguage.burmese
        ? 'Ovexiq က ဒီအဖြေကို အပြီးမပေးနိုင်သေးပါ။ ထပ်စမ်းကြည့်ပါ။'
        : "Ovexiq couldn't finish that request. Please try again.";
  }

  void _scheduleRetryCooldown(DateTime? retryAvailableAt) {
    _retryCooldownTimer?.cancel();
    if (retryAvailableAt == null) {
      return;
    }
    final delay = retryAvailableAt.difference(DateTime.now());
    if (delay <= Duration.zero) {
      return;
    }
    _retryCooldownTimer = Timer(delay, () {
      if (!mounted || state.error?.retryAvailableAt != retryAvailableAt) {
        return;
      }
      final error = state.error!;
      state = state.copyWith(
        error: ChatControllerException(
          error.message,
          cause: error.cause,
          stackTrace: error.stackTrace,
          canRetryLastResponse: true,
        ),
      );
    });
  }

  @override
  void dispose() {
    _retryCooldownTimer?.cancel();
    if (!mounted) {
      return;
    }
    super.dispose();
  }

  void _logRequestFailure(Object error, StackTrace stackTrace) {
    if (error is AIRequestFailure) {
      // AIService emitted the one release-safe terminal diagnostic line.
      return;
    }

    debugPrint(
      'Ovexiq chat request failure '
      'category=unknown retryable=true stage=chat_stream '
      'reason=unclassified_chat_failure',
    );
    debugPrintStack(stackTrace: stackTrace);
  }

  MessageFeedback feedbackFor(String messageId) {
    return state.feedbackByMessageId[messageId] ?? MessageFeedback.none;
  }

  void toggleLike(String messageId) {
    final current = feedbackFor(messageId);

    _setMessageFeedback(
      messageId,
      current == MessageFeedback.liked
          ? MessageFeedback.none
          : MessageFeedback.liked,
    );
  }

  void toggleDislike(String messageId) {
    final current = feedbackFor(messageId);

    _setMessageFeedback(
      messageId,
      current == MessageFeedback.disliked
          ? MessageFeedback.none
          : MessageFeedback.disliked,
    );
  }

  void _setMessageFeedback(String messageId, MessageFeedback feedback) {
    final updated = <String, MessageFeedback>{...state.feedbackByMessageId};

    if (feedback == MessageFeedback.none) {
      updated.remove(messageId);
    } else {
      updated[messageId] = feedback;
    }

    state = state.copyWith(feedbackByMessageId: updated);
  }

  String _providerDisplayName(ProviderType provider) {
    return switch (provider) {
      ProviderType.openAI => 'OpenAI',
      ProviderType.gemini => 'Gemini',
      ProviderType.claude => 'Claude',
      ProviderType.deepSeek => 'DeepSeek',
      ProviderType.grok => 'Grok',
      ProviderType.mistral => 'Mistral',
      ProviderType.ollama => 'Ollama',
    };
  }

  AIMessage _toAIMessage(ChatMessage message) {
    final role = switch (message.role) {
      ChatRole.user => AIMessageRole.user,
      ChatRole.assistant => AIMessageRole.assistant,
      ChatRole.system => AIMessageRole.system,
    };

    return AIMessage(role: role, content: message.content);
  }

  String _nextConversationId(DateTime now) {
    final timestamp = now.microsecondsSinceEpoch;
    final nextTimestamp = timestamp > _lastConversationIdMicros
        ? timestamp
        : _lastConversationIdMicros + 1;

    _lastConversationIdMicros = nextTimestamp;
    return nextTimestamp.toString();
  }

  DateTime _nextActivityTime() {
    final now = DateTime.now();
    final timestamp = now.microsecondsSinceEpoch;
    final nextTimestamp = timestamp > _lastActivityMicros
        ? timestamp
        : _lastActivityMicros + 1;

    _lastActivityMicros = nextTimestamp;
    return DateTime.fromMicrosecondsSinceEpoch(nextTimestamp, isUtc: now.isUtc);
  }

  void _trackActivity(DateTime timestamp) {
    if (timestamp.microsecondsSinceEpoch > _lastActivityMicros) {
      _lastActivityMicros = timestamp.microsecondsSinceEpoch;
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

class _ImageResultSource {
  const _ImageResultSource({
    required this.prompt,
    required this.sourceMessageId,
    this.artifactId,
    this.artifactCreatedAt,
    this.artifactVersionId,
  });

  final String prompt;
  final String sourceMessageId;
  final String? artifactId;
  final DateTime? artifactCreatedAt;
  final String? artifactVersionId;
}

class ChatState {
  const ChatState({
    this.conversation,
    this.isLoading = false,
    this.isSending = false,
    this.isImageGenerationInProgress = false,
    this.activeImageRequestId,
    this.error,
    this.feedbackByMessageId = const <String, MessageFeedback>{},
    this.missionSuggestion,
    this.imageActionRequest,
    this.pendingClarification,
    this.pendingImageRevision,
  });

  final Conversation? conversation;
  final bool isLoading;
  final bool isSending;
  final bool isImageGenerationInProgress;
  final String? activeImageRequestId;
  final ChatControllerException? error;
  final Map<String, MessageFeedback> feedbackByMessageId;
  final MissionSuggestion? missionSuggestion;
  final ChatImageActionRequested? imageActionRequest;
  final PendingChatClarification? pendingClarification;
  final PendingImageRevision? pendingImageRevision;

  List<ChatMessage> get messages =>
      conversation?.messages ?? const <ChatMessage>[];

  bool get isBusy => isLoading || isSending;

  ChatState copyWith({
    Conversation? conversation,
    bool? isLoading,
    bool? isSending,
    bool? isImageGenerationInProgress,
    String? activeImageRequestId,
    ChatControllerException? error,
    Map<String, MessageFeedback>? feedbackByMessageId,
    MissionSuggestion? missionSuggestion,
    ChatImageActionRequested? imageActionRequest,
    PendingChatClarification? pendingClarification,
    PendingImageRevision? pendingImageRevision,
    bool clearConversation = false,
    bool clearError = false,
    bool clearMissionSuggestion = false,
    bool clearImageActionRequest = false,
    bool clearActiveImageRequestId = false,
    bool clearPendingClarification = false,
    bool clearPendingImageRevision = false,
  }) {
    return ChatState(
      conversation: clearConversation
          ? null
          : conversation ?? this.conversation,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      isImageGenerationInProgress:
          isImageGenerationInProgress ?? this.isImageGenerationInProgress,
      activeImageRequestId: clearActiveImageRequestId
          ? null
          : activeImageRequestId ?? this.activeImageRequestId,
      error: clearError ? null : error ?? this.error,
      feedbackByMessageId: feedbackByMessageId ?? this.feedbackByMessageId,
      missionSuggestion: clearMissionSuggestion
          ? null
          : missionSuggestion ?? this.missionSuggestion,
      imageActionRequest: clearImageActionRequest
          ? null
          : imageActionRequest ?? this.imageActionRequest,
      pendingClarification: clearPendingClarification
          ? null
          : pendingClarification ?? this.pendingClarification,
      pendingImageRevision: clearPendingImageRevision
          ? null
          : pendingImageRevision ?? this.pendingImageRevision,
    );
  }
}

class ChatControllerException implements Exception {
  const ChatControllerException(
    this.message, {
    this.cause,
    this.stackTrace,
    this.canRetryLastResponse = false,
    this.retryAvailableAt,
  });

  final String message;
  final Object? cause;
  final StackTrace? stackTrace;
  final bool canRetryLastResponse;
  final DateTime? retryAvailableAt;

  @override
  String toString() => message;
}
