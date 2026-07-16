import 'package:aiorbit/core/ai/ai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../repositories/conversation_repository.dart';
import '../services/ai_chat_service.dart';

final aiChatServiceProvider = Provider<AIChatService>((ref) {
  return AIChatService();
});

final conversationRepositoryProvider = Provider<ConversationRepository>((ref) {
  return ConversationRepository();
});

final chatControllerProvider = StateNotifierProvider<ChatController, ChatState>(
  (ref) {
    return ChatController(
      aiChatService: ref.watch(aiChatServiceProvider),
      conversationRepository: ref.watch(conversationRepositoryProvider),
    );
  },
);

class ChatController extends StateNotifier<ChatState> {
  ChatController({
    required AIChatService aiChatService,
    required ConversationRepository conversationRepository,
  }) : _aiChatService = aiChatService,
       _conversationRepository = conversationRepository,
       super(const ChatState());

  final AIChatService _aiChatService;
  final ConversationRepository _conversationRepository;

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
      if (!mounted || revision != _operationRevision) {
        return;
      }

      state = ChatState(
        error: ChatControllerException(
          'Could not create a new conversation.',
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
    );

    try {
      await _conversationRepository.saveConversation(conversation);

      if (!mounted || state.conversation?.id != conversationId) {
        return;
      }

      final assistantMessageId = DateTime.now().microsecondsSinceEpoch
          .toString();

      var assistantContent = '';

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
          case AIChunkType.text:
            assistantContent += chunk.text;

            final assistantMessage = ChatMessage(
              id: assistantMessageId,
              role: ChatRole.assistant,
              content: assistantContent,
              createdAt: DateTime.now(),
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

          case AIChunkType.status:
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
      );
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }

      state = state.copyWith(
        isSending: false,
        error: ChatControllerException(
          'Could not send the message. Please try again.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
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
  });

  final Conversation? conversation;
  final bool isLoading;
  final bool isSending;
  final ChatControllerException? error;

  List<ChatMessage> get messages =>
      conversation?.messages ?? const <ChatMessage>[];

  bool get isBusy => isLoading || isSending;

  ChatState copyWith({
    Conversation? conversation,
    bool? isLoading,
    bool? isSending,
    ChatControllerException? error,
    bool clearConversation = false,
    bool clearError = false,
  }) {
    return ChatState(
      conversation: clearConversation
          ? null
          : conversation ?? this.conversation,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      error: clearError ? null : error ?? this.error,
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
