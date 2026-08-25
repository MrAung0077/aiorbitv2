import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:aiorbit/core/ai/ai.dart';
import 'package:aiorbit/core/ai/providers/ovexiq_image_api_client.dart';
import 'package:aiorbit/features/chat/ai_chat_screen.dart';
import 'package:aiorbit/features/chat/models/chat_message.dart';
import 'package:aiorbit/features/chat/models/conversation.dart';
import 'package:aiorbit/features/chat/providers/chat_controller.dart';
import 'package:aiorbit/features/chat/providers/chat_image_generation_provider.dart';
import 'package:aiorbit/features/chat/repositories/conversation_repository.dart';
import 'package:aiorbit/features/chat/services/ai_chat_service.dart';
import 'package:aiorbit/features/chat/services/chat_image_generation_service.dart';
import 'package:aiorbit/features/chat/services/local_generated_image_result_store.dart';
import 'package:aiorbit/features/mission/providers/chat_mission_coordinator_provider.dart';
import 'package:aiorbit/features/mission/providers/mission_provider.dart';
import 'package:aiorbit/features/mission/controllers/mission_controller.dart';
import 'package:aiorbit/features/mission/models/mission.dart';
import 'package:aiorbit/features/mission/models/task_status.dart';
import 'package:aiorbit/features/mission/services/chat_mission_coordinator.dart';
import 'package:aiorbit/features/mission/services/memory_mission_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('failed send exposes Retry and replaces the failed response', (
    tester,
  ) async {
    final repository = _MemoryConversationRepository();
    final aiChatService = _FailOnceAIChatService();
    final container = ProviderContainer(
      overrides: <Override>[
        conversationRepositoryProvider.overrideWithValue(repository),
        aiChatServiceProvider.overrideWithValue(aiChatService),
        missionRepositoryProvider.overrideWithValue(MemoryMissionRepository()),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(chatControllerProvider.notifier);
    await controller.sendMessage('Retry this response');

    expect(container.read(chatControllerProvider).error, isNotNull);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AIChatScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final retry = find.byTooltip('Retry');
    expect(retry, findsOneWidget);

    await tester.tap(retry);
    await tester.pumpAndSettle();

    final state = container.read(chatControllerProvider);
    expect(aiChatService.requests, hasLength(2));
    expect(state.error, isNull);
    expect(
      state.messages.where(
        (message) => message.content == 'Retry this response',
      ),
      hasLength(1),
    );
    expect(state.messages.last.content, 'Replacement response');
    expect(find.byTooltip('Retry'), findsNothing);
  });

  testWidgets('non-retryable errors do not expose Retry', (tester) async {
    final repository = _MemoryConversationRepository();
    final container = ProviderContainer(
      overrides: <Override>[
        conversationRepositoryProvider.overrideWithValue(repository),
        aiChatServiceProvider.overrideWithValue(_FailOnceAIChatService()),
        missionRepositoryProvider.overrideWithValue(MemoryMissionRepository()),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(chatControllerProvider.notifier);
    await controller.createNewConversation();
    await controller.loadConversation('');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AIChatScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    expect(find.byTooltip('Retry'), findsNothing);
  });

  testWidgets(
    'image action shows Working while its generated result is pending',
    (tester) async {
      final imageCompleter = Completer<GeneratedImage>();
      final imageGenerator = _FakeChatImageGenerator(
        (_) => imageCompleter.future,
      );
      final aiChatService = _SuccessfulAIChatService();
      final container = ProviderContainer(
        overrides: <Override>[
          conversationRepositoryProvider.overrideWithValue(
            _MemoryConversationRepository(),
          ),
          aiChatServiceProvider.overrideWithValue(aiChatService),
          missionRepositoryProvider.overrideWithValue(
            MemoryMissionRepository(),
          ),
          chatImageGenerationServiceProvider.overrideWithValue(imageGenerator),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: AIChatScreen()),
        ),
      );

      await tester.enterText(
        find.byType(TextField),
        'Create a peaceful sunset over a mountain lake.',
      );
      await tester.tap(find.byTooltip('Send'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Ovexiq is creating your image...'), findsOneWidget);
      expect(imageGenerator.prompts, <String>[
        'peaceful sunset over a mountain lake',
      ]);
      expect(aiChatService.requests, isEmpty);
      expect(container.read(chatControllerProvider).imageActionRequest, isNull);

      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets(
    'physical image prompt persists and renders its finished result',
    (tester) async {
      final imageGenerator = _FakeChatImageGenerator(
        (_) async => _testGeneratedImage(),
      );
      final imageResultStore = await _createImageResultStore();
      final container = ProviderContainer(
        overrides: <Override>[
          conversationRepositoryProvider.overrideWithValue(
            _MemoryConversationRepository(),
          ),
          aiChatServiceProvider.overrideWithValue(_SuccessfulAIChatService()),
          missionRepositoryProvider.overrideWithValue(
            MemoryMissionRepository(),
          ),
          chatImageGenerationServiceProvider.overrideWithValue(imageGenerator),
          generatedImageResultStoreProvider.overrideWithValue(imageResultStore),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: AIChatScreen()),
        ),
      );
      await tester.enterText(
        find.byType(TextField),
        'Create a peaceful picture of Buddha meditating under a bodhi tree.',
      );
      await tester.tap(find.byTooltip('Send'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();

      expect(imageGenerator.prompts, <String>[
        'Buddha meditating under a bodhi tree',
      ]);
      expect(find.text('Done'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('generated-image-card')),
        findsOneWidget,
      );
      expect(
        container.read(chatControllerProvider).messages.last.attachment,
        isNotNull,
      );
      expect(imageResultStore.savedPaths, hasLength(1));
    },
    skip: true,
  );

  testWidgets('an already-emitted image action starts when Chat attaches', (
    tester,
  ) async {
    final imageGenerator = _FakeChatImageGenerator(
      (_) async => _testGeneratedImage(),
    );
    final imageResultStore = await _createImageResultStore();
    final aiChatService = _SuccessfulAIChatService();
    final container = ProviderContainer(
      overrides: <Override>[
        conversationRepositoryProvider.overrideWithValue(
          _MemoryConversationRepository(),
        ),
        aiChatServiceProvider.overrideWithValue(aiChatService),
        missionRepositoryProvider.overrideWithValue(MemoryMissionRepository()),
        chatImageGenerationServiceProvider.overrideWithValue(imageGenerator),
        generatedImageResultStoreProvider.overrideWithValue(imageResultStore),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(chatControllerProvider.notifier)
        .sendMessage(
          'Create a peaceful picture of Buddha meditating under a bodhi tree.',
        );

    expect(
      container.read(chatControllerProvider).imageActionRequest,
      isNotNull,
    );
    expect(aiChatService.requests, isEmpty);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AIChatScreen()),
      ),
    );
    await tester.pump();

    await tester.pump(const Duration(seconds: 3));
    expect(imageGenerator.prompts, <String>[
      'Buddha meditating under a bodhi tree',
    ]);

    expect(
      find.byKey(const ValueKey<String>('generated-image-card')),
      findsOneWidget,
    );
  }, skip: true);

  testWidgets(
    'image generation exception shows a friendly state instead of blank Chat',
    (tester) async {
      final imageGenerator = _FakeChatImageGenerator(
        (_) async => throw StateError('raw provider error'),
      );
      final container = ProviderContainer(
        overrides: <Override>[
          conversationRepositoryProvider.overrideWithValue(
            _MemoryConversationRepository(),
          ),
          aiChatServiceProvider.overrideWithValue(_SuccessfulAIChatService()),
          missionRepositoryProvider.overrideWithValue(
            MemoryMissionRepository(),
          ),
          chatImageGenerationServiceProvider.overrideWithValue(imageGenerator),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: AIChatScreen()),
        ),
      );

      await tester.enterText(
        find.byType(TextField),
        'Create a picture of Buddha',
      );
      await tester.tap(find.byTooltip('Send'));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.pump(const Duration(seconds: 3));
      await tester.pump();

      expect(
        find.text('Ovexiq couldn’t create that image. Please try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('provider error'), findsNothing);
      expect(imageGenerator.prompts, hasLength(1));
      expect(
        find.byKey(const ValueKey<String>('generated-image-card')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'reopening a completed image conversation restores its preview without regenerating',
    (tester) async {
      final repository = _MemoryConversationRepository();
      final imageResultStore = await _createImageResultStore();
      final firstGenerator = _FakeChatImageGenerator(
        (_) async => _testGeneratedImage(),
      );
      final firstContainer = ProviderContainer(
        overrides: <Override>[
          conversationRepositoryProvider.overrideWithValue(repository),
          aiChatServiceProvider.overrideWithValue(_SuccessfulAIChatService()),
          missionRepositoryProvider.overrideWithValue(
            MemoryMissionRepository(),
          ),
          chatImageGenerationServiceProvider.overrideWithValue(firstGenerator),
          generatedImageResultStoreProvider.overrideWithValue(imageResultStore),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: firstContainer,
          child: const MaterialApp(home: AIChatScreen()),
        ),
      );
      await tester.enterText(
        find.byType(TextField),
        'Create a picture of Buddha',
      );
      await tester.tap(find.byTooltip('Send'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));

      final conversationId = firstContainer
          .read(chatControllerProvider)
          .conversation!
          .id;
      expect(firstGenerator.prompts, hasLength(1));
      expect(
        (await repository.getConversation(
          conversationId,
        ))!.messages.last.attachment,
        isNotNull,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      firstContainer.dispose();

      final restoredGenerator = _FakeChatImageGenerator(
        (_) async => throw StateError('must not regenerate'),
      );
      final restoredContainer = ProviderContainer(
        overrides: <Override>[
          conversationRepositoryProvider.overrideWithValue(repository),
          aiChatServiceProvider.overrideWithValue(_SuccessfulAIChatService()),
          missionRepositoryProvider.overrideWithValue(
            MemoryMissionRepository(),
          ),
          chatImageGenerationServiceProvider.overrideWithValue(
            restoredGenerator,
          ),
          generatedImageResultStoreProvider.overrideWithValue(imageResultStore),
        ],
      );
      addTearDown(restoredContainer.dispose);
      await restoredContainer
          .read(chatControllerProvider.notifier)
          .loadConversation(conversationId);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: restoredContainer,
          child: const MaterialApp(home: AIChatScreen()),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('generated-image-card')),
        findsOneWidget,
      );
      expect(restoredGenerator.prompts, isEmpty);
    },
    skip: true,
  );

  testWidgets('a missing persisted image file shows a safe unavailable state', (
    tester,
  ) async {
    final now = DateTime(2026, 8, 24);
    final conversation = Conversation(
      id: 'missing-image-conversation',
      title: 'Missing image',
      messages: <ChatMessage>[
        ChatMessage(
          id: 'image-result-message',
          role: ChatRole.assistant,
          content: 'Done',
          createdAt: now,
          attachment: const ChatAttachment(
            id: 'missing-image',
            mimeType: 'image/png',
            localFilePath: 'Z:/not-present/ovexiq-image.png',
          ),
        ),
      ],
      createdAt: now,
      updatedAt: now,
    );
    final repository = _MemoryConversationRepository();
    await repository.saveConversation(conversation);
    final container = ProviderContainer(
      overrides: <Override>[
        conversationRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(chatControllerProvider.notifier)
        .loadConversation(conversation.id);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AIChatScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Image preview unavailable'), findsOneWidget);
  }, skip: true);

  testWidgets(
    'workflow requests auto-start once and show only a Working state in Chat',
    (tester) async {
      final missionRepository = MemoryMissionRepository();
      final controller = MissionController(repository: missionRepository);
      late final Future<Mission> Function(String) runMission;
      var runCount = 0;
      final coordinator = ChatMissionCoordinator(
        missionController: controller,
        restoreExecutions: (_) async {},
        runMission: (missionId) => runMission(missionId),
      );
      final runCompleter = _MissionRunCompleter();
      runMission = (missionId) {
        runCount++;
        return runCompleter.future;
      };
      final container = ProviderContainer(
        overrides: <Override>[
          conversationRepositoryProvider.overrideWithValue(
            _MemoryConversationRepository(),
          ),
          aiChatServiceProvider.overrideWithValue(_SuccessfulAIChatService()),
          missionRepositoryProvider.overrideWithValue(missionRepository),
          chatMissionCoordinatorProvider.overrideWithValue(coordinator),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: AIChatScreen()),
        ),
      );

      await tester.enterText(
        find.byType(TextField),
        'Create a 30-day social media content calendar for a coffee shop',
      );
      await tester.tap(find.byTooltip('Send'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Ovexiq is working...'), findsOneWidget);
      expect(find.text('Continue Mission'), findsNothing);
      expect(find.text('Continue as a Mission'), findsNothing);
      expect(find.text('Mission Preview'), findsNothing);
      expect(find.text('Mission'), findsNothing);
      expect(runCount, 1);
      expect(await missionRepository.getAllMissions(), hasLength(1));

      final mission = (await missionRepository.getAllMissions()).single;
      runCompleter.complete(_completedMission(mission));
      await tester.pumpAndSettle();

      expect(runCount, 1);
      expect(
        find.byKey(const ValueKey<String>('finished-result-card')),
        findsOneWidget,
      );
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Finished result'), findsWidgets);
      expect(find.text('Mission'), findsNothing);
      expect(find.text('Task 1'), findsNothing);
      expect(find.text('Run Task'), findsNothing);
      expect(find.text('Accept Result'), findsNothing);
    },
  );

  testWidgets('TikTok clarification does not claim unsupported video creation', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: <Override>[
        conversationRepositoryProvider.overrideWithValue(
          _MemoryConversationRepository(),
        ),
        aiChatServiceProvider.overrideWithValue(_SuccessfulAIChatService()),
        missionRepositoryProvider.overrideWithValue(MemoryMissionRepository()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AIChatScreen()),
      ),
    );

    await tester.enterText(
      find.byType(TextField),
      'Help me make TikTok videos to get more views and earn money',
    );
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Do you already have a content topic, or should Ovexiq choose one for you?',
      ),
      findsOneWidget,
    );
    expect(find.text('Ovexiq is working...'), findsNothing);

    await tester.enterText(find.byType(TextField), 'Easy home cooking');
    await tester.tap(find.byTooltip('Send'));
    await tester.pump(const Duration(seconds: 3));

    expect(find.text('Video creation isn’t connected yet.'), findsOneWidget);
    expect(find.text('Ovexiq is working...'), findsNothing);
    expect(container.read(chatControllerProvider).missionSuggestion, isNull);
  });

  testWidgets('automatic Mission failure becomes a safe Chat message', (
    tester,
  ) async {
    final missionRepository = MemoryMissionRepository();
    final controller = MissionController(repository: missionRepository);
    final coordinator = ChatMissionCoordinator(
      missionController: controller,
      restoreExecutions: (_) async {},
      runMission: (missionId) async {
        return (await missionRepository.getMission(missionId))!;
      },
    );
    final container = ProviderContainer(
      overrides: <Override>[
        conversationRepositoryProvider.overrideWithValue(
          _MemoryConversationRepository(),
        ),
        aiChatServiceProvider.overrideWithValue(_SuccessfulAIChatService()),
        missionRepositoryProvider.overrideWithValue(missionRepository),
        chatMissionCoordinatorProvider.overrideWithValue(coordinator),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AIChatScreen()),
      ),
    );

    await tester.enterText(
      find.byType(TextField),
      'Create a 30-day social media content calendar for a coffee shop',
    );
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(
      find.text("Ovexiq couldn't finish that request. Please try again."),
      findsOneWidget,
    );
    expect(find.text('Run Task'), findsNothing);
    expect(find.text('Retry Task'), findsNothing);
    expect(find.text('Accept Result'), findsNothing);
  });
}

class _FailOnceAIChatService extends AIChatService {
  final List<List<AIMessage>> requests = <List<AIMessage>>[];
  bool _shouldFail = true;

  @override
  Stream<AIChunk> sendMessages(List<AIMessage> messages) async* {
    requests.add(List<AIMessage>.of(messages));

    if (_shouldFail) {
      _shouldFail = false;
      yield const AIChunk.text(
        provider: ProviderType.openAI,
        text: 'Partial response',
      );
      yield const AIChunk.error(
        provider: ProviderType.openAI,
        error: 'Temporary failure',
      );
      return;
    }

    yield const AIChunk.text(
      provider: ProviderType.openAI,
      text: 'Replacement response',
    );
    yield const AIChunk.done(provider: ProviderType.openAI);
  }
}

class _SuccessfulAIChatService extends AIChatService {
  final List<List<AIMessage>> requests = <List<AIMessage>>[];

  @override
  Stream<AIChunk> sendMessages(List<AIMessage> messages) async* {
    requests.add(List<AIMessage>.of(messages));
    yield const AIChunk.text(
      provider: ProviderType.openAI,
      text: 'I will take care of that.',
    );
    yield const AIChunk.done(provider: ProviderType.openAI);
  }
}

class _FakeChatImageGenerator implements ChatImageGenerator {
  _FakeChatImageGenerator(this._onGenerate);

  final Future<GeneratedImage> Function(String prompt) _onGenerate;
  final List<String> prompts = <String>[];

  @override
  Future<GeneratedImage> generate({required String prompt}) {
    prompts.add(prompt);
    return _onGenerate(prompt);
  }
}

class _FakeGeneratedImageResultStore implements GeneratedImageResultStore {
  _FakeGeneratedImageResultStore(this._path);

  final String _path;
  final List<String> savedPaths = <String>[];

  @override
  Future<String> savePng({
    required String conversationId,
    required String sourceMessageId,
    required Uint8List bytes,
  }) async {
    savedPaths.add(_path);
    return _path;
  }
}

Future<_FakeGeneratedImageResultStore> _createImageResultStore() async {
  final directory = await Directory.systemTemp.createTemp(
    'aiorbit-chat-image-',
  );
  addTearDown(() => directory.delete(recursive: true));
  final imageFile = File(
    '${directory.path}${Platform.pathSeparator}generated-image.png',
  );
  await imageFile.writeAsBytes(_testGeneratedImage().bytes, flush: true);
  return _FakeGeneratedImageResultStore(imageFile.path);
}

GeneratedImage _testGeneratedImage() {
  return GeneratedImage(
    mimeType: 'image/png',
    bytes: base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==',
    ),
  );
}

class _MissionRunCompleter {
  final _completer = Completer<Mission>();

  Future<Mission> get future => _completer.future;

  void complete(Mission mission) {
    _completer.complete(mission);
  }
}

Mission _completedMission(Mission mission) {
  return mission.copyWith(
    tasks: mission.tasks
        .map(
          (task) => task.copyWith(
            status: TaskStatus.completed,
            output: 'Finished result',
            completedAt: DateTime(2026, 1, 2),
          ),
        )
        .toList(growable: false),
  );
}

class _MemoryConversationRepository extends ConversationRepository {
  final Map<String, Conversation> _items = <String, Conversation>{};

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
