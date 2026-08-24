import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/providers/ovexiq_image_api_client.dart';
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
import 'providers/chat_image_generation_provider.dart';
import 'services/router_preview_service.dart';
import 'widgets/brain_overlay.dart';
import 'widgets/finished_result_card.dart';
import 'widgets/generated_image_card.dart';
import '../mission/providers/chat_mission_coordinator_provider.dart';
import '../mission/services/chat_mission_coordinator.dart';
import '../mission/services/chat_mission_result_adapter.dart';

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
  _MissionWorkState _missionWorkState = _MissionWorkState.idle;
  ChatMissionResult? _finishedMissionResult;
  _ImageWorkState _imageWorkState = _ImageWorkState.idle;
  GeneratedImage? _generatedImage;
  final Set<String> _startedImageRequestKeys = <String>{};

  @override
  void initState() {
    super.initState();

    ref.listenManual<ChatState>(
      chatControllerProvider,
      _onChatStateChanged,
      fireImmediately: true,
    );

    Future<void>.microtask(() async {
      if (!mounted) {
        return;
      }

      final chatState = ref.read(chatControllerProvider);

      if (chatState.conversation == null && !chatState.isLoading) {
        await ref
            .read(chatControllerProvider.notifier)
            .loadMostRecentConversation();
      }
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

    if (text.isEmpty ||
        chatState.isSending ||
        _missionWorkState == _MissionWorkState.working ||
        _imageWorkState == _ImageWorkState.working) {
      return;
    }

    final decision = _routerPreviewService.analyze(text);

    setState(() {
      _routerDecision = decision;
      _missionWorkState = _MissionWorkState.idle;
      _finishedMissionResult = null;
      _imageWorkState = _ImageWorkState.idle;
      _generatedImage = null;
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

  Future<void> _startSuggestedMissionIfNeeded(ChatState chatState) async {
    final suggestion = chatState.missionSuggestion;
    final conversationId = chatState.conversation?.id;

    if (suggestion == null ||
        conversationId == null ||
        _missionWorkState == _MissionWorkState.working) {
      return;
    }

    setState(() {
      _missionWorkState = _MissionWorkState.working;
    });

    try {
      final result = await ref
          .read(chatMissionCoordinatorProvider)
          .startOrResume(
            suggestion: suggestion,
            conversationId: conversationId,
          );

      if (!mounted) {
        return;
      }

      final packagedResult = result.outcome == ChatMissionRunOutcome.completed
          ? const ChatMissionResultAdapter().fromMission(result.mission)
          : null;

      setState(() {
        _finishedMissionResult = packagedResult;
        _missionWorkState =
            result.outcome == ChatMissionRunOutcome.failed ||
                packagedResult == null
            ? _MissionWorkState.failed
            : _MissionWorkState.idle;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _missionWorkState = _MissionWorkState.failed;
        });
      }
    }
  }

  Future<void> _startImageGenerationIfNeeded(ChatState chatState) async {
    final request = chatState.imageActionRequest;
    final conversationId = chatState.conversation?.id;
    final messages = chatState.messages;

    if (request == null || conversationId == null || messages.isEmpty) {
      return;
    }

    final requestKey = '$conversationId:${messages.last.id}';
    if (!_startedImageRequestKeys.add(requestKey)) {
      return;
    }

    setState(() {
      _imageWorkState = _ImageWorkState.working;
      _generatedImage = null;
    });
    ref.read(chatControllerProvider.notifier).consumeImageActionRequest();

    try {
      final image = await ref
          .read(chatImageGenerationServiceProvider)
          .generate(prompt: request.subject);

      if (!mounted) {
        return;
      }

      setState(() {
        _generatedImage = image;
        _imageWorkState = _ImageWorkState.idle;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _imageWorkState = _ImageWorkState.failed;
        });
      }
    }
  }

  void _onChatStateChanged(ChatState? previous, ChatState next) {
    final messageCountChanged =
        previous?.messages.length != next.messages.length;

    final sendingFinished = previous?.isSending == true && !next.isSending;

    final missionSuggestionAppeared =
        previous?.missionSuggestion != next.missionSuggestion &&
        next.missionSuggestion != null;
    final imageActionAppeared =
        previous?.imageActionRequest != next.imageActionRequest &&
        next.imageActionRequest != null;

    if (missionSuggestionAppeared || imageActionAppeared) {
      if (previous == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _startDetectedWork(
              ref.read(chatControllerProvider),
              missionSuggestionAppeared: missionSuggestionAppeared,
              imageActionAppeared: imageActionAppeared,
            );
          }
        });
      } else {
        _startDetectedWork(
          next,
          missionSuggestionAppeared: missionSuggestionAppeared,
          imageActionAppeared: imageActionAppeared,
        );
      }
    }

    if (messageCountChanged ||
        sendingFinished ||
        missionSuggestionAppeared ||
        imageActionAppeared) {
      Future<void>.delayed(const Duration(milliseconds: 80), () {
        if (mounted) {
          _scrollToBottom();
        }
      });
    }
  }

  void _startDetectedWork(
    ChatState chatState, {
    required bool missionSuggestionAppeared,
    required bool imageActionAppeared,
  }) {
    if (missionSuggestionAppeared) {
      _startSuggestedMissionIfNeeded(chatState);
    }

    if (imageActionAppeared) {
      _startImageGenerationIfNeeded(chatState);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatControllerProvider);
    final brainStatus = ref.watch(brainStatusProvider);
    final isBrainOverlayVisible = ref.watch(brainOverlayVisibleProvider);

    final messages = chatState.messages;
    final hasError = chatState.error != null;
    final canRetryLastResponse =
        chatState.error?.canRetryLastResponse == true && !chatState.isSending;
    final isMissionWorking = _missionWorkState == _MissionWorkState.working;
    final hasMissionFailure = _missionWorkState == _MissionWorkState.failed;
    final finishedMissionResult = _finishedMissionResult;
    final isImageWorking = _imageWorkState == _ImageWorkState.working;
    final hasImageFailure = _imageWorkState == _ImageWorkState.failed;
    final generatedImage = _generatedImage;
    final hasImageStatus =
        isImageWorking || hasImageFailure || generatedImage != null;
    final hasWorkStatus =
        hasImageStatus ||
        isMissionWorking ||
        hasMissionFailure ||
        finishedMissionResult != null;

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
                              (hasWorkStatus ? 1 : 0) +
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
                                onRegenerate:
                                    isLastAssistantMessage && !isMissionWorking
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

                            if (hasImageStatus && index == messages.length) {
                              if (generatedImage != null) {
                                return GeneratedImageCard(
                                  image: generatedImage,
                                );
                              }

                              return _ImageWorkStatus(
                                isWorking: isImageWorking,
                              );
                            }

                            if ((isMissionWorking ||
                                    hasMissionFailure ||
                                    finishedMissionResult != null) &&
                                index == messages.length) {
                              if (finishedMissionResult != null) {
                                return FinishedResultCard(
                                  result: finishedMissionResult,
                                );
                              }

                              return _MissionWorkStatus(
                                isWorking: isMissionWorking,
                              );
                            }

                            if (chatState.isSending &&
                                messages.isEmpty &&
                                index == messages.length) {
                              return const AppTypingIndicator(
                                label: 'Ovexiq is preparing...',
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
                              onRetry: canRetryLastResponse
                                  ? () {
                                      ref
                                          .read(chatControllerProvider.notifier)
                                          .regenerateLastResponse();
                                    }
                                  : null,
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: AppPromptComposer(
                    controller: _controller,
                    focusNode: _focusNode,
                    isSending:
                        chatState.isSending ||
                        isMissionWorking ||
                        isImageWorking,
                    onSend: _sendMessage,
                    hintText: 'Ask Ovexiq anything...',
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

enum _MissionWorkState { idle, working, failed }

enum _ImageWorkState { idle, working, failed }

class _MissionWorkStatus extends StatelessWidget {
  const _MissionWorkStatus({required this.isWorking});

  final bool isWorking;

  @override
  Widget build(BuildContext context) {
    if (isWorking) {
      return const AppTypingIndicator(label: 'Ovexiq is working...');
    }

    return const Padding(
      padding: EdgeInsets.only(top: 12, bottom: 20),
      child: Text("Ovexiq couldn't finish that request. Please try again."),
    );
  }
}

class _ImageWorkStatus extends StatelessWidget {
  const _ImageWorkStatus({required this.isWorking});

  final bool isWorking;

  @override
  Widget build(BuildContext context) {
    if (isWorking) {
      return const AppTypingIndicator(
        label: 'Ovexiq is creating your image...',
      );
    }

    return const Padding(
      padding: EdgeInsets.only(top: 12, bottom: 20),
      child: Text('Ovexiq couldn’t create that image. Please try again.'),
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
              'Tell Ovexiq your goal',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Describe what you want to accomplish. Ovexiq can help turn it '
              'into a structured workflow.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
