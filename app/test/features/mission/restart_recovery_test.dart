import 'dart:convert';
import 'dart:ffi' hide Size;
import 'dart:io';

import 'package:aiorbit/core/database/isar_service.dart';
import 'package:aiorbit/features/chat/conversation_history_screen.dart';
import 'package:aiorbit/features/chat/models/chat_message.dart';
import 'package:aiorbit/features/chat/models/conversation.dart';
import 'package:aiorbit/features/chat/providers/chat_controller.dart';
import 'package:aiorbit/features/chat/providers/conversation_list_provider.dart';
import 'package:aiorbit/features/home/home_screen.dart';
import 'package:aiorbit/features/mission/mission_detail_screen.dart';
import 'package:aiorbit/features/mission/mission_final_results_card.dart';
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
      final latestMission = _mission(
        id: 'mission-latest',
        conversationId: latestConversation.id,
        title: 'Restored Completed Mission',
        updatedAt: DateTime(2026, 4, 3, 10),
        taskStatus: TaskStatus.pending,
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
              missionId: latestMission.id,
              taskId: latestMission.tasks.single.id,
            ),
      );

      final acceptedMission = await tester.runAsync(
        () => initialContainer
            .read(missionTaskExecutionProvider.notifier)
            .acceptResult(
              missionId: latestMission.id,
              taskId: latestMission.tasks.single.id,
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
      expect(acceptedMission, isNotNull);

      expect(acceptedMission!.tasks.single.status, TaskStatus.completed);
      expect(acceptedMission.tasks.single.completedAt, isNotNull);
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
      expect(
        restoredMission?.tasks.single.output,
        'Session-only execution result',
      );
      expect(restoredMission?.taskProgress.percentage, 100);
      expect(restoredContainer.read(missionExecutionProvider), isNull);
      expect(restoredContainer.read(missionTaskExecutionProvider), isEmpty);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: restoredContainer,
          child: MaterialApp(
            home: MissionDetailScreen(
              mission: restoredMission!,
              missionController: restoredController,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MissionFinalResultsCard), findsOneWidget);
      expect(find.text('Final Results'), findsOneWidget);
      expect(find.text('Session-only execution result'), findsOneWidget);
      expect(
        find.byKey(
          ValueKey<String>(
            'open-final-result-${latestMission.tasks.single.id}',
          ),
        ),
        findsOneWidget,
      );
      expect(restoredContainer.read(missionTaskExecutionProvider), isEmpty);

      await tester.tap(
        find.byKey(
          ValueKey<String>(
            'open-final-result-${latestMission.tasks.single.id}',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Accepted Result'), findsOneWidget);
      expect(find.text('Execution Output'), findsNothing);
      expect(find.text('Review before accepting'), findsNothing);
      expect(restoredContainer.read(missionTaskExecutionProvider), isEmpty);

      await tester.pageBack();
      await tester.pumpAndSettle();

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

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets(
    'restart restores only task executions that were actually attempted',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final baseMission = _mission(
        id: 'mission-partial-execution',
        conversationId: 'conversation-partial-execution',
        title: 'Partially Executed Mission',
        updatedAt: DateTime(2026, 4, 4, 10),
        taskStatus: TaskStatus.pending,
      );
      final mission = baseMission.copyWith(
        tasks: List<MissionTask>.generate(3, (index) {
          final taskNumber = index + 1;

          return MissionTask(
            id: '${baseMission.id}-task-$taskNumber',
            missionId: baseMission.id,
            title: 'Task $taskNumber',
            description: 'Complete task $taskNumber.',
            order: index,
            status: TaskStatus.pending,
            taskType: 'research',
            createdAt: baseMission.createdAt.add(Duration(minutes: index)),
          );
        }),
      );
      final task1 = mission.tasks[0];
      final task2 = mission.tasks[1];
      final task3 = mission.tasks[2];
      final initialContainer = ProviderContainer(
        overrides: <Override>[
          missionTaskExecutorProvider.overrideWithValue(
            const _ImmediateMissionTaskExecutor(),
          ),
        ],
      );
      final initialRepository = initialContainer.read(
        missionRepositoryProvider,
      );
      final initialExecutionNotifier = initialContainer.read(
        missionTaskExecutionProvider.notifier,
      );

      await tester.runAsync(() => initialRepository.saveMission(mission));
      await tester.runAsync(
        () => initialExecutionNotifier.executeTask(
          missionId: mission.id,
          taskId: task1.id,
        ),
      );
      await tester.runAsync(
        () => initialExecutionNotifier.acceptResult(
          missionId: mission.id,
          taskId: task1.id,
        ),
      );
      await tester.runAsync(
        () => initialExecutionNotifier.executeTask(
          missionId: mission.id,
          taskId: task2.id,
        ),
      );
      await tester.runAsync(
        () => initialExecutionNotifier.acceptResult(
          missionId: mission.id,
          taskId: task2.id,
        ),
      );

      expect(
        initialExecutionNotifier.executionFor(
          missionId: mission.id,
          taskId: task3.id,
        ),
        isNull,
      );

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
        () => restoredController.getMission(mission.id),
      );

      expect(restoredMission, isNotNull);
      expect(restoredMission!.tasks.map((task) => task.status), <TaskStatus>[
        TaskStatus.completed,
        TaskStatus.completed,
        TaskStatus.pending,
      ]);
      expect(restoredMission.tasks[2].completedAt, isNull);
      expect(restoredMission.tasks[2].output, isNull);
      expect(restoredMission.taskProgress.isComplete, isFalse);
      expect(restoredContainer.read(missionTaskExecutionProvider), isEmpty);

      final restoredExecutionNotifier = restoredContainer.read(
        missionTaskExecutionProvider.notifier,
      );
      await tester.runAsync(
        () => restoredExecutionNotifier.restoreMissionExecutions(mission.id),
      );

      final restoredExecutions = restoredContainer.read(
        missionTaskExecutionProvider,
      );
      expect(restoredExecutions, hasLength(2));
      expect(
        restoredExecutions.map((execution) => execution.taskId).toSet(),
        <String>{task1.id, task2.id},
      );
      expect(
        restoredExecutions.every(
          (execution) => execution.status == ExecutionStatus.completed,
        ),
        isTrue,
      );
      expect(
        restoredExecutionNotifier.executionFor(
          missionId: mission.id,
          taskId: task3.id,
        ),
        isNull,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: restoredContainer,
          child: MaterialApp(
            home: MissionDetailScreen(
              mission: restoredMission,
              missionController: restoredController,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final task3Card = find.byKey(
        ValueKey<String>('mission-task-${task3.id}'),
      );
      expect(task3Card, findsOneWidget);
      expect(find.text('Mission Completed'), findsNothing);
      expect(find.text('Final Results'), findsNothing);
      expect(
        find.descendant(of: task3Card, matching: find.text('Run Next Task')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: task3Card, matching: find.text('Retry Task')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: task3Card,
          matching: find.text('Task execution failed'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(ValueKey<String>('task-execution-result-${task3.id}')),
        findsNothing,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'restart keeps completed task status without accepted output incomplete',
    (tester) async {
      final mission = _mission(
        id: 'mission-unaccepted-completion',
        conversationId: 'conversation-unaccepted-completion',
        title: 'Unaccepted Completion',
        updatedAt: DateTime(2026, 4, 5, 10),
        taskStatus: TaskStatus.completed,
        completedAt: DateTime(2026, 4, 5, 9),
      );
      final initialContainer = ProviderContainer();

      await tester.runAsync(
        () => initialContainer
            .read(missionRepositoryProvider)
            .saveMission(mission),
      );
      expect(mission.taskProgress.isComplete, isFalse);

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
        () => restoredController.getMission(mission.id),
      );

      expect(restoredMission, isNotNull);
      expect(restoredMission!.tasks.single.status, TaskStatus.completed);
      expect(restoredMission.tasks.single.completedAt, isNotNull);
      expect(restoredMission.tasks.single.output, isNull);
      expect(restoredMission.taskProgress.percentage, 100);
      expect(restoredMission.taskProgress.isComplete, isFalse);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: restoredContainer,
          child: MaterialApp(
            home: MissionDetailScreen(
              mission: restoredMission,
              missionController: restoredController,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mission Completed'), findsNothing);
      expect(find.text('Final Results'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('mission-final-results')),
        findsNothing,
      );
    },
  );
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
