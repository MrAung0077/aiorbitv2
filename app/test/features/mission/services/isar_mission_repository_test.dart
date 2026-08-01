import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:aiorbit/core/database/isar_service.dart';
import 'package:aiorbit/features/mission/data/mappers/mission_record_mapper.dart';
import 'package:aiorbit/features/mission/data/models/mission_record.dart';
import 'package:aiorbit/features/mission/models/execution_status.dart';
import 'package:aiorbit/features/mission/models/mission.dart';
import 'package:aiorbit/features/mission/models/mission_category.dart';
import 'package:aiorbit/features/mission/models/mission_execution.dart';
import 'package:aiorbit/features/mission/models/mission_status.dart';
import 'package:aiorbit/features/mission/models/mission_suggestion.dart';
import 'package:aiorbit/features/mission/models/mission_task.dart';
import 'package:aiorbit/features/mission/models/mission_task_execution.dart';
import 'package:aiorbit/features/mission/models/task_status.dart';
import 'package:aiorbit/features/mission/providers/mission_execution_provider.dart';
import 'package:aiorbit/features/mission/providers/mission_provider.dart';
import 'package:aiorbit/features/mission/providers/mission_task_execution_provider.dart';
import 'package:aiorbit/features/mission/services/isar_mission_repository.dart';
import 'package:aiorbit/features/mission/services/memory_mission_repository.dart';
import 'package:aiorbit/features/mission/services/mission_task_executor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory databaseDirectory;
  late Isar isar;
  late IsarMissionRepository repository;
  var databaseSequence = 0;

  setUpAll(_initializeTestIsarCore);

  setUp(() async {
    databaseSequence += 1;
    databaseDirectory = await Directory.systemTemp.createTemp(
      'aiorbit-mission-repository-',
    );
    isar = await _openDatabase(
      directory: databaseDirectory,
      name: 'mission-repository-$databaseSequence',
    );
    repository = IsarMissionRepository(isar: isar);
  });

  tearDown(() async {
    if (isar.isOpen) {
      await isar.close(deleteFromDisk: true);
    }

    if (await databaseDirectory.exists()) {
      await databaseDirectory.delete(recursive: true);
    }
  });

  test('production provider resolves to the Isar mission repository', () {
    final container = ProviderContainer(
      overrides: <Override>[sharedIsarProvider.overrideWithValue(isar)],
    );
    addTearDown(container.dispose);

    expect(
      container.read(missionRepositoryProvider),
      isA<IsarMissionRepository>(),
    );
  });

  test('repository overrides remain independent from shared Isar', () async {
    final memoryRepository = MemoryMissionRepository();
    final container = ProviderContainer(
      overrides: <Override>[
        missionRepositoryProvider.overrideWithValue(memoryRepository),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(missionRepositoryProvider), same(memoryRepository));

    final mission = await container
        .read(missionControllerProvider)
        .startMission(_suggestion(), conversationId: 'memory-conversation');

    expect(await memoryRepository.getMission(mission.id), isNotNull);
    expect(await isar.missionRecords.where().count(), 0);
  });

  test(
    'production provider fails clearly before shared Isar is ready',
    () async {
      await IsarService.close();
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(() => container.read(missionRepositoryProvider), throwsStateError);
    },
  );

  test('controller creation and task updates persist through Isar', () async {
    final container = ProviderContainer(
      overrides: <Override>[sharedIsarProvider.overrideWithValue(isar)],
    );
    addTearDown(container.dispose);
    final controller = container.read(missionControllerProvider);

    final mission = await controller.startMission(
      _suggestion(),
      conversationId: 'controller-conversation',
    );
    final inProgress = await controller.updateTaskStatus(
      missionId: mission.id,
      taskId: mission.tasks.single.id,
      status: TaskStatus.inProgress,
    );
    final completed = await controller.updateTaskStatus(
      missionId: mission.id,
      taskId: mission.tasks.single.id,
      status: TaskStatus.completed,
    );
    final record = await isar.missionRecords
        .where()
        .missionIdEqualTo(mission.id)
        .findFirst();
    final restored = await controller.getMission(mission.id);

    expect(inProgress.tasks.single.status, TaskStatus.inProgress);
    expect(completed.tasks.single.status, TaskStatus.completed);
    expect(completed.tasks.single.completedAt, isNotNull);
    expect(record, isNotNull);
    expect(restored?.conversationId, 'controller-conversation');
    expect(restored?.tasks.single.status, TaskStatus.completed);
    expect(restored?.tasks.single.completedAt, isNotNull);
    expect(restored?.taskProgress.percentage, 100);
  });

  test('saving and retrieving preserves mission domain state', () async {
    final mission = _mission(
      id: 'mission-round-trip',
      conversationId: 'conversation-1',
      status: MissionStatus.paused,
      currentTaskIndex: 1,
      userContext: 'Keep the current campaign tone.',
      tasks: <MissionTask>[
        _task(
          id: 'task-in-progress',
          missionId: 'mission-round-trip',
          order: 0,
          status: TaskStatus.inProgress,
          recommendedProvider: 'provider-a',
          inputContext: 'Use primary sources.',
        ),
        _task(
          id: 'task-completed',
          missionId: 'mission-round-trip',
          order: 1,
          status: TaskStatus.completed,
          completedAt: DateTime.utc(2026, 3, 8, 11),
        ),
      ],
    );

    await repository.saveMission(mission);
    final restored = await repository.getMission(mission.id);

    expect(restored, isNotNull);
    expect(restored!.id, mission.id);
    expect(restored.title, mission.title);
    expect(restored.goal, mission.goal);
    expect(restored.category, mission.category);
    expect(restored.status, MissionStatus.paused);
    expect(restored.createdAt.isAtSameMomentAs(mission.createdAt), isTrue);
    expect(restored.updatedAt.isAtSameMomentAs(mission.updatedAt), isTrue);
    expect(restored.currentTaskIndex, 1);
    expect(restored.conversationId, 'conversation-1');
    expect(restored.userContext, 'Keep the current campaign tone.');
    expect(restored.tasks, hasLength(2));
    expect(restored.tasks.first.status, TaskStatus.inProgress);
    expect(restored.tasks.first.recommendedProvider, 'provider-a');
    expect(restored.tasks.first.inputContext, 'Use primary sources.');
    expect(restored.tasks.last.status, TaskStatus.completed);
    expect(
      restored.tasks.last.completedAt?.isAtSameMomentAs(
        DateTime.utc(2026, 3, 8, 11),
      ),
      isTrue,
    );
    expect(restored.taskProgress.percentage, 50);
    expect(restored.progressPercent, 50);
  });

  test('saving the same mission ID updates without duplication', () async {
    final original = _mission(id: 'mission-upsert');
    final completedAt = DateTime.utc(2026, 3, 9, 15);
    final updated = _mission(
      id: original.id,
      title: 'Updated mission',
      updatedAt: DateTime.utc(2026, 3, 9, 16),
      currentTaskIndex: 1,
      conversationId: 'updated-conversation',
      tasks: <MissionTask>[
        _task(
          id: 'task-1',
          missionId: original.id,
          order: 0,
          status: TaskStatus.completed,
          completedAt: completedAt,
        ),
        _task(
          id: 'task-2',
          missionId: original.id,
          order: 1,
          status: TaskStatus.inProgress,
        ),
      ],
    );

    await repository.saveMission(original);
    await repository.saveMission(updated);

    final records = await isar.missionRecords
        .where()
        .missionIdEqualTo(original.id)
        .findAll();
    final restored = await repository.getMission(original.id);

    expect(records, hasLength(1));
    expect(await repository.getAllMissions(), hasLength(1));
    expect(restored?.title, 'Updated mission');
    expect(restored?.updatedAt.isAtSameMomentAs(updated.updatedAt), isTrue);
    expect(restored?.currentTaskIndex, 1);
    expect(restored?.conversationId, 'updated-conversation');
    expect(restored?.tasks.first.status, TaskStatus.completed);
    expect(
      restored?.tasks.first.completedAt?.isAtSameMomentAs(completedAt),
      isTrue,
    );
    expect(restored?.tasks.last.status, TaskStatus.inProgress);
  });

  test(
    'duplicate and corrupted records resolve to latest valid mission',
    () async {
      const mapper = MissionRecordMapper();
      final older = _mission(
        id: 'mission-duplicate',
        title: 'Older duplicate',
        updatedAt: DateTime.utc(2026, 5, 1, 9),
      );
      final newer = _mission(
        id: 'mission-duplicate',
        title: 'Newest duplicate',
        updatedAt: DateTime.utc(2026, 5, 1, 12),
      );
      final olderRecord = mapper.toRecord(older);
      final newerRecord = mapper.toRecord(newer)
        ..missionId = ' mission-duplicate ';
      final invalidRecord = MissionRecord()
        ..missionId = '   '
        ..title = 'Invalid record'
        ..createdAt = DateTime.utc(2026, 5, 1)
        ..updatedAt = DateTime.utc(2026, 5, 2);

      await isar.writeTxn(() async {
        await isar.missionRecords.putAll(<MissionRecord>[
          olderRecord,
          newerRecord,
          invalidRecord,
        ]);
      });

      final restored = await repository.getMission(' mission-duplicate ');
      final allMissions = await repository.getAllMissions();

      expect(restored?.title, 'Newest duplicate');
      expect(allMissions, hasLength(1));
      expect(allMissions.single.id, 'mission-duplicate');

      await repository.saveMission(
        newer.copyWith(title: 'Normalized duplicate'),
      );

      final remainingRecords = (await isar.missionRecords.where().findAll())
          .where((record) => record.missionId.trim() == newer.id)
          .toList(growable: false);

      expect(remainingRecords, hasLength(1));
      expect(remainingRecords.single.missionId, newer.id);
      expect(
        (await repository.getMission(newer.id))?.title,
        'Normalized duplicate',
      );
    },
  );

  test('blank mission identifiers are rejected without persistence', () async {
    final invalid = _mission(id: '   ');

    await expectLater(repository.saveMission(invalid), throwsArgumentError);

    expect(await repository.getMission('   '), isNull);
    await repository.deleteMission('   ');
    expect(await isar.missionRecords.where().count(), 0);
  });

  test('failed database writes leave the previous record intact', () async {
    final original = _mission(
      id: 'mission-failed-write',
      title: 'Original mission',
      updatedAt: DateTime.utc(2026, 5, 2, 9),
    );
    final attemptedUpdate = original.copyWith(
      title: 'Partially updated mission',
      updatedAt: DateTime.utc(2026, 5, 2, 10),
    );
    final databaseName = isar.name;

    await repository.saveMission(original);
    await isar.close();

    await expectLater(
      repository.saveMission(attemptedUpdate),
      throwsA(anything),
    );

    isar = await _openDatabase(
      directory: databaseDirectory,
      name: databaseName,
    );
    repository = IsarMissionRepository(isar: isar);

    final records = await isar.missionRecords.where().findAll();
    final restored = await repository.getMission(original.id);

    expect(records, hasLength(1));
    expect(restored?.title, original.title);
    expect(restored?.updatedAt.isAtSameMomentAs(original.updatedAt), isTrue);
  });

  test(
    'rapid saves and repeated task updates preserve one latest mission',
    () async {
      final missionId = 'mission-rapid-saves';
      final conversationId = 'conversation-rapid-saves';
      final baseMission = _mission(
        id: missionId,
        conversationId: conversationId,
        updatedAt: DateTime.utc(2026, 6, 1, 9),
      );

      await Future.wait<void>(<Future<void>>[
        for (var revision = 0; revision < 20; revision++)
          repository.saveMission(
            baseMission.copyWith(
              title: 'Revision $revision',
              updatedAt: baseMission.updatedAt.add(Duration(minutes: revision)),
            ),
          ),
      ]);

      final container = ProviderContainer(
        overrides: <Override>[sharedIsarProvider.overrideWithValue(isar)],
      );
      addTearDown(container.dispose);
      final controller = container.read(missionControllerProvider);

      await controller.updateTaskStatus(
        missionId: missionId,
        taskId: baseMission.tasks.single.id,
        status: TaskStatus.inProgress,
      );
      await controller.updateTaskStatus(
        missionId: missionId,
        taskId: baseMission.tasks.single.id,
        status: TaskStatus.completed,
      );
      final reopened = await controller.updateTaskStatus(
        missionId: missionId,
        taskId: baseMission.tasks.single.id,
        status: TaskStatus.inProgress,
      );
      final linked = await controller.getMissionForConversation(conversationId);
      final records = await isar.missionRecords.where().findAll();

      expect(records, hasLength(1));
      expect(reopened.title, 'Revision 19');
      expect(reopened.tasks.single.status, TaskStatus.inProgress);
      expect(reopened.tasks.single.completedAt, isNull);
      expect(reopened.taskProgress.percentage, 0);
      expect(linked?.id, missionId);
      expect(linked?.title, 'Revision 19');
      expect(linked?.conversationId, conversationId);
    },
  );

  test(
    'save restart update restart restores completion without executions',
    () async {
      final mission = _mission(
        id: 'mission-double-restart',
        conversationId: 'conversation-double-restart',
        tasks: <MissionTask>[
          _task(
            id: 'task-double-restart',
            missionId: 'mission-double-restart',
            order: 0,
            status: TaskStatus.pending,
            output: 'Session-only output',
          ),
        ],
      );
      final databaseName = isar.name;
      final initialContainer = ProviderContainer(
        overrides: <Override>[
          sharedIsarProvider.overrideWithValue(isar),
          missionTaskExecutorProvider.overrideWithValue(
            const _ImmediateMissionTaskExecutor(),
          ),
        ],
      );

      await initialContainer
          .read(missionRepositoryProvider)
          .saveMission(mission);
      final taskExecution = await initialContainer
          .read(missionTaskExecutionProvider.notifier)
          .executeTask(missionId: mission.id, taskId: mission.tasks.single.id);
      final missionExecution = initialContainer.read(
        missionExecutionProvider.notifier,
      );
      missionExecution.createExecution(
        executionId: 'execution-double-restart',
        missionId: mission.id,
      );
      missionExecution.prepare();
      missionExecution.start();

      expect(taskExecution.outputText, 'Session-only execution result');
      expect(initialContainer.read(missionExecutionProvider), isNotNull);
      initialContainer.dispose();
      await isar.close();

      isar = await _openDatabase(
        directory: databaseDirectory,
        name: databaseName,
      );
      repository = IsarMissionRepository(isar: isar);
      final firstRestartContainer = ProviderContainer(
        overrides: <Override>[sharedIsarProvider.overrideWithValue(isar)],
      );
      final firstRestartController = firstRestartContainer.read(
        missionControllerProvider,
      );

      expect(firstRestartContainer.read(missionExecutionProvider), isNull);
      expect(firstRestartContainer.read(missionTaskExecutionProvider), isEmpty);
      await firstRestartController.updateTaskStatus(
        missionId: mission.id,
        taskId: mission.tasks.single.id,
        status: TaskStatus.inProgress,
      );
      final completed = await firstRestartController.updateTaskStatus(
        missionId: mission.id,
        taskId: mission.tasks.single.id,
        status: TaskStatus.completed,
      );

      expect(completed.taskProgress.isComplete, isTrue);
      expect(completed.tasks.single.completedAt, isNotNull);
      firstRestartContainer.dispose();
      await isar.close();

      isar = await _openDatabase(
        directory: databaseDirectory,
        name: databaseName,
      );
      repository = IsarMissionRepository(isar: isar);
      final secondRestartContainer = ProviderContainer(
        overrides: <Override>[sharedIsarProvider.overrideWithValue(isar)],
      );
      addTearDown(secondRestartContainer.dispose);
      final restored = await secondRestartContainer
          .read(missionControllerProvider)
          .getMissionForConversation(mission.conversationId!);

      expect(restored?.id, mission.id);
      expect(restored?.tasks.single.status, TaskStatus.completed);
      expect(restored?.tasks.single.completedAt, isNotNull);
      expect(restored?.tasks.single.output, isNull);
      expect(restored?.taskProgress.percentage, 100);
      expect(restored?.taskProgress.isComplete, isTrue);
      expect(secondRestartContainer.read(missionExecutionProvider), isNull);
      expect(
        secondRestartContainer.read(missionTaskExecutionProvider),
        isEmpty,
      );
    },
  );

  test('large workflows round trip with derived immutable progress', () async {
    const taskCount = 200;
    final completedAt = DateTime.utc(2026, 6, 2, 12);
    final mission = _mission(
      id: 'mission-large-workflow',
      status: MissionStatus.completed,
      currentTaskIndex: 999,
      tasks: <MissionTask>[
        for (var index = 0; index < taskCount; index++)
          _task(
            id: 'large-task-$index',
            missionId: 'mission-large-workflow',
            order: index,
            status: index.isEven ? TaskStatus.completed : TaskStatus.pending,
            completedAt: index.isEven ? completedAt : null,
            output: 'Do not persist output $index',
          ),
      ],
    );

    await repository.saveMission(mission);
    final restored = await repository.getMission(mission.id);

    expect(restored, isNotNull);
    expect(restored!.tasks, hasLength(taskCount));
    expect(
      restored.tasks.map((task) => task.order),
      orderedEquals(<int>[
        for (var index = 0; index < taskCount; index++) index,
      ]),
    );
    expect(restored.currentTaskIndex, taskCount - 1);
    expect(restored.taskProgress.completedTasks, taskCount ~/ 2);
    expect(restored.taskProgress.percentage, 50);
    expect(restored.progressPercent, 50);
    expect(restored.taskProgress.isComplete, isFalse);
    expect(restored.status, MissionStatus.completed);
    expect(restored.tasks.every((task) => task.output == null), isTrue);
    expect(restored.tasks.clear, throwsUnsupportedError);
  });

  test('empty database starts without mission or execution state', () async {
    final container = ProviderContainer(
      overrides: <Override>[sharedIsarProvider.overrideWithValue(isar)],
    );
    addTearDown(container.dispose);
    final controller = container.read(missionControllerProvider);

    expect(await controller.getMissions(), isEmpty);
    expect(await controller.getMission('missing'), isNull);
    expect(await controller.getMissionForConversation('missing'), isNull);
    expect(container.read(missionExecutionProvider), isNull);
    expect(container.read(missionTaskExecutionProvider), isEmpty);
  });

  test(
    'multiple missions coexist in insertion order and can be deleted',
    () async {
      final first = _mission(id: 'first');
      final second = _mission(id: 'second');

      await repository.saveMission(first);
      await repository.saveMission(second);
      await repository.saveMission(
        _mission(id: first.id, title: 'Updated first'),
      );

      final allMissions = await repository.getAllMissions();

      expect(allMissions.map((mission) => mission.id), <String>[
        first.id,
        second.id,
      ]);
      expect(allMissions.first.title, 'Updated first');

      await repository.deleteMission(first.id);

      expect(await repository.getMission(first.id), isNull);
      expect((await repository.getAllMissions()).single.id, second.id);
    },
  );

  test('conversation linkage supports latest mission selection', () async {
    final container = ProviderContainer(
      overrides: <Override>[sharedIsarProvider.overrideWithValue(isar)],
    );
    addTearDown(container.dispose);
    final wiredRepository = container.read(missionRepositoryProvider);
    final controller = container.read(missionControllerProvider);
    final older = _mission(
      id: 'older',
      conversationId: 'conversation-linked',
      updatedAt: DateTime.utc(2026, 3, 10, 9),
    );
    final newer = _mission(
      id: 'newer',
      conversationId: 'conversation-linked',
      updatedAt: DateTime.utc(2026, 3, 10, 12),
    );
    final unrelated = _mission(
      id: 'unrelated',
      conversationId: 'other-conversation',
      updatedAt: DateTime.utc(2026, 3, 10, 14),
    );

    await wiredRepository.saveMission(newer);
    await wiredRepository.saveMission(older);
    await wiredRepository.saveMission(unrelated);

    final linked = (await wiredRepository.getAllMissions())
        .where((mission) => mission.conversationId == 'conversation-linked')
        .toList(growable: false);
    final latest = await controller.getMissionForConversation(
      'conversation-linked',
    );

    expect(
      linked.map((mission) => mission.id),
      containsAll(<String>[older.id, newer.id]),
    );
    expect(latest?.id, newer.id);
  });

  test('delete removes linked data from Continue Mission lookup', () async {
    final container = ProviderContainer(
      overrides: <Override>[sharedIsarProvider.overrideWithValue(isar)],
    );
    addTearDown(container.dispose);
    final controller = container.read(missionControllerProvider);
    final mission = _mission(
      id: 'mission-delete-continue',
      conversationId: 'conversation-delete-continue',
    );

    await repository.saveMission(mission);
    expect(
      (await controller.getMissionForConversation(
        'conversation-delete-continue',
      ))?.id,
      mission.id,
    );

    await controller.deleteMission(' mission-delete-continue ');

    expect(await controller.getMission(mission.id), isNull);
    expect(
      await controller.getMissionForConversation(
        'conversation-delete-continue',
      ),
      isNull,
    );
    expect(await isar.missionRecords.where().count(), 0);
  });

  test(
    'shared Isar restores missions but not session execution state',
    () async {
      final mission = _mission(
        id: 'mission-reopen',
        conversationId: 'conversation-reopen',
        tasks: <MissionTask>[
          _task(
            id: 'task-reopen',
            missionId: 'mission-reopen',
            order: 0,
            status: TaskStatus.pending,
            output: 'Session-only task output',
          ),
        ],
      );
      final databaseName = isar.name;
      final initialContainer = ProviderContainer(
        overrides: <Override>[
          sharedIsarProvider.overrideWithValue(isar),
          missionTaskExecutorProvider.overrideWithValue(
            const _ImmediateMissionTaskExecutor(),
          ),
        ],
      );
      final wiredRepository = initialContainer.read(missionRepositoryProvider);

      await wiredRepository.saveMission(mission);
      final taskExecution = await initialContainer
          .read(missionTaskExecutionProvider.notifier)
          .executeTask(missionId: mission.id, taskId: mission.tasks.single.id);
      final missionExecution = initialContainer.read(
        missionExecutionProvider.notifier,
      );
      missionExecution.createExecution(
        executionId: 'mission-execution',
        missionId: mission.id,
      );
      missionExecution.prepare();
      missionExecution.start();

      expect(taskExecution.outputText, 'Session-only execution result');
      expect(initialContainer.read(missionExecutionProvider), isNotNull);

      initialContainer.dispose();
      await isar.close();

      isar = await _openDatabase(
        directory: databaseDirectory,
        name: databaseName,
      );
      final reopenedContainer = ProviderContainer(
        overrides: <Override>[sharedIsarProvider.overrideWithValue(isar)],
      );
      addTearDown(reopenedContainer.dispose);
      final restored = await reopenedContainer
          .read(missionControllerProvider)
          .getMission(mission.id);

      expect(restored?.id, mission.id);
      expect(restored?.conversationId, mission.conversationId);
      expect(restored?.tasks.single.status, TaskStatus.pending);
      expect(restored?.tasks.single.output, isNull);
      expect(restored?.updatedAt.isAtSameMomentAs(mission.updatedAt), isTrue);
      expect(restored?.taskProgress.percentage, 0);
      expect(reopenedContainer.read(missionExecutionProvider), isNull);
      expect(reopenedContainer.read(missionTaskExecutionProvider), isEmpty);
    },
  );

  test('task output and execution state remain outside persistence', () async {
    final mission = _mission(
      id: 'mission-session-only',
      tasks: <MissionTask>[
        _task(
          id: 'task-session-only',
          missionId: 'mission-session-only',
          order: 0,
          status: TaskStatus.pending,
          output: 'Do not persist this execution output',
        ),
      ],
    );

    await repository.saveMission(mission);
    final restored = await repository.getMission(mission.id);

    expect(restored?.tasks.single.output, isNull);
    expect(restored?.tasks.single.status, TaskStatus.pending);
    expect(restored?.taskProgress.percentage, 0);
  });
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

  throw UnsupportedError('Isolated Isar repository tests are desktop-only.');
}

