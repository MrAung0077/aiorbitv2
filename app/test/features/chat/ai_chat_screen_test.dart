import 'dart:async';

import 'package:aiorbit/core/ai/ai.dart';
import 'package:aiorbit/features/chat/ai_chat_screen.dart';
import 'package:aiorbit/features/chat/models/conversation.dart';
import 'package:aiorbit/features/chat/providers/chat_controller.dart';
import 'package:aiorbit/features/chat/repositories/conversation_repository.dart';
import 'package:aiorbit/features/chat/services/ai_chat_service.dart';
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
    },
  );

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
  @override
  Stream<AIChunk> sendMessages(List<AIMessage> messages) async* {
    yield const AIChunk.text(
      provider: ProviderType.openAI,
      text: 'I will take care of that.',
    );
    yield const AIChunk.done(provider: ProviderType.openAI);
  }
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
