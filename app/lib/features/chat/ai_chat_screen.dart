import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/providers/ovexiq_image_api_client.dart';
import '../../core/text/response_language.dart';
import '../../core/widgets/app_conversation_header.dart';
import '../../core/widgets/app_message_bubble.dart';
import '../../core/widgets/app_prompt_composer.dart';
import '../../core/widgets/app_typing_indicator.dart';
import 'models/brain_status.dart';
import 'models/artifact.dart';
import 'models/chat_message.dart';
import 'models/message_feedback.dart';
import 'models/router_decision.dart';
import 'providers/brain_provider.dart';
import 'providers/chat_controller.dart';
import 'providers/chat_image_generation_provider.dart';
import 'providers/chat_video_ingest_provider.dart';
import 'providers/device_image_save_provider.dart';
import 'services/router_preview_service.dart';
import 'services/chat_image_generation_service.dart';
import 'services/local_video_ingest_service.dart';
import 'widgets/brain_overlay.dart';
import 'widgets/finished_result_card.dart';
import 'widgets/generated_image_card.dart';
import 'widgets/video_attachment_card.dart';
import '../mission/providers/chat_mission_coordinator_provider.dart';
import '../mission/providers/mission_provider.dart';
import '../mission/services/chat_mission_coordinator.dart';
import '../mission/services/chat_mission_result_adapter.dart';
import '../mission/models/mission_suggestion.dart';
import '../mission/models/mission_status.dart';
import '../mission/models/task_status.dart';

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
  MissionSuggestion? _failedMissionSuggestion;
  ResponseLanguage _failedMissionResponseLanguage = ResponseLanguage.auto;
  ChatMissionResult? _finishedMissionResult;
  _ImageWorkState _imageWorkState = _ImageWorkState.idle;
  final Map<String, Uint8List> _imagePreviewBytes = <String, Uint8List>{};
  final Set<String> _startedImageRequestKeys = <String>{};
  final Set<String> _cancelledImageRequestKeys = <String>{};
  ChatImageGenerationOperation? _activeImageGeneration;
  String? _activeImageRequestKey;
  var _isVideoIngesting = false;
  String? _historyMissionConversationId;
  var _historyMissionResolved = false;

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
      _failedMissionSuggestion = null;
      _failedMissionResponseLanguage = ResponseLanguage.auto;
      _finishedMissionResult = null;
      _imageWorkState = _ImageWorkState.idle;
      _imagePreviewBytes.clear();
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

  Future<void> _attachVideo() async {
    if (_isVideoIngesting ||
        _imageWorkState == _ImageWorkState.working ||
        _missionWorkState == _MissionWorkState.working ||
        ref.read(chatControllerProvider).isSending) {
      return;
    }

    setState(() {
      _isVideoIngesting = true;
    });

    try {
      final selectedVideo = await ref.read(videoPickerProvider).pickOneVideo();
      if (selectedVideo == null) {
        return;
      }

      final controller = ref.read(chatControllerProvider.notifier);
      var conversation = ref.read(chatControllerProvider).conversation;
      if (conversation == null) {
        final created = await controller.createNewConversation();
        if (!created) {
          throw const VideoIngestException();
        }
        conversation = ref.read(chatControllerProvider).conversation;
      }
      if (conversation == null) {
        throw const VideoIngestException();
      }

      final createdAt = DateTime.now();
      final ingestId = 'video-${createdAt.microsecondsSinceEpoch}';
      final ingestedVideo = await ref
          .read(localVideoIngestServiceProvider)
          .ingest(
            conversationId: conversation.id,
            ingestId: ingestId,
            source: selectedVideo,
          );
      final artifact = Artifact(
        id: 'artifact-video-${conversation.id}-$ingestId',
        conversationId: conversation.id,
        type: ArtifactType.video,
        createdAt: createdAt,
      );
      final attachment = ChatAttachment(
        id: 'video-${conversation.id}-$ingestId',
        mimeType: ingestedVideo.mimeType,
        localFilePath: ingestedVideo.localPath,
        artifact: artifact,
        artifactVersion: ArtifactVersion(
          id: 'artifact-version-video-${conversation.id}-$ingestId',
          artifactId: artifact.id,
          mimeType: ingestedVideo.mimeType,
          localPath: ingestedVideo.localPath,
          fileName: ingestedVideo.fileName,
          byteSize: ingestedVideo.byteSize,
          createdAt: createdAt,
        ),
      );
      final persisted = await controller.persistVideoAttachment(
        conversationId: conversation.id,
        attachment: attachment,
      );
      if (!persisted) {
        throw const VideoIngestException();
      }
      _scrollToBottom();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text("Couldn't add that video")),
          );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isVideoIngesting = false;
        });
      }
    }
  }

  Future<void> _startSuggestedMissionIfNeeded(
    ChatState chatState, {
    MissionSuggestion? suggestionOverride,
  }) async {
    final suggestion = suggestionOverride ?? chatState.missionSuggestion;
    final conversationId = chatState.conversation?.id;

    if (suggestion == null ||
        conversationId == null ||
        _missionWorkState == _MissionWorkState.working) {
      return;
    }

    setState(() {
      _missionWorkState = _MissionWorkState.working;
      _failedMissionSuggestion = null;
      _failedMissionResponseLanguage = ResponseLanguage.auto;
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
        _failedMissionSuggestion = _missionWorkState == _MissionWorkState.failed
            ? suggestion
            : null;
        _failedMissionResponseLanguage =
            _missionWorkState == _MissionWorkState.failed
            ? responseLanguageFor(suggestion.goal)
            : ResponseLanguage.auto;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _missionWorkState = _MissionWorkState.failed;
          _failedMissionSuggestion = suggestion;
          _failedMissionResponseLanguage = responseLanguageFor(suggestion.goal);
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

    final requestId = request.requestId ?? messages.last.id;
    final sourceMessageId = request.sourceMessageId ?? messages.last.id;
    final requestKey = '$conversationId:$requestId';
    if (!_startedImageRequestKeys.add(requestKey)) {
      return;
    }

    setState(() {
      _imageWorkState = _ImageWorkState.working;
    });
    ref.read(chatControllerProvider.notifier).consumeImageActionRequest();

    final generation = ref
        .read(chatImageGenerationServiceProvider)
        .startGeneration(prompt: request.subject);
    _activeImageGeneration = generation;
    _activeImageRequestKey = requestKey;

    try {
      final image = await generation.result;
      if (!_isImageRequestActive(requestKey, generation)) {
        return;
      }

      final localFilePath = await ref
          .read(generatedImageResultStoreProvider)
          .savePng(
            conversationId: conversationId,
            sourceMessageId: requestId,
            bytes: image.bytes,
          );
      if (!_isImageRequestActive(requestKey, generation)) {
        return;
      }
      final versionCreatedAt = DateTime.now();
      final artifact = Artifact(
        id:
            request.artifactId ??
            'artifact-image-$conversationId-$sourceMessageId',
        conversationId: conversationId,
        type: ArtifactType.image,
        createdAt: request.artifactCreatedAt ?? versionCreatedAt,
      );
      final attachment = ChatAttachment(
        id: 'image-$conversationId-$requestId',
        mimeType: image.mimeType,
        localFilePath: localFilePath,
        sourcePrompt: request.subject,
        sourceMessageId: sourceMessageId,
        artifact: artifact,
        artifactVersion: ArtifactVersion(
          id: 'artifact-version-image-$conversationId-$requestId',
          artifactId: artifact.id,
          mimeType: image.mimeType,
          localPath: localFilePath,
          sourceArtifactVersionId: request.sourceArtifactVersionId,
          createdAt: versionCreatedAt,
        ),
      );
      final persisted = await ref
          .read(chatControllerProvider.notifier)
          .persistGeneratedImageResult(
            conversationId: conversationId,
            sourceMessageId: sourceMessageId,
            attachment: attachment,
            requestId: requestId,
          );

      if (!_isImageRequestActive(requestKey, generation)) {
        return;
      }

      if (!persisted) {
        throw StateError('Could not save the generated image result.');
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _imagePreviewBytes[attachment.id] = image.bytes;
        _imageWorkState = _ImageWorkState.idle;
      });
    } on OvexiqImageGenerationCancelled {
      // Cancellation returns to the existing result without a failure state.
    } catch (_) {
      if (_isImageRequestActive(requestKey, generation)) {
        setState(() {
          _imageWorkState = _ImageWorkState.failed;
        });
      }
    } finally {
      if (identical(_activeImageGeneration, generation)) {
        _activeImageGeneration = null;
        _activeImageRequestKey = null;
      }
      ref
          .read(chatControllerProvider.notifier)
          .finishImageGeneration(requestId: requestId);
    }
  }

  bool _isImageRequestActive(
    String requestKey,
    ChatImageGenerationOperation generation,
  ) {
    return mounted &&
        _activeImageRequestKey == requestKey &&
        identical(_activeImageGeneration, generation) &&
        !_cancelledImageRequestKeys.contains(requestKey);
  }

  void _cancelImageGeneration() {
    final generation = _activeImageGeneration;
    final requestKey = _activeImageRequestKey;
    final requestId = ref.read(chatControllerProvider).activeImageRequestId;

    if (generation == null ||
        requestKey == null ||
        requestId == null ||
        _imageWorkState != _ImageWorkState.working) {
      return;
    }

    _cancelledImageRequestKeys.add(requestKey);
    generation.cancel();
    ref
        .read(chatControllerProvider.notifier)
        .cancelImageGeneration(requestId: requestId);
    setState(() {
      _imageWorkState = _ImageWorkState.idle;
    });
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
    final conversationChanged =
        previous?.conversation?.id != next.conversation?.id;

    if (conversationChanged && next.conversation != null) {
      unawaited(_loadHistoryMissionState(next));
    }
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

  Future<void> _loadHistoryMissionState(ChatState chatState) async {
    final conversation = chatState.conversation;
    if (conversation == null) {
      return;
    }
    final conversationId = conversation.id;
    _historyMissionConversationId = conversationId;
    _historyMissionResolved = false;
    if (!ref.read(isarInitializedProvider)) {
      if (mounted && _historyMissionConversationId == conversationId) {
        setState(() => _historyMissionResolved = true);
      }
      return;
    }
    final mission = await ref
        .read(missionControllerProvider)
        .getMissionForConversation(conversationId);
    if (!mounted || _historyMissionConversationId != conversationId) {
      return;
    }
    setState(() {
      _historyMissionResolved = true;
      if (mission == null) {
        return;
      }
      if (mission.status == MissionStatus.completed ||
          mission.taskProgress.isComplete) {
        _finishedMissionResult = const ChatMissionResultAdapter().fromMission(
          mission,
        );
        return;
      }
      if (mission.status == MissionStatus.active &&
          mission.tasks.any((task) => task.status == TaskStatus.inProgress)) {
        _missionWorkState = _MissionWorkState.working;
        return;
      }
      _missionWorkState = _MissionWorkState.failed;
      _failedMissionSuggestion = MissionSuggestion(
        title: mission.title,
        goal: mission.goal,
        category: mission.category,
        reason: '',
        plannedSteps: mission.tasks
            .map((task) => task.title)
            .toList(growable: false),
      );
      _failedMissionResponseLanguage = responseLanguageFor(mission.goal);
    });
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
    final hasPersistedError = messages.isNotEmpty && messages.last.isError;
    final hasError = chatState.error != null && !hasPersistedError;
    final canRetryLastResponse =
        chatState.error?.canRetryLastResponse == true && !chatState.isSending;
    final isMissionWorking = _missionWorkState == _MissionWorkState.working;
    final hasMissionFailure = _missionWorkState == _MissionWorkState.failed;
    final finishedMissionResult = _finishedMissionResult;
    final isImageWorking = _imageWorkState == _ImageWorkState.working;
    final hasImageFailure = _imageWorkState == _ImageWorkState.failed;
    final hasImageStatus = isImageWorking || hasImageFailure;
    final hasWorkStatus =
        hasImageStatus ||
        isMissionWorking ||
        hasMissionFailure ||
        finishedMissionResult != null;
    final hasLegacyUnansweredRequest =
        !chatState.isSending &&
        !hasWorkStatus &&
        _historyMissionResolved &&
        messages.isNotEmpty &&
        messages.last.role == ChatRole.user;

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
                              (hasLegacyUnansweredRequest ? 1 : 0) +
                              (hasError ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index < messages.length) {
                              final message = messages[index];

                              if (message.attachment != null) {
                                if (message.attachment!.artifact?.type ==
                                    ArtifactType.video) {
                                  return VideoAttachmentCard(
                                    attachment: message.attachment!,
                                  );
                                }
                                return GeneratedImageCard(
                                  attachment: message.attachment!,
                                  previewBytes:
                                      _imagePreviewBytes[message
                                          .attachment!
                                          .id],
                                  onSaveImage: () => ref
                                      .read(deviceImageSaveServiceProvider)
                                      .savePng(
                                        localFilePath:
                                            message.attachment!.localFilePath,
                                      ),
                                  onRefineImage: () => ref
                                      .read(chatControllerProvider.notifier)
                                      .beginImageRevision(
                                        resultMessageId: message.id,
                                      ),
                                  onRegenerateImage: () => ref
                                      .read(chatControllerProvider.notifier)
                                      .regenerateImage(
                                        resultMessageId: message.id,
                                      ),
                                );
                              }

                              final isLastAssistantMessage =
                                  index == messages.length - 1 &&
                                  message.role == ChatRole.assistant &&
                                  !message.isError;
                              final isLastRetryableError =
                                  index == messages.length - 1 &&
                                  message.role == ChatRole.assistant &&
                                  message.isError &&
                                  !chatState.isSending &&
                                  canRetryLastResponse;

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
                                onRetry: isLastRetryableError
                                    ? () => ref
                                          .read(chatControllerProvider.notifier)
                                          .regenerateLastResponse()
                                    : null,
                              );
                            }

                            if (hasImageStatus && index == messages.length) {
                              return _ImageWorkStatus(
                                isWorking: isImageWorking,
                                onCancel: isImageWorking
                                    ? _cancelImageGeneration
                                    : null,
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
                                responseLanguage:
                                    _failedMissionResponseLanguage,
                                onCopy: hasMissionFailure
                                    ? () => _copyMessage(
                                        _missionFailureMessage(
                                          _failedMissionResponseLanguage,
                                        ),
                                      )
                                    : null,
                                onRetry:
                                    hasMissionFailure &&
                                        _failedMissionSuggestion != null &&
                                        !isMissionWorking
                                    ? () => _startSuggestedMissionIfNeeded(
                                        ref.read(chatControllerProvider),
                                        suggestionOverride:
                                            _failedMissionSuggestion,
                                      )
                                    : null,
                              );
                            }

                            if (chatState.isSending &&
                                messages.isEmpty &&
                                index == messages.length) {
                              return const AppTypingIndicator(
                                label: 'Ovexiq is preparing...',
                              );
                            }

                            if (hasLegacyUnansweredRequest &&
                                index == messages.length) {
                              final responseLanguage = responseLanguageFor(
                                messages.last.content,
                              );
                              final message = _legacyRecoveryMessage(
                                responseLanguage,
                              );
                              return AppMessageBubble(
                                key: const ValueKey<String>(
                                  'legacy-unanswered-error-card',
                                ),
                                message: ChatMessage(
                                  id: 'legacy-unanswered-error',
                                  role: ChatRole.assistant,
                                  content: message,
                                  createdAt: DateTime.now(),
                                  isError: true,
                                ),
                                onCopy: () => _copyMessage(message),
                                onRetry: () => ref
                                    .read(chatControllerProvider.notifier)
                                    .regenerateLastResponse(),
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
                        isImageWorking ||
                        _isVideoIngesting,
                    onSend: _sendMessage,
                    onAttach: _attachVideo,
                    inlineActions: true,
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

String _missionFailureMessage(ResponseLanguage responseLanguage) {
  return responseLanguage == ResponseLanguage.burmese
      ? 'Ovexiq က ဒီလုပ်ငန်းကို အပြီးမလုပ်ဆောင်နိုင်သေးပါ။ ထပ်စမ်းကြည့်ပါ။'
      : "Ovexiq couldn't finish this task. Please try again.";
}

String _legacyRecoveryMessage(ResponseLanguage responseLanguage) {
  return responseLanguage == ResponseLanguage.burmese
      ? 'ဒီမေးခွန်းအတွက် အဖြေကို မသိမ်းထားနိုင်ခဲ့ပါ။ ထပ်စမ်းကြည့်ပါ။'
      : 'This question does not have a saved answer. Please try again.';
}

enum _MissionWorkState { idle, working, failed }

enum _ImageWorkState { idle, working, failed }

class _MissionWorkStatus extends StatelessWidget {
  const _MissionWorkStatus({
    required this.isWorking,
    required this.responseLanguage,
    this.onCopy,
    this.onRetry,
  });

  final bool isWorking;
  final ResponseLanguage responseLanguage;
  final VoidCallback? onCopy;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (isWorking) {
      return const AppTypingIndicator(label: 'Ovexiq is working...');
    }

    final message = _missionFailureMessage(responseLanguage);
    return AppMessageBubble(
      key: const ValueKey<String>('mission-error-card'),
      message: ChatMessage(
        id: 'mission-error',
        role: ChatRole.assistant,
        content: message,
        createdAt: DateTime.now(),
        isError: true,
      ),
      onCopy: onCopy,
      onRetry: onRetry,
    );
  }
}

class _ImageWorkStatus extends StatelessWidget {
  const _ImageWorkStatus({required this.isWorking, this.onCancel});

  final bool isWorking;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    if (isWorking) {
      return Row(
        children: <Widget>[
          const Expanded(
            child: AppTypingIndicator(
              label: 'Ovexiq is creating your image...',
            ),
          ),
          TextButton(
            key: const ValueKey<String>('cancel-image-generation-button'),
            onPressed: onCancel,
            child: const Text('Cancel'),
          ),
        ],
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
