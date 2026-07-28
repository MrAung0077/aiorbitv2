import 'package:aiorbit/core/ai/ai.dart';
import 'package:aiorbit/features/mission/models/mission_suggestion.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../repositories/conversation_repository.dart';
import '../services/ai_chat_service.dart';
import '../services/mission_suggestion_service.dart';
import '../models/message_feedback.dart';

final aiChatServiceProvider = Provider<AIChatService>((ref) {
  return AIChatService();
});

final missionSuggestionServiceProvider = Provider<MissionSuggestionService>((
  ref,
) {
  return const MissionSuggestionService();
});

final conversationRepositoryProvider = Provider<ConversationRepository>((ref) {
  return ConversationRepository();
});

final chatControllerProvider = StateNotifierProvider<ChatController, ChatState>(
  (ref) {
    return ChatController(
      aiChatService: ref.watch(aiChatServiceProvider),
      conversationRepository: ref.watch(conversationRepositoryProvider),
      missionSuggestionService: ref.watch(missionSuggestionServiceProvider),
    );
  },
);

class ChatController extends StateNotifier<ChatState> {
  ChatController({
    required AIChatService aiChatService,
    required ConversationRepository conversationRepository,
    required MissionSuggestionService missionSuggestionService,
  }) : _aiChatService = aiChatService,
       _conversationRepository = conversationRepository,
       _missionSuggestionService = missionSuggestionService,
       super(const ChatState());

  final AIChatService _aiChatService;
  final ConversationRepository _conversationRepository;
  final MissionSuggestionService _missionSuggestionService;

  int _operationRevision = 0;

  Future<void> createNewConversation() async {
    final revision = ++_operationRevision;
    final now = DateTime.now();

    state = state.copyWith(isLoading: true, clearError: true);

    final conversation = Conversation(
      id: now.microsecondsSinceEpoch.toString(),
      title: 'New Chat',
      messages: const [],
      createdAt: now,
      updatedAt: now,
    );

    try {
      await _conversationRepository.saveConversation(conversation);

      if (!mounted || revision != _operationRevision) {
        return;
      }

      state = ChatState(conversation: conversation);
    } catch (error, stackTrace) {
      debugPrint('AI SEND ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      state = state.copyWith(
        isSending: false,
        error: ChatControllerException(
          error.toString(),
          cause: error,
          stackTrace: stackTrace,
        ),
      );
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
        await createNewConversation();
        return;
      }

      state = ChatState(conversation: conversations.first);
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

    if (text.isEmpty || state.isSending) {
      return;
    }

    var conversation = state.conversation;

    if (conversation == null) {
      final now = DateTime.now();

      conversation = Conversation(
        id: now.microsecondsSinceEpoch.toString(),
        title: Conversation.generateTitleFromPrompt(text),
        messages: const [],
        createdAt: now,
        updatedAt: now,
      );
    }

    final conversationId = conversation.id;
    final now = DateTime.now();

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
    );