Future<Isar> _openDatabase({
  required Directory directory,
  required String name,
}) {
  return Isar.open(
    <CollectionSchema<dynamic>>[MissionRecordSchema],
    directory: directory.path,
    name: name,
    inspector: false,
  );
}

MissionSuggestion _suggestion() {
  return const MissionSuggestion(
    title: 'Persisted mission',
    goal: 'Verify the production repository wiring',
    category: MissionCategory.productivity,
    reason: 'The controller should save through Isar.',
    plannedSteps: <String>['Persist the workflow task'],
  );
}

class _ImmediateMissionTaskExecutor implements MissionTaskExecutor {
  const _ImmediateMissionTaskExecutor();

  @override
  Future<MissionTaskExecution> execute({
    required Mission mission,
    required MissionTask task,
  }) async {
    final startedAt = DateTime.utc(2026, 3, 12, 9);

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

Mission _mission({
  required String id,
  String? title,
  String? conversationId,
  MissionStatus status = MissionStatus.active,
  DateTime? updatedAt,
  int currentTaskIndex = 0,
  String? userContext,
  List<MissionTask>? tasks,
}) {
  final createdAt = DateTime.utc(2026, 3, 7, 9);

  return Mission(
    id: id,
    title: title ?? 'Mission $id',
    goal: 'Persist mission $id',
    category: MissionCategory.productivity,
    status: status,
    createdAt: createdAt,
    updatedAt: updatedAt ?? createdAt,
    currentTaskIndex: currentTaskIndex,
    progressPercent: 99,
    tasks:
        tasks ??
        <MissionTask>[
          _task(
            id: 'task-$id',
            missionId: id,
            order: 0,
            status: TaskStatus.pending,
          ),
        ],
    conversationId: conversationId,
    userContext: userContext,
  );
}

MissionTask _task({
  required String id,
  required String missionId,
  required int order,
  required TaskStatus status,
  DateTime? completedAt,
  String? recommendedProvider,
  String? inputContext,
  String? output,
}) {
  return MissionTask(
    id: id,
    missionId: missionId,
    title: 'Task $id',
    description: 'Persist task $id',
    order: order,
    status: status,
    taskType: 'test',
    recommendedProvider: recommendedProvider,
    inputContext: inputContext,
    output: output,
    createdAt: DateTime.utc(2026, 3, 7, 10).add(Duration(hours: order)),
    completedAt: completedAt,
  );
}
