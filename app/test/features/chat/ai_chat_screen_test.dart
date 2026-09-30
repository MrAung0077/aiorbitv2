import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:aiorbit/core/ai/ai.dart';
import 'package:aiorbit/core/ai/providers/ovexiq_image_api_client.dart';
import 'package:aiorbit/features/chat/ai_chat_screen.dart';
import 'package:aiorbit/features/chat/models/artifact.dart';
import 'package:aiorbit/features/chat/models/chat_message.dart';
import 'package:aiorbit/features/chat/models/conversation.dart';
import 'package:aiorbit/features/chat/providers/chat_controller.dart';
import 'package:aiorbit/features/chat/providers/chat_image_generation_provider.dart';
import 'package:aiorbit/features/chat/providers/chat_video_ingest_provider.dart';
import 'package:aiorbit/features/chat/repositories/conversation_repository.dart';
import 'package:aiorbit/features/chat/services/ai_chat_service.dart';
import 'package:aiorbit/features/chat/services/chat_image_generation_service.dart';
import 'package:aiorbit/features/chat/services/local_generated_image_result_store.dart';
import 'package:aiorbit/features/chat/services/local_video_ingest_service.dart';
import 'package:aiorbit/features/chat/services/video_picker.dart';
import 'package:aiorbit/features/mission/providers/chat_mission_coordinator_provider.dart';
import 'package:aiorbit/features/mission/providers/mission_provider.dart';
import 'package:aiorbit/features/mission/controllers/mission_controller.dart';
import 'package:aiorbit/features/mission/models/mission.dart';
import 'package:aiorbit/features/mission/models/mission_category.dart';
import 'package:aiorbit/features/mission/models/mission_status.dart';
import 'package:aiorbit/features/mission/models/mission_suggestion.dart';
import 'package:aiorbit/features/mission/models/mission_task.dart';
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

  testWidgets('stopping chat ignores a late failure without a Retry card', (
    tester,
  ) async {
    final repository = _MemoryConversationRepository();
    final aiChatService = _LateFailureAIChatService();
    final container = ProviderContainer(
      overrides: <Override>[
        conversationRepositoryProvider.overrideWithValue(repository),
        aiChatServiceProvider.overrideWithValue(aiChatService),
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
      'What is one useful writing habit?',
    );
    await tester.tap(find.byTooltip('Send'));
    await aiChatService.started.future;
    await tester.pump();

    await tester.tap(find.text('Stop'));
    await tester.pump();
    expect(find.text('Stopped.'), findsOneWidget);

    aiChatService.failLate();
    await tester.pumpAndSettle();

    expect(find.text('Stopped.'), findsOneWidget);
    expect(find.byTooltip('Retry'), findsNothing);
    expect(
      find.text("Ovexiq couldn't finish that request. Please try again."),
      findsNothing,
    );
  });

  testWidgets(
    'short follow-up after stopping Chat reuses the original request without a duplicate bubble',
    (tester) async {
      for (final followUp in <String>['ပြန်ရေး', 'ပြန်လုပ်', 'retry', 'continue']) {
        final repository = _MemoryConversationRepository();
        final aiChatService = _StoppedChatRetryAIChatService();
        final container = ProviderContainer(
          overrides: <Override>[
            conversationRepositoryProvider.overrideWithValue(repository),
            aiChatServiceProvider.overrideWithValue(aiChatService),
            missionRepositoryProvider.overrideWithValue(
              MemoryMissionRepository(),
            ),
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: AIChatScreen()),
          ),
        );
        await tester.enterText(
          find.byType(TextField),
          'Write a short welcome message.',
        );
        await tester.tap(find.byTooltip('Send'));
        await aiChatService.firstRequestStarted.future;
        await tester.pump();

        await tester.tap(find.text('Stop'));
        await tester.pump();
        await tester.enterText(find.byType(TextField), followUp);
        await tester.tap(find.byTooltip('Send'));
        await aiChatService.retryRequestStarted.future;
        aiChatService.failCancelledRequestLate();
        aiChatService.succeedRetry();
        await tester.pumpAndSettle();

        expect(aiChatService.requests, hasLength(2));
        expect(
          aiChatService.requests.last.map((message) => message.content),
          orderedEquals(<String>['Write a short welcome message.']),
        );
        expect(
          container
              .read(chatControllerProvider)
              .messages
              .where((message) => message.role == ChatRole.user),
          hasLength(1),
        );
        expect(
          container
              .read(chatControllerProvider)
              .messages
              .where((message) => message.content == followUp),
          isEmpty,
        );
        expect(find.text('Retried answer'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      }
    },
  );

  testWidgets('detailed follow-up after stopping Chat remains a new request', (
    tester,
  ) async {
    final repository = _MemoryConversationRepository();
    final aiChatService = _StoppedChatRetryAIChatService();
    final container = ProviderContainer(
      overrides: <Override>[
        conversationRepositoryProvider.overrideWithValue(repository),
        aiChatServiceProvider.overrideWithValue(aiChatService),
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
    await tester.enterText(find.byType(TextField), 'Write a short welcome message.');
    await tester.tap(find.byTooltip('Send'));
    await aiChatService.firstRequestStarted.future;
    await tester.pump();
    await tester.tap(find.text('Stop'));
    await tester.pump();
    const detailedFollowUp =
        'Continue, but write a different message for a new audience.';
    await tester.enterText(find.byType(TextField), detailedFollowUp);
    await tester.tap(find.byTooltip('Send'));
    await aiChatService.retryRequestStarted.future;
    aiChatService.failCancelledRequestLate();
    aiChatService.succeedRetry();
    await tester.pumpAndSettle();

    expect(aiChatService.requests, hasLength(2));
    expect(
      aiChatService.requests.last.map((message) => message.content),
      orderedEquals(<String>[
        'Write a short welcome message.',
        detailedFollowUp,
      ]),
    );
    expect(
      container
          .read(chatControllerProvider)
          .messages
          .where((message) => message.role == ChatRole.user),
      hasLength(2),
    );
  });

  testWidgets('rate-limited Burmese chat waits without an immediate Retry', (
    tester,
  ) async {
    final repository = _MemoryConversationRepository();
    final container = ProviderContainer(
      overrides: <Override>[
        conversationRepositoryProvider.overrideWithValue(repository),
        aiChatServiceProvider.overrideWithValue(_RateLimitedAIChatService()),
        missionRepositoryProvider.overrideWithValue(MemoryMissionRepository()),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(chatControllerProvider.notifier);
    await controller.sendMessage('Facebook အတွက် post တစ်ခုရေးပေးပါ။');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AIChatScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ခဏလောက်စောင့်ပြီး ပြန်စမ်းပေးပါ။'), findsOneWidget);
    expect(find.byTooltip('Retry'), findsNothing);
    controller.dispose();
  });

  testWidgets(
    'legacy unanswered history exposes a manual Retry without auto-execution',
    (tester) async {
      final repository = _MemoryConversationRepository();
      final service = _SuccessfulAIChatService();
      final createdAt = DateTime(2026, 9, 24, 9);
      await repository.saveConversation(
        Conversation(
          id: 'legacy-unanswered',
          title: 'Legacy question',
          messages: <ChatMessage>[
            ChatMessage(
              id: 'legacy-user',
              role: ChatRole.user,
              content: 'ကျောက်စိမ်းအကြောင်း သိလား',
              createdAt: createdAt,
            ),
          ],
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );
      final container = ProviderContainer(
        overrides: <Override>[
          conversationRepositoryProvider.overrideWithValue(repository),
          aiChatServiceProvider.overrideWithValue(service),
          missionRepositoryProvider.overrideWithValue(
            MemoryMissionRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(chatControllerProvider.notifier)
          .loadConversation('legacy-unanswered');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: AIChatScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(service.requests, isEmpty);
      expect(
        find.byKey(const ValueKey<String>('legacy-unanswered-error-card')),
        findsOneWidget,
      );
      expect(find.byTooltip('Retry'), findsOneWidget);

      await tester.tap(find.byTooltip('Retry'));
      await tester.pumpAndSettle();

      expect(service.requests, hasLength(1));
      expect(
        service.requests.single.map((message) => message.content),
        orderedEquals(<String>['ကျောက်စိမ်းအကြောင်း သိလား']),
      );
      expect(
        container
            .read(chatControllerProvider)
            .messages
            .where((message) => message.role == ChatRole.user),
        hasLength(1),
      );
    },
  );

  testWidgets('reopening a completed Mission only renders its saved result', (
    tester,
  ) async {
    final conversationRepository = _MemoryConversationRepository();
    final missionRepository = MemoryMissionRepository();
    final missionController = MissionController(repository: missionRepository);
    final createdAt = DateTime(2026, 9, 24, 9);
    const conversationId = 'completed-mission-history';
    final mission = await missionController.startMission(
      const MissionSuggestion(
        title: 'Coffee shop plan',
        goal: 'Create a plan for a coffee shop',
        category: MissionCategory.marketing,
        reason: 'Saved Mission',
        plannedSteps: <String>['Plan'],
      ),
      conversationId: conversationId,
    );
    await missionRepository.saveMission(_completedMission(mission));
    await conversationRepository.saveConversation(
      Conversation(
        id: conversationId,
        title: 'Coffee shop plan',
        messages: <ChatMessage>[
          ChatMessage(
            id: 'mission-user',
            role: ChatRole.user,
            content: 'Create a plan for a coffee shop',
            createdAt: createdAt,
          ),
        ],
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
    );
    final service = _SuccessfulAIChatService();
    final container = ProviderContainer(
      overrides: <Override>[
        conversationRepositoryProvider.overrideWithValue(
          conversationRepository,
        ),
        aiChatServiceProvider.overrideWithValue(service),
        missionRepositoryProvider.overrideWithValue(missionRepository),
        isarInitializedProvider.overrideWithValue(true),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(chatControllerProvider.notifier)
        .loadConversation(conversationId);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AIChatScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(service.requests, isEmpty);
    expect(
      find.byKey(const ValueKey<String>('finished-result-card')),
      findsOneWidget,
    );
    expect(find.text('Result Pack ready'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('legacy-unanswered-error-card')),
      findsNothing,
    );
  });

  testWidgets('reopening partial Mission history waits for explicit Retry', (
    tester,
  ) async {
    final conversationRepository = _MemoryConversationRepository();
    final missionRepository = MemoryMissionRepository();
    final missionController = MissionController(repository: missionRepository);
    const conversationId = 'partial-mission-history';
    final mission = await missionController.startMission(
      const MissionSuggestion(
        title: 'Coffee shop plan',
        goal: 'Create a plan for a coffee shop',
        category: MissionCategory.marketing,
        reason: 'Saved Mission',
        plannedSteps: <String>['Audience', 'Posts'],
      ),
      conversationId: conversationId,
    );
    final partialMission = mission.copyWith(
      tasks: <MissionTask>[
        mission.tasks.first.copyWith(
          status: TaskStatus.completed,
          output: 'Saved audience output',
          completedAt: DateTime(2026, 9, 24, 9),
        ),
        mission.tasks.last,
      ],
    );
    await missionRepository.saveMission(partialMission);
    await conversationRepository.saveConversation(
      _conversationWithFinalUserMessage(conversationId),
    );
    var runCount = 0;
    final coordinator = ChatMissionCoordinator(
      missionController: missionController,
      restoreExecutions: (_) async {},
      runMission: (missionId) async {
        runCount++;
        return (await missionRepository.getMission(missionId))!;
      },
    );
    final container = ProviderContainer(
      overrides: <Override>[
        conversationRepositoryProvider.overrideWithValue(
          conversationRepository,
        ),
        aiChatServiceProvider.overrideWithValue(_SuccessfulAIChatService()),
        missionRepositoryProvider.overrideWithValue(missionRepository),
        chatMissionCoordinatorProvider.overrideWithValue(coordinator),
        isarInitializedProvider.overrideWithValue(true),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(chatControllerProvider.notifier)
        .loadConversation(conversationId);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AIChatScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(runCount, 0);
    expect(
      find.byKey(const ValueKey<String>('mission-error-card')),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Retry'));
    await tester.pumpAndSettle();

    expect(runCount, 1);
    final preservedMission = (await missionRepository.getMission(mission.id))!;
    expect(preservedMission.tasks.first.status, TaskStatus.completed);
    expect(preservedMission.tasks.first.output, 'Saved audience output');
  });

  testWidgets('reopening a cancelled Mission never resumes it automatically', (
    tester,
  ) async {
    final conversationRepository = _MemoryConversationRepository();
    final missionRepository = MemoryMissionRepository();
    final missionController = MissionController(repository: missionRepository);
    const conversationId = 'cancelled-mission-history';
    final mission = await missionController.startMission(
      const MissionSuggestion(
        title: 'Coffee shop plan',
        goal: 'Create a plan for a coffee shop',
        category: MissionCategory.marketing,
        reason: 'Saved Mission',
        plannedSteps: <String>['Audience', 'Posts'],
      ),
      conversationId: conversationId,
    );
    final cancelledMission = mission.copyWith(
      status: MissionStatus.cancelled,
      tasks: <MissionTask>[
        mission.tasks.first.copyWith(
          status: TaskStatus.completed,
          output: 'Saved audience output',
          completedAt: DateTime(2026, 9, 24, 9),
        ),
        mission.tasks.last,
      ],
    );
    await missionRepository.saveMission(cancelledMission);
    await conversationRepository.saveConversation(
      _conversationWithFinalUserMessage(conversationId),
    );
    var runCount = 0;
    final coordinator = ChatMissionCoordinator(
      missionController: missionController,
      restoreExecutions: (_) async {},
      runMission: (missionId) async {
        runCount++;
        return (await missionRepository.getMission(missionId))!;
      },
    );
    final container = ProviderContainer(
      overrides: <Override>[
        conversationRepositoryProvider.overrideWithValue(
          conversationRepository,
        ),
        aiChatServiceProvider.overrideWithValue(_SuccessfulAIChatService()),
        missionRepositoryProvider.overrideWithValue(missionRepository),
        chatMissionCoordinatorProvider.overrideWithValue(coordinator),
        isarInitializedProvider.overrideWithValue(true),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(chatControllerProvider.notifier)
        .loadConversation(conversationId);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AIChatScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(runCount, 0);
    expect(
      find.byKey(const ValueKey<String>('mission-cancelled-card')),
      findsOneWidget,
    );
    expect(
      (await missionRepository.getMission(mission.id))!.status,
      MissionStatus.cancelled,
    );
  });

  testWidgets(
    'short follow-up explicitly resumes the same cancelled Mission and preserves accepted output',
    (tester) async {
      final conversationRepository = _MemoryConversationRepository();
      final missionRepository = MemoryMissionRepository();
      final missionController = MissionController(
        repository: missionRepository,
      );
      const conversationId = 'cancelled-mission-follow-up';
      final mission = await missionController.startMission(
        const MissionSuggestion(
          title: 'Coffee shop plan',
          goal: 'Create a plan for a coffee shop',
          category: MissionCategory.marketing,
          reason: 'Saved Mission',
          plannedSteps: <String>['Audience', 'Posts'],
        ),
        conversationId: conversationId,
      );
      final cancelledMission = mission.copyWith(
        status: MissionStatus.cancelled,
        tasks: <MissionTask>[
          mission.tasks.first.copyWith(
            status: TaskStatus.completed,
            output: 'Saved audience output',
            completedAt: DateTime(2026, 9, 24, 9),
          ),
          mission.tasks.last,
        ],
      );
      await missionRepository.saveMission(cancelledMission);
      await conversationRepository.saveConversation(
        _conversationWithFinalUserMessage(conversationId),
      );
      Mission? missionGivenToRun;
      final coordinator = ChatMissionCoordinator(
        missionController: missionController,
        restoreExecutions: (_) async {},
        runMission: (missionId) async {
          missionGivenToRun = await missionRepository.getMission(missionId);
          return missionGivenToRun!.copyWith(
            tasks: missionGivenToRun!.tasks
                .map(
                  (task) => task.status == TaskStatus.completed
                      ? task
                      : task.copyWith(
                          status: TaskStatus.completed,
                          output: 'Saved posts output',
                          completedAt: DateTime(2026, 9, 24, 10),
                        ),
                )
                .toList(growable: false),
          );
        },
      );
      final service = _SuccessfulAIChatService();
      final container = ProviderContainer(
        overrides: <Override>[
          conversationRepositoryProvider.overrideWithValue(
            conversationRepository,
          ),
          aiChatServiceProvider.overrideWithValue(service),
          missionRepositoryProvider.overrideWithValue(missionRepository),
          chatMissionCoordinatorProvider.overrideWithValue(coordinator),
          isarInitializedProvider.overrideWithValue(true),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(chatControllerProvider.notifier)
          .loadConversation(conversationId);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: AIChatScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'continue');
      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();

      expect(service.requests, isEmpty);
      expect(missionGivenToRun?.id, mission.id);
      expect(missionGivenToRun?.status, MissionStatus.active);
      expect(missionGivenToRun?.tasks.first.output, 'Saved audience output');
      expect(await missionRepository.getAllMissions(), hasLength(1));
      expect(
        container
            .read(chatControllerProvider)
            .messages
            .where((message) => message.role == ChatRole.user),
        hasLength(1),
      );
      expect(
        container
            .read(chatControllerProvider)
            .messages
            .where((message) => message.content == 'continue'),
        isEmpty,
      );
      expect(find.text('Saved audience output'), findsWidgets);
    },
  );

  testWidgets(
    'reopening active Mission history only displays its stored progress',
    (tester) async {
      final conversationRepository = _MemoryConversationRepository();
      final missionRepository = MemoryMissionRepository();
      final missionController = MissionController(
        repository: missionRepository,
      );
      const conversationId = 'active-mission-history';
      final mission = await missionController.startMission(
        const MissionSuggestion(
          title: 'Coffee shop plan',
          goal: 'Create a plan for a coffee shop',
          category: MissionCategory.marketing,
          reason: 'Saved Mission',
          plannedSteps: <String>['Plan'],
        ),
        conversationId: conversationId,
      );
      await missionRepository.saveMission(
        mission.copyWith(
          status: MissionStatus.active,
          tasks: <MissionTask>[
            mission.tasks.single.copyWith(status: TaskStatus.inProgress),
          ],
        ),
      );
      await conversationRepository.saveConversation(
        _conversationWithFinalUserMessage(conversationId),
      );
      var runCount = 0;
      final coordinator = ChatMissionCoordinator(
        missionController: missionController,
        restoreExecutions: (_) async {},
        runMission: (missionId) async {
          runCount++;
          return (await missionRepository.getMission(missionId))!;
        },
      );
      final service = _SuccessfulAIChatService();
      final container = ProviderContainer(
        overrides: <Override>[
          conversationRepositoryProvider.overrideWithValue(
            conversationRepository,
          ),
          aiChatServiceProvider.overrideWithValue(service),
          missionRepositoryProvider.overrideWithValue(missionRepository),
          chatMissionCoordinatorProvider.overrideWithValue(coordinator),
          isarInitializedProvider.overrideWithValue(true),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(chatControllerProvider.notifier)
          .loadConversation(conversationId);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: AIChatScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(runCount, 0);
      expect(service.requests, isEmpty);
      expect(find.text('Ovexiq is working...'), findsOneWidget);
      expect(find.byTooltip('Retry'), findsNothing);
    },
  );

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

  testWidgets('new generated image receives durable artifact and version IDs', (
    tester,
  ) async {
    final imageGenerator = _FakeChatImageGenerator(
      (_) async => _testGeneratedImage(),
    );
    final imageResultStore = _FakeGeneratedImageResultStore(
      '/safe/artifact-image.png',
    );
    final container = ProviderContainer(
      overrides: <Override>[
        conversationRepositoryProvider.overrideWithValue(
          _MemoryConversationRepository(),
        ),
        aiChatServiceProvider.overrideWithValue(_SuccessfulAIChatService()),
        missionRepositoryProvider.overrideWithValue(MemoryMissionRepository()),
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
      'Create a picture of Buddha',
    );
    await tester.tap(find.byTooltip('Send'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    final attachment = container
        .read(chatControllerProvider)
        .messages
        .last
        .attachment!;
    expect(attachment.artifact?.type, ArtifactType.image);
    expect(
      attachment.artifact?.conversationId,
      container.read(chatControllerProvider).conversation?.id,
    );
    expect(attachment.artifactVersion?.artifactId, attachment.artifact?.id);
    expect(attachment.artifactVersion?.localPath, attachment.localFilePath);
    expect(attachment.artifactVersion?.sourceArtifactVersionId, isNull);
    expect(imageGenerator.prompts, hasLength(1));
  });

  testWidgets('attaching one video ingests and persists one video artifact', (
    tester,
  ) async {
    final localVideo = File(Platform.resolvedExecutable);
    final videoPicker = _FakeVideoPicker(
      _selectedVideo(name: 'summer.mp4', bytes: Uint8List.fromList(<int>[1])),
    );
    final videoIngestService = _FakeLocalVideoIngestService(
      IngestedVideo(
        fileName: 'summer.mp4',
        mimeType: 'video/mp4',
        localPath: localVideo.path,
        byteSize: 4,
      ),
    );
    final aiChatService = _SuccessfulAIChatService();
    final container = ProviderContainer(
      overrides: <Override>[
        conversationRepositoryProvider.overrideWithValue(
          _MemoryConversationRepository(),
        ),
        aiChatServiceProvider.overrideWithValue(aiChatService),
        missionRepositoryProvider.overrideWithValue(MemoryMissionRepository()),
        videoPickerProvider.overrideWithValue(videoPicker),
        localVideoIngestServiceProvider.overrideWithValue(videoIngestService),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AIChatScreen()),
      ),
    );
    expect(find.byTooltip('Add attachment'), findsOneWidget);
    await tester.tap(find.byTooltip('Add attachment'));
    await tester.pumpAndSettle();
    expect(find.text('Add Video'), findsOneWidget);
    await tester.tap(find.text('Add Video'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final attachments = container
        .read(chatControllerProvider)
        .messages
        .where((message) => message.attachment != null)
        .toList(growable: false);
    expect(videoPicker.pickCount, 1);
    expect(videoIngestService.ingestCount, 1);
    expect(attachments, hasLength(1));
    expect(attachments.single.attachment?.artifact?.type, ArtifactType.video);
    expect(find.text('Video added'), findsOneWidget);
    expect(aiChatService.requests, isEmpty);
  });

  testWidgets('cancelling Add Video returns to ordinary Chat safely', (
    tester,
  ) async {
    final videoPicker = _FakeVideoPicker(null);
    final aiChatService = _SuccessfulAIChatService();
    final container = ProviderContainer(
      overrides: <Override>[
        conversationRepositoryProvider.overrideWithValue(
          _MemoryConversationRepository(),
        ),
        aiChatServiceProvider.overrideWithValue(aiChatService),
        missionRepositoryProvider.overrideWithValue(MemoryMissionRepository()),
        videoPickerProvider.overrideWithValue(videoPicker),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AIChatScreen()),
      ),
    );

    await tester.tap(find.byTooltip('Add attachment'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Video'));
    await tester.pumpAndSettle();

    expect(videoPicker.pickCount, 1);
    expect(
      container
          .read(chatControllerProvider)
          .messages
          .where((message) => message.attachment != null),
      isEmpty,
    );
    expect(find.text("Couldn't add that video"), findsNothing);

    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.tap(find.byTooltip('Send'));
    await tester.pump(const Duration(seconds: 3));

    expect(aiChatService.requests, hasLength(1));
    expect(
      container.read(chatControllerProvider).messages.first.content,
      'Hello',
    );
  });

  testWidgets(
    'cancelling image work hides Working and ignores a late success',
    (tester) async {
      final imageCompleter = Completer<GeneratedImage>();
      final imageGenerator = _CancellableFakeChatImageGenerator(
        (_) => imageCompleter.future,
      );
      final imageResultStore = _FakeGeneratedImageResultStore(
        '/safe/cancelled-image.png',
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
        'Create a picture of Buddha',
      );
      await tester.tap(find.byTooltip('Send'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Ovexiq is creating your image...'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey<String>('cancel-image-generation-button')),
      );
      await tester.pump();

      expect(imageGenerator.cancelCount, 1);
      expect(find.text('Ovexiq is creating your image...'), findsNothing);
      expect(find.text('Cancel'), findsNothing);
      expect(
        find.text('Ovexiq couldn’t create that image. Please try again.'),
        findsNothing,
      );
      expect(
        container.read(chatControllerProvider).isImageGenerationInProgress,
        isFalse,
      );
      expect(imageResultStore.savedPaths, isEmpty);
      expect(
        container
            .read(chatControllerProvider)
            .messages
            .where((message) => message.attachment != null),
        isEmpty,
      );

      // A second cancellation after the Working row is gone is harmless.
      container
          .read(chatControllerProvider.notifier)
          .cancelImageGeneration(requestId: 'not-active');

      imageCompleter.complete(_testGeneratedImage());
      await tester.pump();
      await tester.pump();

      expect(imageGenerator.prompts, hasLength(1));
      expect(imageResultStore.savedPaths, isEmpty);
      expect(
        container
            .read(chatControllerProvider)
            .messages
            .where((message) => message.attachment != null),
        isEmpty,
      );
      expect(
        find.text('Ovexiq couldn’t create that image. Please try again.'),
        findsNothing,
      );
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
      expect(find.text('Result Pack ready'), findsOneWidget);
      expect(find.text('Finished result'), findsWidgets);
      expect(find.text('Mission'), findsNothing);
      expect(find.text('Task 1'), findsNothing);
      expect(find.text('Run Task'), findsNothing);
      expect(find.text('Accept Result'), findsNothing);
    },
  );

  testWidgets('TikTok clarification resolves unsupported execution neutrally', (
    tester,
  ) async {
    final aiChatService = _SuccessfulAIChatService();
    final container = ProviderContainer(
      overrides: <Override>[
        conversationRepositoryProvider.overrideWithValue(
          _MemoryConversationRepository(),
        ),
        aiChatServiceProvider.overrideWithValue(aiChatService),
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
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'This feature isn’t available in the current Ovexiq beta yet.',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Reel and video creation features are coming soon.'),
      findsOneWidget,
    );
    expect(find.text('Ovexiq is working...'), findsNothing);
    expect(container.read(chatControllerProvider).missionSuggestion, isNull);
    expect(aiChatService.requests, isEmpty);
    expect(find.byTooltip('Retry'), findsNothing);
  });

  testWidgets('automatic English Mission failure shows a retryable error card', (
    tester,
  ) async {
    final missionRepository = MemoryMissionRepository();
    final controller = MissionController(repository: missionRepository);
    var runCount = 0;
    final coordinator = ChatMissionCoordinator(
      missionController: controller,
      restoreExecutions: (_) async {},
      runMission: (missionId) async {
        runCount++;
        final mission = (await missionRepository.getMission(missionId))!;
        if (runCount == 1) {
          return mission;
        }

        return mission.copyWith(
          tasks: mission.tasks
              .map(
                (task) => task.copyWith(
                  status: TaskStatus.completed,
                  output: 'Ready-to-use finished result',
                  completedAt: DateTime(2026, 9, 19),
                ),
              )
              .toList(growable: false),
        );
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
      find.byKey(const ValueKey<String>('mission-error-card')),
      findsOneWidget,
    );
    expect(
      find.text("Ovexiq couldn't finish this task. Please try again."),
      findsOneWidget,
    );
    expect(find.byTooltip('Copy'), findsOneWidget);
    expect(find.byTooltip('Retry'), findsOneWidget);
    expect(find.text('Run Task'), findsNothing);
    expect(find.text('Retry Task'), findsNothing);
    expect(find.text('Accept Result'), findsNothing);

    await tester.tap(find.byTooltip('Retry'));
    await tester.pumpAndSettle();

    expect(runCount, 2);
    expect(await missionRepository.getAllMissions(), hasLength(1));
    expect(
      container
          .read(chatControllerProvider)
          .messages
          .where(
            (message) =>
                message.content ==
                'Create a 30-day social media content calendar for a coffee shop',
          ),
      hasLength(1),
    );
    expect(
      find.byKey(const ValueKey<String>('mission-error-card')),
      findsNothing,
    );
    expect(find.text('Ready-to-use finished result'), findsWidgets);
  });

  testWidgets('automatic Burmese Mission failure shows a localized error card', (
    tester,
  ) async {
    final missionRepository = MemoryMissionRepository();
    final coordinator = ChatMissionCoordinator(
      missionController: MissionController(repository: missionRepository),
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
      'Facebook နဲ့ TikTok အတွက် coffee shop Page ရဲ့ 30 ရက်စာ Content Plan ဖန်တီးပေးပါ။',
    );
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Ovexiq က ဒီလုပ်ငန်းကို အပြီးမလုပ်ဆောင်နိုင်သေးပါ။ ထပ်စမ်းကြည့်ပါ။',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('mission-error-card')),
      findsOneWidget,
    );
    expect(find.byTooltip('Copy'), findsOneWidget);
    expect(find.byTooltip('Retry'), findsOneWidget);
  });

  testWidgets(
    'Mission Retry is unavailable while the existing Mission is running',
    (tester) async {
      final missionRepository = MemoryMissionRepository();
      final retryCompleter = Completer<Mission>();
      var runCount = 0;
      final coordinator = ChatMissionCoordinator(
        missionController: MissionController(repository: missionRepository),
        restoreExecutions: (_) async {},
        runMission: (missionId) {
          runCount++;
          if (runCount == 1) {
            return missionRepository
                .getMission(missionId)
                .then((mission) => mission!);
          }
          return retryCompleter.future;
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

      await tester.tap(find.byTooltip('Retry'));
      await tester.pump();

      expect(runCount, 2);
      expect(find.text('Ovexiq is working...'), findsOneWidget);
      expect(find.byTooltip('Retry'), findsNothing);

      final mission = (await missionRepository.getAllMissions()).single;
      retryCompleter.complete(_completedMission(mission));
      await tester.pumpAndSettle();
      expect(runCount, 2);
      expect(
        find.byKey(const ValueKey<String>('finished-result-card')),
        findsOneWidget,
      );
    },
  );

  testWidgets('a failed Mission retry remains safely retryable', (
    tester,
  ) async {
    final missionRepository = MemoryMissionRepository();
    var runCount = 0;
    final coordinator = ChatMissionCoordinator(
      missionController: MissionController(repository: missionRepository),
      restoreExecutions: (_) async {},
      runMission: (missionId) async {
        runCount++;
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
    await tester.tap(find.byTooltip('Retry'));
    await tester.pumpAndSettle();

    expect(runCount, 2);
    expect(
      find.byKey(const ValueKey<String>('mission-error-card')),
      findsOneWidget,
    );
    expect(find.byTooltip('Retry'), findsOneWidget);
    expect(await missionRepository.getAllMissions(), hasLength(1));
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

class _LateFailureAIChatService extends AIChatService {
  final started = Completer<void>();
  StreamController<AIChunk>? _response;

  @override
  Stream<AIChunk> sendMessages(List<AIMessage> messages) {
    final response = StreamController<AIChunk>();
    _response = response;
    started.complete();
    return response.stream;
  }

  void failLate() {
    _response!
      ..addError(StateError('late provider error'))
      ..close();
  }
}

class _StoppedChatRetryAIChatService extends AIChatService {
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
      ..addError(StateError('late provider error'))
      ..close();
  }

  void succeedRetry() {
    _responses[1]
      ..add(
        const AIChunk.text(
          provider: ProviderType.openAI,
          text: 'Retried answer',
        ),
      )
      ..add(const AIChunk.done(provider: ProviderType.openAI))
      ..close();
  }
}

class _RateLimitedAIChatService extends AIChatService {
  @override
  Stream<AIChunk> sendMessages(List<AIMessage> messages) async* {
    yield const AIChunk.status(
      provider: ProviderType.openAI,
      text: 'Generating',
    );
    yield const AIChunk.error(
      provider: ProviderType.openAI,
      error: 'Too many requests.',
      failure: AIRequestFailure(
        category: AIRequestFailureCategory.rateLimited,
        retryable: true,
        executionStage: 'gateway_response',
        diagnosticReason: 'http_429',
        statusCode: 429,
        retryAfter: Duration(seconds: 60),
      ),
    );
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

class _FakeChatImageGenerator extends ChatImageGenerator {
  _FakeChatImageGenerator(this._onGenerate);

  final Future<GeneratedImage> Function(String prompt) _onGenerate;
  final List<String> prompts = <String>[];

  @override
  Future<GeneratedImage> generate({required String prompt}) {
    prompts.add(prompt);
    return _onGenerate(prompt);
  }
}

class _CancellableFakeChatImageGenerator extends ChatImageGenerator {
  _CancellableFakeChatImageGenerator(this._onGenerate);

  final Future<GeneratedImage> Function(String prompt) _onGenerate;
  final List<String> prompts = <String>[];
  var cancelCount = 0;

  @override
  Future<GeneratedImage> generate({required String prompt}) {
    prompts.add(prompt);
    return _onGenerate(prompt);
  }

  @override
  ChatImageGenerationOperation startGeneration({required String prompt}) {
    final result = generate(prompt: prompt);
    return ChatImageGenerationOperation.fromFuture(
      result,
      onCancel: () {
        cancelCount++;
      },
    );
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

class _FakeVideoPicker implements VideoPicker {
  _FakeVideoPicker(this._video);

  final SelectedVideoFile? _video;
  var pickCount = 0;

  @override
  Future<SelectedVideoFile?> pickOneVideo() async {
    pickCount++;
    return _video;
  }
}

class _FakeLocalVideoIngestService extends LocalVideoIngestService {
  _FakeLocalVideoIngestService(this._result);

  final IngestedVideo _result;
  var ingestCount = 0;

  @override
  Future<IngestedVideo> ingest({
    required String conversationId,
    required String ingestId,
    required SelectedVideoFile source,
  }) async {
    ingestCount++;
    return _result;
  }
}

SelectedVideoFile _selectedVideo({
  required String name,
  required Uint8List bytes,
}) {
  return SelectedVideoFile(
    name: name,
    readLength: () async => bytes.length,
    readStream: () => Stream<Uint8List>.value(bytes),
  );
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

Conversation _conversationWithFinalUserMessage(String conversationId) {
  final createdAt = DateTime(2026, 9, 24, 9);
  return Conversation(
    id: conversationId,
    title: 'Coffee shop plan',
    messages: <ChatMessage>[
      ChatMessage(
        id: '$conversationId-user',
        role: ChatRole.user,
        content: 'Create a plan for a coffee shop',
        createdAt: createdAt,
      ),
    ],
    createdAt: createdAt,
    updatedAt: createdAt,
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
