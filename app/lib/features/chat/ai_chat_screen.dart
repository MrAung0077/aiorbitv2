import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/app_conversation_header.dart';
import '../../core/widgets/app_message_bubble.dart';
import '../../core/widgets/app_prompt_composer.dart';
import '../../core/widgets/app_typing_indicator.dart';
import 'models/brain_status.dart';
import 'models/chat_message.dart';
import 'models/message_feedback.dart';
import 'models/router_decision.dart';
import 'providers/brain_provider.dart';
import 'providers/chat_controller.dart';
import 'services/router_preview_service.dart';
import 'widgets/brain_overlay.dart';

class AIChatScreen extends ConsumerStatefulWidget {
  const AIChatScreen({super.key});

  @override
  ConsumerState<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends ConsumerState<AIChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final RouterPreviewService _routerPreviewService =
      const RouterPreviewService();

  RouterDecision? _routerDecision;

  @override
  void initState() {
    super.initState();

    Future<void>.microtask(() async {
      if (!mounted) {
        return;
      }

      await ref
          .read(chatControllerProvider.notifier)
          .loadMostRecentConversation();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    final chatState = ref.read(chatControllerProvider);

    if (text.isEmpty || chatState.isSending) {
      return;
    }

    final decision = _routerPreviewService.analyze(text);

    setState(() {
      _routerDecision = decision;
    });

    _controller.clear();
    _focusNode.unfocus();

    ref.read(brainStatusProvider.notifier).state = BrainStatus.understanding;
    ref.read(brainOverlayVisibleProvider.notifier).state = true;

    _scrollToBottom();

    try {
      final sendFuture = ref
          .read(chatControllerProvider.notifier)
          .sendMessage(text);

      final animationFuture = _runBrainSequence();

      await Future.wait<void>([sendFuture, animationFuture]);
    } finally {
      if (mounted) {
        ref.read(brainStatusProvider.notifier).state = BrainStatus.completed;

        await Future<void>.delayed(const Duration(milliseconds: 350));
      }

      if (mounted) {
        ref.read(brainOverlayVisibleProvider.notifier).state = false;
        ref.read(brainStatusProvider.notifier).state = null;

        setState(() {
          _routerDecision = null;
        });

        _scrollToBottom();
        _focusNode.requestFocus();
      }
    }
  }

  Future<void> _runBrainSequence() async {
    await Future<void>.delayed(const Duration(milliseconds: 650));

    if (!mounted) {
      return;
    }

    ref.read(brainStatusProvider.notifier).state = BrainStatus.selectingAi;

    await Future<void>.delayed(const Duration(milliseconds: 650));

    if (!mounted) {
      return;
    }

    ref.read(brainStatusProvider.notifier).state = BrainStatus.optimizing;

    await Future<void>.delayed(const Duration(milliseconds: 650));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _copyMessage(String text) {
    Clipboard.setData(ClipboardData(text: text));

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ChatState>(chatControllerProvider, (previous, next) {
      final messageCountChanged =
          previous?.messages.length != next.messages.length;

      final sendingFinished = previous?.isSending == true && !next.isSending;

      if (messageCountChanged || sendingFinished) {
        _scrollToBottom();
      }
    });

    final chatState = ref.watch(chatControllerProvider);
    final brainStatus = ref.watch(brainStatusProvider);
    final isBrainOverlayVisible = ref.watch(brainOverlayVisibleProvider);

    final messages = chatState.messages;
    final hasError = chatState.error != null;

    return Scaffold(
      appBar: AppConversationHeader(
        title: chatState.conversation?.title ?? 'New Conversation',
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: messages.isEmpty && !hasError
                      ? const _EmptyChatView()
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount:
                              messages.length +
                              (chatState.isSending && messages.isEmpty
                                  ? 1
                                  : 0) +
                              (hasError ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index < messages.length) {
                              final message = messages[index];

                              final isLastAssistantMessage =
                                  index == messages.length - 1 &&
                                  message.role == ChatRole.assistant &&
                                  !message.isError;

                              return AppMessageBubble(
                                message: message,
                                feedback:
                                    chatState.feedbackByMessageId[message.id] ??
                                    MessageFeedback.none,
                                providerName: message.providerName,
                                isStreaming:
                                    chatState.isSending &&
                                    index == messages.length - 1 &&
                                    message.role == ChatRole.assistant,
                                onCopy: () {
                                  _copyMessage(message.content);
                                },
                                onLike: () {
                                  ref
                                      .read(chatControllerProvider.notifier)
                                      .toggleLike(message.id);
                                },
                                onDislike: () {
                                  ref
                                      .read(chatControllerProvider.notifier)
                                      .toggleDislike(message.id);
                                },
                                onRegenerate: isLastAssistantMessage
                                    ? () {
                                        ref
                                            .read(
                                              chatControllerProvider.notifier,
                                            )
                                            .regenerateLastResponse();
                                      }
                                    : null,
                              );
                            }

                            if (chatState.isSending &&
                                messages.isEmpty &&
                                index == messages.length) {
                              return const AppTypingIndicator(
                                label: 'AIOrbit is preparing...',
                              );
                            }

                            const errorMessage =
                                'Something went wrong. Please try again.';

                            return AppMessageBubble(
                              message: ChatMessage(
                                id: 'chat-error',
                                role: ChatRole.assistant,
                                content: errorMessage,
                                createdAt: DateTime.now(),
                                isError: true,
                              ),
                              onCopy: () {
                                _copyMessage(errorMessage);
                              },
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: AppPromptComposer(
                    controller: _controller,
                    focusNode: _focusNode,
                    isSending: chatState.isSending,
                    onSend: _sendMessage,
                    hintText: 'Ask AIOrbit anything...',
                    maxLines: 5,
                  ),
                ),
              ],
            ),
          ),
          if (isBrainOverlayVisible && _routerDecision != null)
            Positioned.fill(
              child: BrainOverlay(
                currentStatus: brainStatus ?? BrainStatus.understanding,
                decision: _routerDecision!,
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyChatView extends StatelessWidget {
  const _EmptyChatView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_awesome, size: 64),
            const SizedBox(height: 16),
            Text(
              'Welcome to AIOrbit',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Start a new conversation.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
