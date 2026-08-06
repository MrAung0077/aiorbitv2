import 'dart:convert';
import 'dart:ffi' hide Size;
import 'dart:io';

import 'package:aiorbit/core/database/isar_service.dart';
import 'package:aiorbit/features/chat/ai_chat_screen.dart';
import 'package:aiorbit/features/chat/conversation_history_screen.dart';
import 'package:aiorbit/features/chat/models/chat_message.dart';
import 'package:aiorbit/features/chat/models/conversation.dart';
import 'package:aiorbit/features/chat/providers/chat_controller.dart';
import 'package:aiorbit/features/chat/providers/conversation_list_provider.dart';
import 'package:aiorbit/features/home/home_screen.dart';
import 'package:aiorbit/features/mission/mission_detail_screen.dart';
import 'package:aiorbit/features/mission/mission_preview_screen.dart';
import 'package:aiorbit/features/mission/models/execution_status.dart';
import 'package:aiorbit/features/mission/models/mission.dart';
import 'package:aiorbit/features/mission/models/mission_category.dart';
import 'package:aiorbit/features/mission/models/mission_execution.dart';
import 'package:aiorbit/features/mission/models/mission_status.dart';
import 'package:aiorbit/features/mission/models/mission_task.dart';
import 'package:aiorbit/features/mission/models/mission_task_execution.dart';
import 'package:aiorbit/features/mission/models/task_status.dart';
import 'package:aiorbit/features/mission/providers/mission_execution_provider.dart';
import 'package:aiorbit/features/mission/providers/mission_provider.dart';
import 'package:aiorbit/features/mission/providers/mission_task_execution_provider.dart';
import 'package:aiorbit/features/mission/services/memory_mission_repository.dart';
import 'package:aiorbit/features/mission/services/mission_task_executor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