    try {
      await _conversationRepository.saveConversation(conversation);

      if (!mounted || state.conversation?.id != conversationId) {
        return;
      }

      final assistantMessageId = DateTime.now().microsecondsSinceEpoch
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
            createdAt: DateTime.now(),
          ),
        ],
        updatedAt: DateTime.now(),
      );

      state = state.copyWith(
        conversation: streamingConversation,
        isSending: true,
      );

      await for (final chunk in _aiChatService.sendMessage(text)) {
        if (!mounted || state.conversation?.id != conversationId) {
          return;
        }

        switch (chunk.type) {
          case AIChunkType.status:
            currentProviderName = _providerDisplayName(chunk.provider);

            assistantContent += '${chunk.text}\n\n';

            final assistantMessage = ChatMessage(
              id: assistantMessageId,
              role: ChatRole.assistant,
              content: assistantContent,
              createdAt: DateTime.now(),
              providerName: currentProviderName,
            );

            streamingConversation = conversation.copyWith(
              messages: <ChatMessage>[
                ...conversation.messages,
                assistantMessage,
              ],
              updatedAt: DateTime.now(),
            );

            state = state.copyWith(
              conversation: streamingConversation,
              isSending: true,
            );

            break;
          case AIChunkType.text:
            assistantContent += chunk.text;

            final assistantMessage = ChatMessage(
              id: assistantMessageId,
              role: ChatRole.assistant,
              content: assistantContent,
              createdAt: DateTime.now(),
              providerName: currentProviderName,
            );

            streamingConversation = conversation.copyWith(
              messages: <ChatMessage>[
                ...conversation.messages,
                assistantMessage,
              ],
              updatedAt: DateTime.now(),
            );

            state = state.copyWith(
              conversation: streamingConversation,
              isSending: true,
            );

          case AIChunkType.error:
            throw StateError(
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

      final missionSuggestion = _missionSuggestionService.suggestFor(text);

      state = state.copyWith(
        conversation: streamingConversation,
        isSending: false,
        missionSuggestion: missionSuggestion,
        clearMissionSuggestion: missionSuggestion == null,
      );
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }

      debugPrint('====================================');
      debugPrint(error.toString());
      debugPrint(stackTrace.toString());
      debugPrint('====================================');

      state = state.copyWith(
        isSending: false,
        error: ChatControllerException(
          error.toString(),
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<void> regenerateLastResponse() async {
    if (state.isSending) {
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
      updatedAt: DateTime.now(),
    );

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

      final assistantMessageId = DateTime.now().microsecondsSinceEpoch
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
            createdAt: DateTime.now(),
          ),
        ],
        updatedAt: DateTime.now(),
      );

      state = state.copyWith(
        conversation: streamingConversation,
        isSending: true,
      );

      await for (final chunk in _aiChatService.sendMessage(userPrompt)) {
        if (!mounted || state.conversation?.id != conversationId) {
          return;
        }

        switch (chunk.type) {
          case AIChunkType.status:
            currentProviderName = _providerDisplayName(chunk.provider);
            assistantContent += '${chunk.text}\n\n';

            final assistantMessage = ChatMessage(
              id: assistantMessageId,
              role: ChatRole.assistant,
              content: assistantContent,
              createdAt: DateTime.now(),
              providerName: currentProviderName,
            );

            streamingConversation = conversation.copyWith(
              messages: <ChatMessage>[
                ...conversation.messages,
                assistantMessage,
              ],
              updatedAt: DateTime.now(),
            );

            state = state.copyWith(
              conversation: streamingConversation,
              isSending: true,
            );

          case AIChunkType.text:
            assistantContent += chunk.text;

            final assistantMessage = ChatMessage(
              id: assistantMessageId,
              role: ChatRole.assistant,
              content: assistantContent,
              createdAt: DateTime.now(),
              providerName: currentProviderName,
            );

            streamingConversation = conversation.copyWith(
              messages: <ChatMessage>[
                ...conversation.messages,
                assistantMessage,
              ],
              updatedAt: DateTime.now(),
            );

            state = state.copyWith(
              conversation: streamingConversation,
              isSending: true,
            );

          case AIChunkType.error:
            throw StateError(
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

      final missionSuggestion = _missionSuggestionService.suggestFor(
        userPrompt,
      );

      state = state.copyWith(
        conversation: streamingConversation,
        isSending: false,
        missionSuggestion: missionSuggestion,
        clearMissionSuggestion: missionSuggestion == null,
      );
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }

      debugPrint('AI REGENERATE ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);

      state = state.copyWith(
        isSending: false,
        error: ChatControllerException(
          error.toString(),
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
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

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

class ChatState {
  const ChatState({
    this.conversation,
    this.isLoading = false,
    this.isSending = false,
    this.error,
    this.feedbackByMessageId = const <String, MessageFeedback>{},
    this.missionSuggestion,
  });

  final Conversation? conversation;
  final bool isLoading;
  final bool isSending;
  final ChatControllerException? error;
  final Map<String, MessageFeedback> feedbackByMessageId;
  final MissionSuggestion? missionSuggestion;

  List<ChatMessage> get messages =>
      conversation?.messages ?? const <ChatMessage>[];

  bool get isBusy => isLoading || isSending;

  ChatState copyWith({
    Conversation? conversation,
    bool? isLoading,
    bool? isSending,
    ChatControllerException? error,
    Map<String, MessageFeedback>? feedbackByMessageId,
    MissionSuggestion? missionSuggestion,
    bool clearConversation = false,
    bool clearError = false,
    bool clearMissionSuggestion = false,
  }) {
    return ChatState(
      conversation: clearConversation
          ? null
          : conversation ?? this.conversation,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      error: clearError ? null : error ?? this.error,
      feedbackByMessageId: feedbackByMessageId ?? this.feedbackByMessageId,
      missionSuggestion: clearMissionSuggestion
          ? null
          : missionSuggestion ?? this.missionSuggestion,
    );
  }
}

class ChatControllerException implements Exception {
  const ChatControllerException(this.message, {this.cause, this.stackTrace});

  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() => message;
}
