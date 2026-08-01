import 'package:aiorbit/features/chat/ai_chat_screen.dart';
import 'package:aiorbit/features/chat/conversation_history_screen.dart';
import 'package:aiorbit/features/chat/models/chat_message.dart';
import 'package:aiorbit/features/chat/models/conversation.dart';
import 'package:aiorbit/features/chat/providers/chat_controller.dart';
import 'package:aiorbit/features/chat/repositories/conversation_repository.dart';
import 'package:aiorbit/features/mission/mission_detail_screen.dart';
import 'package:aiorbit/features/mission/mission_preview_screen.dart';
import 'package:aiorbit/features/mission/models/mission.dart';
import 'package:aiorbit/features/mission/models/mission_category.dart';
import 'package:aiorbit/features/mission/models/mission_status.dart';
import 'package:aiorbit/features/mission/models/mission_task.dart';
import 'package:aiorbit/features/mission/models/task_status.dart';
import 'package:aiorbit/features/mission/providers/mission_execution_provider.dart';
import 'package:aiorbit/features/mission/providers/mission_provider.dart';
import 'package:aiorbit/features/mission/services/memory_mission_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tapping a History item reopens the exact conversation', (
    tester,
  ) async {
    final selectedConversation = _conversation(
      id: 'selected',
      title: 'Selected conversation',
      updatedAt: DateTime(2026, 1, 1),
      prompt: 'Research the latest AI trends',
    );
    final container = ProviderContainer(
      overrides: <Override>[
        conversationRepositoryProvider.overrideWithValue(
          _MemoryConversationRepository(<Conversation>[
            _conversation(
              id: 'latest',
              title: 'Latest conversation',
              updatedAt: DateTime(2026, 1, 2),
              prompt: 'Hello',
            ),
            selectedConversation,
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ConversationHistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Selected conversation'));
    await tester.pumpAndSettle();

    final chatState = container.read(chatControllerProvider);

    expect(chatState.conversation?.id, selectedConversation.id);
    expect(chatState.messages.single.content, 'Research the latest AI trends');
    expect(chatState.missionSuggestion, isNotNull);
    expect(find.byType(AIChatScreen), findsOneWidget);
    expect(
      find.text('Your first mission starts with a conversation.'),
      findsNothing,
    );
  });

  testWidgets('shows an empty state when no conversations exist', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: <Override>[
        conversationRepositoryProvider.overrideWithValue(
          _MemoryConversationRepository(const <Conversation>[]),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ConversationHistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Your first mission starts with a conversation.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Tell Ovexiq what you want to accomplish, and it can turn your goal '
        'into a structured workflow.',
      ),
      findsOneWidget,
    );
    expect(find.text('Start Chat'), findsOneWidget);

    await tester.tap(find.text('Start Chat'));
    await tester.pumpAndSettle();

    expect(find.byType(AIChatScreen), findsOneWidget);
    expect(find.text('Tell Ovexiq your goal'), findsOneWidget);
    expect(
      find.text(
        'Describe what you want to accomplish. Ovexiq can help turn it into '
        'a structured workflow.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'Continue Mission opens the latest linked mission without duplicating it',
    (tester) async {
      final selectedConversation = _conversation(
        id: 'selected',
        title: 'Selected conversation',
        updatedAt: DateTime(2026, 1, 2),
        prompt: 'Research the latest AI trends',
      );
      final missionRepository = MemoryMissionRepository();
      final linkedMission = _mission(
        id: 'linked',
        conversationId: selectedConversation.id,
        title: 'Correct Mission',
        taskStatus: TaskStatus.pending,
        updatedAt: DateTime(2026, 1, 2),
      );

      await missionRepository.saveMission(linkedMission);
      await missionRepository.saveMission(
        _mission(
          id: 'other',
          conversationId: 'other-conversation',
          title: 'Other Mission',
          taskStatus: TaskStatus.completed,
          updatedAt: DateTime(2026, 1, 3),
        ),
      );

      final container = ProviderContainer(
        overrides: <Override>[
          conversationRepositoryProvider.overrideWithValue(
            _MemoryConversationRepository(<Conversation>[selectedConversation]),
          ),
          missionRepositoryProvider.overrideWithValue(missionRepository),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ConversationHistoryScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Selected conversation'));
      await tester.pumpAndSettle();

      expect(find.text('Continue Mission'), findsOneWidget);
      expect(find.text('Open Mission'), findsOneWidget);

      final latestMission = linkedMission.copyWith(
        tasks: <MissionTask>[
          linkedMission.tasks.single.copyWith(
            status: TaskStatus.completed,
            completedAt: DateTime(2026, 1, 4),
          ),
        ],
        updatedAt: DateTime(2026, 1, 4),
      );
      await missionRepository.saveMission(latestMission);

      final executionNotifier = container.read(
        missionExecutionProvider.notifier,
      );
      executionNotifier.createExecution(
        executionId: 'execution-linked',
        missionId: linkedMission.id,
      );
      executionNotifier.prepare();
      executionNotifier.start();
      executionNotifier.updateProgress(
        progress: 0.5,
        currentTaskId: linkedMission.tasks.single.id,
      );

      await tester.tap(find.text('Open Mission'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(MissionDetailScreen), findsOneWidget);
      expect(find.text('Correct Mission'), findsOneWidget);
      expect(find.text('Other Mission'), findsNothing);
      expect(find.text('Mission Completed'), findsOneWidget);
      expect(find.text('All tasks completed successfully.'), findsOneWidget);
      expect(find.text('1 / 1 Tasks Completed'), findsOneWidget);
      expect(find.text('Mission Timeline'), findsOneWidget);
      expect(find.text('Mission Execution'), findsOneWidget);
      expect(find.text('Running'), findsOneWidget);
      expect(find.text('50% executed'), findsOneWidget);
      expect(find.text('Workflow'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('task-status-linked-task')),
        findsOneWidget,
      );

      final missions = await missionRepository.getAllMissions();
      expect(missions, hasLength(2));
    },
  );

  testWidgets('missing mission linkage keeps the safe preview flow', (
    tester,
  ) async {
    final conversation = _conversation(
      id: 'without-mission',
      title: 'Conversation without a mission',
      updatedAt: DateTime(2026, 1, 2),
      prompt: 'Research the latest AI trends',
    );
    final missionRepository = MemoryMissionRepository();
    final container = ProviderContainer(
      overrides: <Override>[
        conversationRepositoryProvider.overrideWithValue(
          _MemoryConversationRepository(<Conversation>[conversation]),
        ),
        missionRepositoryProvider.overrideWithValue(missionRepository),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ConversationHistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Conversation without a mission'));
    await tester.pumpAndSettle();

    expect(find.text('Continue as a Mission'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.byType(MissionPreviewScreen), findsOneWidget);
    expect(await missionRepository.getAllMissions(), isEmpty);

    final startMissionButton = find.text('Start Mission');
    await tester.ensureVisible(startMissionButton);
    await tester.tap(startMissionButton);
    await tester.pumpAndSettle();

    expect(find.byType(MissionDetailScreen), findsOneWidget);

    final missions = await missionRepository.getAllMissions();
    expect(missions, hasLength(1));
    expect(missions.single.conversationId, conversation.id);
  });
}

Conversation _conversation({
  required String id,
  required String title,
  required DateTime updatedAt,
  required String prompt,
}) {
  return Conversation(
    id: id,
    title: title,
    messages: <ChatMessage>[
      ChatMessage(
        id: 'message-$id',
        role: ChatRole.user,
        content: prompt,
        createdAt: updatedAt,
      ),
    ],
    createdAt: updatedAt,
    updatedAt: updatedAt,
  );
}

Mission _mission({
  required String id,
  required String conversationId,
  required String title,
  required TaskStatus taskStatus,
  required DateTime updatedAt,
}) {
  return Mission(
    id: id,
    title: title,
    goal: 'Complete the linked mission',
    category: MissionCategory.education,
    status: MissionStatus.active,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: updatedAt,
    currentTaskIndex: 0,
    progressPercent: 0,
    tasks: <MissionTask>[
      MissionTask(
        id: '$id-task',
        missionId: id,
        title: 'Linked task',
        description: 'Complete the linked task',
        order: 0,
        status: taskStatus,
        taskType: 'research',
        createdAt: DateTime(2026, 1, 1),
      ),
    ],
    conversationId: conversationId,
  );
}

class _MemoryConversationRepository extends ConversationRepository {
  _MemoryConversationRepository(Iterable<Conversation> conversations)
    : _items = <String, Conversation>{
        for (final conversation in conversations) conversation.id: conversation,
      };

  final Map<String, Conversation> _items;

  @override
  Future<List<Conversation>> getAllConversations() async {
    return _items.values.toList(growable: false);
  }

  @override
  Future<Conversation?> getConversation(String conversationId) async {
    return _items[conversationId];
  }
}
