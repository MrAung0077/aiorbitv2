import 'dart:async';
import 'dart:typed_data';

import 'package:aiorbit/core/ai/ai.dart';
import 'package:aiorbit/core/ai/providers/ovexiq_image_api_client.dart';
import 'package:aiorbit/features/chat/ai_chat_screen.dart';
import 'package:aiorbit/features/chat/models/conversation.dart';
import 'package:aiorbit/features/chat/providers/chat_controller.dart';
import 'package:aiorbit/features/chat/providers/chat_image_generation_provider.dart';
import 'package:aiorbit/features/chat/repositories/conversation_repository.dart';
import 'package:aiorbit/features/chat/services/ai_chat_service.dart';
import 'package:aiorbit/features/chat/services/chat_image_generation_service.dart';
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
    'physical image prompt starts once, shows Working, and renders its result',
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
        'Create a peaceful picture of Buddha meditating under a bodhi tree.',
      );
      await tester.tap(find.byTooltip('Send'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Ovexiq is creating your image...'), findsOneWidget);
      expect(imageGenerator.prompts, <String>[
        'Buddha meditating under a bodhi tree',
      ]);
      expect(aiChatService.requests, isEmpty);
      expect(container.read(chatControllerProvider).imageActionRequest, isNull);

      await tester.pump();
      await tester.pump();
      expect(imageGenerator.prompts, hasLength(1));

      imageCompleter.complete(_testGeneratedImage());
      await tester.pumpAndSettle();

      expect(find.text('Done'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('generated-image-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('generated-image-preview')),
        findsOneWidget,
      );
      expect(find.text('Mission'), findsNothing);
      expect(find.text('Task 1'), findsNothing);
    },
  );

  testWidgets('an already-emitted image action starts when Chat attaches', (
    tester,
  ) async {
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
        missionRepositoryProvider.overrideWithValue(MemoryMissionRepository()),
        chatImageGenerationServiceProvider.overrideWithValue(imageGenerator),
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

    expect(find.text('Ovexiq is creating your image...'), findsOneWidget);
    expect(imageGenerator.prompts, <String>[
      'Buddha meditating under a bodhi tree',
    ]);

    imageCompleter.complete(_testGeneratedImage());
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('generated-image-card')),
      findsOneWidget,
    );
  });

  testWidgets(
    'image generation exception shows a friendly state instead of blank Chat',
    (tester) async {
      final imageCompleter = Completer<GeneratedImage>();
      final imageGenerator = _FakeChatImageGenerator(
        (_) => imageCompleter.future,
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

      expect(find.text('Ovexiq is creating your image...'), findsOneWidget);
      imageCompleter.completeError(StateError('raw provider error'));
      await tester.pumpAndSettle();

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

      await tester.enterText(find.byType(TextField), 'Build an app for me');
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

  testWidgets('a resolved clarification still reaches Working and Done', (
    tester,
  ) async {
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
    runMission = (_) {
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

    await tester.enterText(
      find.byType(TextField),
      'A 30-day content calendar about easy home cooking',
    );
    await tester.tap(find.byTooltip('Send'));
    await tester.pump(const Duration(seconds: 3));

    expect(container.read(chatControllerProvider).missionSuggestion, isNotNull);
    expect(runCount, 1);
    await tester.scrollUntilVisible(
      find.text('Ovexiq is working...'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Ovexiq is working...'), findsOneWidget);

    final mission = (await missionRepository.getAllMissions()).single;
    runCompleter.complete(_completedMission(mission));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('finished-result-card')),
      findsOneWidget,
    );
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

    await tester.enterText(find.byType(TextField), 'Build an app for me');
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

GeneratedImage _testGeneratedImage() {
  return GeneratedImage(
    mimeType: 'image/png',
    bytes: Uint8List.fromList(<int>[
      137,
      80,
      78,
      71,
      13,
      10,
      26,
      10,
      0,
      0,
      0,
      13,
      73,
      72,
      68,
      82,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      1,
      8,
      6,
      0,
      0,
      0,
      31,
      21,
      196,
      137,
      0,
      0,
      0,
      13,
      73,
      68,
      65,
      84,
      8,
      215,
      99,
      248,
      207,
      192,
      240,
      31,
      0,
      5,
      0,
      1,
      255,
      137,
      153,
      61,
      29,
      0,
      0,
      0,
      0,
      73,
      69,
      78,
      68,
      174,
      66,
      96,
      130,
    ]),
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