void main() {
  late Directory databaseDirectory;
  late String databaseName;
  var databaseSequence = 0;

  setUpAll(_initializeTestIsarCore);

  setUp(() async {
    databaseSequence += 1;
    databaseDirectory = await Directory.systemTemp.createTemp(
      'aiorbit-restart-recovery-',
    );
    databaseName = 'restart-recovery-$databaseSequence';

    await IsarService.initialize(
      directoryPath: databaseDirectory.path,
      name: databaseName,
      inspector: false,
    );
  });

  tearDown(() async {
    await IsarService.close();

    if (await databaseDirectory.exists()) {
      await databaseDirectory.delete(recursive: true);
    }
  });

  testWidgets(
    'restart restores Home, Library, latest mission, and completed workflow',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final latestConversation = _conversation(
        id: 'conversation-latest',
        title: 'Latest persisted conversation',
        updatedAt: DateTime(2026, 4, 2, 10),
        prompt: 'Research the latest AI trends',
      );
      final recentConversation = _conversation(
        id: 'conversation-recent',
        title: 'Older persisted conversation',
        updatedAt: DateTime(2026, 4, 1, 10),
        prompt: 'Help me write a launch plan',
      );
      final olderMission = _mission(
        id: 'mission-older',
        conversationId: latestConversation.id,
        title: 'Older Linked Mission',
        updatedAt: DateTime(2026, 4, 2, 11),
        taskStatus: TaskStatus.pending,
      );
      final completedAt = DateTime(2026, 4, 3, 9);
      final latestMission = _mission(
        id: 'mission-latest',
        conversationId: latestConversation.id,
        title: 'Restored Completed Mission',
        updatedAt: DateTime(2026, 4, 3, 10),
        taskStatus: TaskStatus.completed,
        completedAt: completedAt,
        taskOutput: 'Do not restore this task output',
      );
      final initialContainer = ProviderContainer(
        overrides: <Override>[
          missionTaskExecutorProvider.overrideWithValue(
            const _ImmediateMissionTaskExecutor(),
          ),
        ],
      );
      final conversationRepository = initialContainer.read(
        conversationRepositoryProvider,
      );
      final missionRepository = initialContainer.read(
        missionRepositoryProvider,
      );

      await tester.runAsync(() async {
        await conversationRepository.saveConversation(recentConversation);
        await conversationRepository.saveConversation(latestConversation);
        await missionRepository.saveMission(olderMission);
        await missionRepository.saveMission(latestMission);
      });

      final taskExecution = await tester.runAsync(
        () => initialContainer
            .read(missionTaskExecutionProvider.notifier)
            .executeTask(
              missionId: olderMission.id,
              taskId: olderMission.tasks.single.id,
            ),
      );
      final missionExecution = initialContainer.read(
        missionExecutionProvider.notifier,
      );
      missionExecution.createExecution(
        executionId: 'session-mission-execution',
        missionId: latestMission.id,
      );
      missionExecution.prepare();
      missionExecution.start();

      expect(taskExecution?.outputText, 'Session-only execution result');
      expect(initialContainer.read(missionExecutionProvider), isNotNull);
      expect(initialContainer.read(missionTaskExecutionProvider), isNotEmpty);

      initialContainer.dispose();
      await tester.runAsync(() async {
        await IsarService.close();
        await IsarService.initialize(
          directoryPath: databaseDirectory.path,
          name: databaseName,
          inspector: false,
        );
      });

      final restoredContainer = ProviderContainer();
      addTearDown(restoredContainer.dispose);
      final restoredController = restoredContainer.read(
        missionControllerProvider,
      );
      final restoredMission = await tester.runAsync(
        () =>
            restoredController.getMissionForConversation(latestConversation.id),
      );

      expect(restoredMission?.id, latestMission.id);
      expect(restoredMission?.tasks.single.status, TaskStatus.completed);
      expect(restoredMission?.tasks.single.completedAt, isNotNull);
      expect(restoredMission?.tasks.single.output, isNull);
      expect(restoredMission?.taskProgress.percentage, 100);
      expect(restoredContainer.read(missionExecutionProvider), isNull);
      expect(restoredContainer.read(missionTaskExecutionProvider), isEmpty);

      await tester.runAsync(() async {
        await restoredContainer
            .read(chatControllerProvider.notifier)
            .loadMostRecentConversation();
        await restoredContainer.read(conversationListProvider.future);
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: restoredContainer,
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Continue'), findsOneWidget);
      expect(find.text(latestConversation.title), findsOneWidget);
      expect(find.text('Recent'), findsOneWidget);
      expect(find.text(recentConversation.title), findsOneWidget);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: restoredContainer,
          child: const MaterialApp(home: ConversationHistoryScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(latestConversation.title), findsOneWidget);
      expect(find.text(recentConversation.title), findsOneWidget);

      final restoredMissions = await tester.runAsync(
        () =>
            restoredContainer.read(missionRepositoryProvider).getAllMissions(),
      );
      final uiMissionRepository = MemoryMissionRepository();
      await tester.runAsync(() async {
        for (final mission in restoredMissions!) {
          await uiMissionRepository.saveMission(mission);
        }
      });
      final uiContainer = ProviderContainer(
        overrides: <Override>[
          missionRepositoryProvider.overrideWithValue(uiMissionRepository),
        ],
      );
      addTearDown(uiContainer.dispose);
      await tester.runAsync(
        () => uiContainer
            .read(chatControllerProvider.notifier)
            .loadConversation(latestConversation.id),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: uiContainer,
          child: const MaterialApp(home: AIChatScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AIChatScreen), findsOneWidget);
      expect(find.text('Continue Mission'), findsOneWidget);
      expect(find.text('Open Mission'), findsOneWidget);

      await tester.runAsync(
        () => uiContainer
            .read(missionTaskExecutionProvider.notifier)
            .restoreMissionExecutions(latestMission.id),
      );

      await tester.tap(find.text('Open Mission'));
      await tester.pumpAndSettle();

      expect(find.byType(MissionDetailScreen), findsOneWidget);
      expect(find.text(latestMission.title), findsOneWidget);
      expect(find.text(olderMission.title), findsNothing);
      expect(find.text('Mission Completed'), findsOneWidget);
      expect(find.text('All tasks completed successfully.'), findsOneWidget);
      expect(find.text('1 / 1 Tasks Completed'), findsOneWidget);
      expect(find.text('Mission Timeline'), findsOneWidget);
      expect(find.text('Mission Execution'), findsOneWidget);
      expect(find.text('Workflow'), findsOneWidget);
      expect(find.text('Session-only execution result'), findsNothing);
      expect(find.text('Do not restore this task output'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets('restart with missing linked mission falls back to Preview', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1024, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final conversation = _conversation(
      id: 'conversation-missing-mission',
      title: 'Conversation with removed mission',
      updatedAt: DateTime(2026, 4, 4, 10),
      prompt: 'Research the latest AI trends',
    );
    final removedMission = _mission(
      id: 'mission-removed',
      conversationId: conversation.id,
      title: 'Removed Mission',
      updatedAt: DateTime(2026, 4, 4, 11),
      taskStatus: TaskStatus.pending,
    );
    final initialContainer = ProviderContainer();

    await tester.runAsync(
      () => initialContainer
          .read(conversationRepositoryProvider)
          .saveConversation(conversation),
    );
    final missionRepository = initialContainer.read(missionRepositoryProvider);
    await tester.runAsync(() async {
      await missionRepository.saveMission(removedMission);
      await missionRepository.deleteMission(removedMission.id);
    });

    initialContainer.dispose();
    await tester.runAsync(() async {
      await IsarService.close();
      await IsarService.initialize(
        directoryPath: databaseDirectory.path,
        name: databaseName,
        inspector: false,
      );
    });

    final restoredContainer = ProviderContainer();
    addTearDown(restoredContainer.dispose);

    final restoredMission = await tester.runAsync(
      () => restoredContainer
          .read(missionControllerProvider)
          .getMissionForConversation(conversation.id),
    );
    expect(restoredMission, isNull);

    await tester.runAsync(() async {
      await restoredContainer.read(conversationListProvider.future);
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: restoredContainer,
        child: const MaterialApp(home: ConversationHistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(conversation.title), findsOneWidget);

    final uiMissionRepository = MemoryMissionRepository();
    final uiContainer = ProviderContainer(
      overrides: <Override>[
        missionRepositoryProvider.overrideWithValue(uiMissionRepository),
      ],
    );
    addTearDown(uiContainer.dispose);
    await tester.runAsync(
      () => uiContainer
          .read(chatControllerProvider.notifier)
          .loadConversation(conversation.id),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: uiContainer,
        child: const MaterialApp(home: AIChatScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AIChatScreen), findsOneWidget);
    expect(find.text('Continue as a Mission'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.byType(MissionPreviewScreen), findsOneWidget);
    final restoredMissions = await tester.runAsync(
      () => restoredContainer.read(missionRepositoryProvider).getAllMissions(),
    );
    expect(restoredMissions, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
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
        id: '$id-user',
        role: ChatRole.user,
        content: prompt,
        createdAt: updatedAt.subtract(const Duration(minutes: 1)),
      ),
      ChatMessage(
        id: '$id-assistant',
        role: ChatRole.assistant,
        content: 'A persisted assistant response.',
        createdAt: updatedAt,
      ),
    ],
    createdAt: updatedAt.subtract(const Duration(hours: 1)),
    updatedAt: updatedAt,
  );
}

Mission _mission({
  required String id,
  required String conversationId,
  required String title,
  required DateTime updatedAt,
  required TaskStatus taskStatus,
  DateTime? completedAt,
  String? taskOutput,
}) {
  final createdAt = updatedAt.subtract(const Duration(days: 1));

  return Mission(
    id: id,
    title: title,
    goal: 'Restore the persisted mission after restart',
    category: MissionCategory.productivity,
    status: MissionStatus.active,
    createdAt: createdAt,
    updatedAt: updatedAt,
    currentTaskIndex: 0,
    progressPercent: 99,
    tasks: <MissionTask>[
      MissionTask(
        id: '$id-task',
        missionId: id,
        title: 'Persisted workflow task',
        description: 'Verify restart recovery.',
        order: 0,
        status: taskStatus,
        taskType: 'research',
        output: taskOutput,
        createdAt: createdAt,
        completedAt: completedAt,
      ),
    ],
    conversationId: conversationId,
  );
}

class _ImmediateMissionTaskExecutor implements MissionTaskExecutor {
  const _ImmediateMissionTaskExecutor();

  @override
  Future<MissionTaskExecution> execute({
    required Mission mission,
    required MissionTask task,
  }) async {
    final startedAt = DateTime(2026, 4, 3, 11);

    return MissionTaskExecution(
      execution: MissionExecution(
        id: 'task-execution-${task.id}',
        missionId: mission.id,
        status: ExecutionStatus.completed,
        progress: 1,
        startedAt: startedAt,
        finishedAt: startedAt.add(const Duration(minutes: 1)),
        currentTaskId: task.id,
      ),
      outputText: 'Session-only execution result',
    );
  }
}

Future<void> _initializeTestIsarCore() async {
  final packageConfigFile = File('.dart_tool/package_config.json').absolute;
  final packageConfig = jsonDecode(await packageConfigFile.readAsString());
  final packages = packageConfig['packages'] as List<dynamic>;
  final flutterLibraries = packages.cast<Map<String, dynamic>>().firstWhere(
    (package) => package['name'] == 'isar_community_flutter_libs',
  );
  final rootUri = packageConfigFile.uri.resolve(
    flutterLibraries['rootUri'] as String,
  );
  final libraryUri = Directory.fromUri(
    rootUri,
  ).uri.resolve(_platformLibraryPath());

  await Isar.initializeIsarCore(
    libraries: <Abi, String>{Abi.current(): File.fromUri(libraryUri).path},
  );
}

String _platformLibraryPath() {
  if (Platform.isWindows) {
    return 'windows/libisar.dll';
  }

  if (Platform.isLinux) {
    return 'linux/libisar.so';
  }

  if (Platform.isMacOS) {
    return 'macos/libisar.dylib';
  }

  throw UnsupportedError('Restart recovery tests are desktop-only.');
}
