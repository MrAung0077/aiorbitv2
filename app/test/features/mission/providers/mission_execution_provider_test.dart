import 'dart:async';

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
import 'package:aiorbit/features/mission/services/mission_task_execution_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final runningAt = DateTime(2026, 2, 3, 10);
  final finishedAt = DateTime(2026, 2, 3, 10, 4);

  test('loads the latest mission and completes the correct task', () async {
    final repository = MemoryMissionRepository();
    final executor = _ControlledMissionTaskExecutor();
    final container = _container(
      repository: repository,
      executor: executor,
      clock: _clock(runningAt, finishedAt),
    );
    addTearDown(container.dispose);

    await repository.saveMission(_mission(taskTitle: 'Stale task'));
    await repository.saveMission(_mission(taskTitle: 'Latest task'));

    expect(
      container
          .read(missionTaskExecutionProvider.notifier)
          .isIdle(missionId: 'mission', taskId: 'task'),
      isTrue,
    );

    final future = container
        .read(missionExecutionProvider.notifier)
        .executeTask(missionId: 'mission', taskId: 'task');

    await executor.started.future;

    expect(executor.receivedMission?.tasks.single.title, 'Latest task');
    expect(executor.receivedTask?.title, 'Latest task');
    expect(_record(container)?.status, ExecutionStatus.running);
    expect(_record(container)?.missionId, 'mission');
    expect(_record(container)?.taskId, 'task');
    expect(container.read(missionExecutionProvider), isNull);

    executor.complete(
      _executionResult(
        status: ExecutionStatus.completed,
        startedAt: runningAt,
        finishedAt: finishedAt,
        outputText: 'Completed output',
      ),
    );

    final result = await future;

    expect(result.status, ExecutionStatus.completed);
    expect(result.missionId, 'mission');
    expect(result.taskId, 'task');
    expect(result.startedAt, runningAt);
    expect(result.finishedAt, finishedAt);
    expect(result.outputText, 'Completed output');
    expect(_record(container), same(result));
    expect(container.read(missionExecutionProvider), isNull);

    final unchangedMission = await repository.getMission('mission');
    expect(unchangedMission?.tasks.single.status, TaskStatus.pending);
    expect(unchangedMission?.taskProgress.percentage, 0);
  });

  test('executor failure is published with a user-safe message', () async {
    final repository = MemoryMissionRepository();
    final executor = _ControlledMissionTaskExecutor();
    final container = _container(
      repository: repository,
      executor: executor,
      clock: _clock(runningAt, finishedAt),
    );
    addTearDown(container.dispose);

    await repository.saveMission(_mission());

    final future = container
        .read(missionExecutionProvider.notifier)
        .executeTask(missionId: 'mission', taskId: 'task');

    await executor.started.future;
    executor.fail(StateError('provider secret detail'));

    final result = await future;

    expect(result.status, ExecutionStatus.failed);
    expect(result.missionId, 'mission');
    expect(result.taskId, 'task');
    expect(
      result.failureMessage,
      'Unable to complete this task. Please try again.',
    );
    expect(result.failureMessage, isNot(contains('provider secret detail')));
    expect(_record(container)?.status, ExecutionStatus.failed);
    expect(container.read(missionExecutionProvider), isNull);
  });

  test('completed and invalid tasks are rejected before execution', () async {
    final repository = MemoryMissionRepository();
    final executor = _ControlledMissionTaskExecutor();
    final container = _container(
      repository: repository,
      executor: executor,
      clock: _clock(runningAt, finishedAt),
    );
    addTearDown(container.dispose);

    await repository.saveMission(_mission(status: TaskStatus.completed));

    await expectLater(
      container
          .read(missionExecutionProvider.notifier)
          .executeTask(missionId: 'mission', taskId: 'task'),
      throwsStateError,
    );

    await repository.saveMission(_mission(taskTitle: ''));

    await expectLater(
      container
          .read(missionExecutionProvider.notifier)
          .executeTask(missionId: 'mission', taskId: 'task'),
      throwsStateError,
    );

    expect(executor.callCount, 0);
    expect(container.read(missionExecutionProvider), isNull);
    expect(
      container
          .read(missionTaskExecutionProvider.notifier)
          .isIdle(missionId: 'mission', taskId: 'task'),
      isTrue,
    );
  });

  test('empty IDs and missing mission or task fail safely', () async {
    final repository = MemoryMissionRepository();
    final executor = _ControlledMissionTaskExecutor();
    final container = _container(
      repository: repository,
      executor: executor,
      clock: _clock(runningAt, finishedAt),
    );
    addTearDown(container.dispose);
    final notifier = container.read(missionExecutionProvider.notifier);

    await expectLater(
      notifier.executeTask(missionId: '', taskId: 'task'),
      throwsStateError,
    );
    await expectLater(
      notifier.executeTask(missionId: 'mission', taskId: ''),
      throwsStateError,
    );
    await expectLater(
      notifier.executeTask(missionId: 'missing', taskId: 'task'),
      throwsStateError,
    );

    await repository.saveMission(_mission());

    await expectLater(
      notifier.executeTask(missionId: 'mission', taskId: 'missing'),
      throwsStateError,
    );

    expect(executor.callCount, 0);
    expect(container.read(missionExecutionProvider), isNull);
  });

  test('duplicate concurrent task execution is rejected', () async {
    final repository = MemoryMissionRepository();
    final executor = _ControlledMissionTaskExecutor();
    final container = _container(
      repository: repository,
      executor: executor,
      clock: _clock(runningAt, finishedAt),
    );
    addTearDown(container.dispose);

    await repository.saveMission(_mission(status: TaskStatus.inProgress));

    final first = container
        .read(missionExecutionProvider.notifier)
        .executeTask(missionId: 'mission', taskId: 'task');

    await expectLater(
      container
          .read(missionExecutionProvider.notifier)
          .executeTask(missionId: 'mission', taskId: 'task'),
      throwsStateError,
    );

    await executor.started.future;
    expect(executor.callCount, 1);

    executor.complete(
      _executionResult(
        status: ExecutionStatus.completed,
        startedAt: runningAt,
        finishedAt: finishedAt,
      ),
    );

    await first;
  });

  test('mission execution remains unchanged during task execution', () async {
    final repository = MemoryMissionRepository();
    final executor = _ControlledMissionTaskExecutor();
    final container = _container(
      repository: repository,
      executor: executor,
      clock: _clock(runningAt, finishedAt),
    );
    addTearDown(container.dispose);

    await repository.saveMission(_mission());

    final missionExecution = container.read(missionExecutionProvider.notifier);
    missionExecution.createExecution(
      executionId: 'mission-execution',
      missionId: 'mission',
    );
    missionExecution.prepare();
    missionExecution.start();
    final originalMissionExecution = container.read(missionExecutionProvider);

    final future = missionExecution.executeTask(
      missionId: 'mission',
      taskId: 'task',
    );

    await executor.started.future;

    expect(
      container.read(missionExecutionProvider),
      same(originalMissionExecution),
    );
    expect(_record(container)?.status, ExecutionStatus.running);

    executor.complete(
      _executionResult(
        status: ExecutionStatus.completed,
        startedAt: runningAt,
        finishedAt: finishedAt,
      ),
    );

    await future;

    expect(
      container.read(missionExecutionProvider),
      same(originalMissionExecution),
    );
    expect(_record(container)?.status, ExecutionStatus.completed);
  });

  test('multiple task execution records coexist in memory', () async {
    final repository = MemoryMissionRepository();
    final container = _container(
      repository: repository,
      executor: _ImmediateMissionTaskExecutor(
        startedAt: runningAt,
        finishedAt: finishedAt,
      ),
      clock: () => runningAt,
    );
    addTearDown(container.dispose);

    await repository.saveMission(
      _mission(missionId: 'mission-one', taskId: 'task-one'),
    );
    await repository.saveMission(
      _mission(missionId: 'mission-two', taskId: 'task-two'),
    );

    final notifier = container.read(missionTaskExecutionProvider.notifier);
    await notifier.executeTask(missionId: 'mission-one', taskId: 'task-one');
    await notifier.executeTask(missionId: 'mission-two', taskId: 'task-two');

    expect(container.read(missionTaskExecutionProvider), hasLength(2));
    expect(
      notifier
          .executionFor(missionId: 'mission-one', taskId: 'task-one')
          ?.status,
      ExecutionStatus.completed,
    );
    expect(
      notifier
          .executionFor(missionId: 'mission-two', taskId: 'task-two')
          ?.status,
      ExecutionStatus.completed,
    );
    expect(container.read(missionExecutionProvider), isNull);
  });

  test('empty completed output is rejected and cannot be accepted', () async {
    final repository = MemoryMissionRepository();
    final executor = _ControlledMissionTaskExecutor();
    final container = _container(
      repository: repository,
      executor: executor,
      clock: _clock(runningAt, finishedAt),
    );
    addTearDown(container.dispose);

    await repository.saveMission(_mission());
    final notifier = container.read(missionTaskExecutionProvider.notifier);
    final future = notifier.executeTask(missionId: 'mission', taskId: 'task');

    await executor.started.future;
    executor.complete(
      _executionResult(
        status: ExecutionStatus.completed,
        startedAt: runningAt,
        finishedAt: finishedAt,
        outputText: '  \n\t ',
      ),
    );

    final result = await future;

    expect(result.status, ExecutionStatus.failed);
    expect(result.outputText, isNull);
    expect(
      result.failureMessage,
      'Unable to complete this task. Please try again.',
    );
    await expectLater(
      notifier.acceptResult(missionId: 'mission', taskId: 'task'),
      throwsStateError,
    );
    expect(
      (await repository.getMission('mission'))?.tasks.single.status,
      TaskStatus.pending,
    );
  });

  test('mismatched executor identifiers are rejected safely', () async {
    final repository = MemoryMissionRepository();
    final executor = _ControlledMissionTaskExecutor();
    final container = _container(
      repository: repository,
      executor: executor,
      clock: _clock(runningAt, finishedAt),
    );
    addTearDown(container.dispose);

    await repository.saveMission(_mission());
    final future = container
        .read(missionTaskExecutionProvider.notifier)
        .executeTask(missionId: 'mission', taskId: 'task');

    await executor.started.future;
    executor.complete(
      _executionResult(
        status: ExecutionStatus.completed,
        startedAt: runningAt,
        finishedAt: finishedAt,
        missionId: 'different-mission',
        taskId: 'different-task',
        outputText: 'Wrong task output',
      ),
    );

    final result = await future;

    expect(result.status, ExecutionStatus.failed);
    expect(result.missionId, 'mission');
    expect(result.taskId, 'task');
    expect(result.outputText, isNull);
    expect(result.failureMessage, isNot(contains('different-mission')));
    expect(container.read(missionTaskExecutionProvider), hasLength(1));
    expect(container.read(missionExecutionProvider), isNull);
  });

  test(
    'a task removed while running cannot publish successful output',
    () async {
      final repository = MemoryMissionRepository();
      final executor = _ControlledMissionTaskExecutor();
      final container = _container(
        repository: repository,
        executor: executor,
        clock: _clock(runningAt, finishedAt),
      );
      addTearDown(container.dispose);

      await repository.saveMission(_mission());
      final future = container
          .read(missionTaskExecutionProvider.notifier)
          .executeTask(missionId: 'mission', taskId: 'task');

      await executor.started.future;
      final latestMission = await repository.getMission('mission');
      await repository.saveMission(
        latestMission!.copyWith(tasks: const <MissionTask>[]),
      );
      executor.complete(
        _executionResult(
          status: ExecutionStatus.completed,
          startedAt: runningAt,
          finishedAt: finishedAt,
          outputText: 'Orphaned output',
        ),
      );

      final result = await future;

      expect(result.status, ExecutionStatus.failed);
      expect(result.outputText, isNull);
      expect((await repository.getMission('mission'))?.tasks, isEmpty);
      expect(container.read(missionExecutionProvider), isNull);
    },
  );

  test('manual completion during execution is never overwritten', () async {
    final repository = MemoryMissionRepository();
    final executor = _ControlledMissionTaskExecutor();
    final container = _container(
      repository: repository,
      executor: executor,
      clock: _clock(runningAt, finishedAt),
    );
    addTearDown(container.dispose);

    await repository.saveMission(_mission(status: TaskStatus.inProgress));
    final notifier = container.read(missionTaskExecutionProvider.notifier);
    final future = notifier.executeTask(missionId: 'mission', taskId: 'task');

    await executor.started.future;
    await container
        .read(missionControllerProvider)
        .updateTaskStatus(
          missionId: 'mission',
          taskId: 'task',
          status: TaskStatus.completed,
        );
    executor.complete(
      _executionResult(
        status: ExecutionStatus.completed,
        startedAt: runningAt,
        finishedAt: finishedAt,
        outputText: 'Completed output',
      ),
    );

    final result = await future;
    final savedMission = await repository.getMission('mission');

    expect(result.status, ExecutionStatus.completed);
    expect(savedMission?.tasks.single.status, TaskStatus.completed);
    expect(savedMission?.tasks.single.completedAt, isNotNull);
    expect(savedMission?.taskProgress.percentage, 100);
    expect(container.read(missionExecutionProvider), isNull);
  });

  test('missing mission and duplicate acceptance fail safely', () async {
    final repository = MemoryMissionRepository();
    final container = _container(
      repository: repository,
      executor: _ImmediateMissionTaskExecutor(
        startedAt: runningAt,
        finishedAt: finishedAt,
      ),
      clock: () => runningAt,
    );
    addTearDown(container.dispose);

    await repository.saveMission(_mission());
    final notifier = container.read(missionTaskExecutionProvider.notifier);
    await notifier.executeTask(missionId: 'mission', taskId: 'task');

    final firstAcceptance = notifier.acceptResult(
      missionId: 'mission',
      taskId: 'task',
    );
    await expectLater(
      notifier.acceptResult(missionId: 'mission', taskId: 'task'),
      throwsStateError,
    );
    final acceptedMission = await firstAcceptance;

    expect(acceptedMission.tasks.single.status, TaskStatus.completed);
    expect(acceptedMission.tasks.single.completedAt, isNotNull);
    expect(container.read(missionExecutionProvider), isNull);

    await repository.saveMission(_mission());
    await repository.deleteMission('mission');

    await expectLater(
      notifier.acceptResult(missionId: 'mission', taskId: 'task'),
      throwsStateError,
    );
    expect(
      notifier.executionFor(missionId: 'mission', taskId: 'task')?.status,
      ExecutionStatus.completed,
    );
  });
}

ProviderContainer _container({
  required MemoryMissionRepository repository,
  required MissionTaskExecutor executor,
  required DateTime Function() clock,
}) {
  return ProviderContainer(
    overrides: <Override>[
      missionRepositoryProvider.overrideWithValue(repository),
      missionTaskExecutionRepositoryProvider.overrideWithValue(
        _MemoryMissionTaskExecutionRepository(),
      ),
      missionTaskExecutorProvider.overrideWithValue(executor),
      missionTaskExecutionClockProvider.overrideWithValue(clock),
    ],
  );
}

class _MemoryMissionTaskExecutionRepository
    implements MissionTaskExecutionRepository {
  final Map<String, MissionTaskExecution> _executions =
      <String, MissionTaskExecution>{};

  String _key(String missionId, String taskId) {
    return '${missionId.trim()}::${taskId.trim()}';
  }

  @override
  Future<void> saveExecution(MissionTaskExecution execution) async {
    _executions[_key(execution.missionId, execution.taskId)] = execution;
  }

  @override
  Future<MissionTaskExecution?> getExecution({
    required String missionId,
    required String taskId,
  }) async {
    return _executions[_key(missionId, taskId)];
  }

  @override
  Future<List<MissionTaskExecution>> getExecutionsForMission(
    String missionId,
  ) async {
    final normalizedMissionId = missionId.trim();

    return List<MissionTaskExecution>.unmodifiable(
      _executions.values.where(
        (execution) => execution.missionId == normalizedMissionId,
      ),
    );
  }

  @override
  Future<void> deleteExecution({
    required String missionId,
    required String taskId,
  }) async {
    _executions.remove(_key(missionId, taskId));
  }

  @override
  Future<void> deleteExecutionsForMission(String missionId) async {
    final normalizedMissionId = missionId.trim();

    _executions.removeWhere(
      (_, execution) => execution.missionId == normalizedMissionId,
    );
  }
}

MissionTaskExecution? _record(ProviderContainer container) {
  return container
      .read(missionTaskExecutionProvider.notifier)
      .executionFor(missionId: 'mission', taskId: 'task');
}

DateTime Function() _clock(DateTime startedAt, DateTime finishedAt) {
  var callCount = 0;

  return () {
    callCount += 1;
    return callCount == 1 ? startedAt : finishedAt;
  };
}

class _ControlledMissionTaskExecutor implements MissionTaskExecutor {
  final started = Completer<void>();
  final _result = Completer<MissionTaskExecution>();

  Mission? receivedMission;
  MissionTask? receivedTask;
  int callCount = 0;

  @override
  Future<MissionTaskExecution> execute({
    required Mission mission,
    required MissionTask task,
  }) {
    callCount += 1;
    receivedMission = mission;
    receivedTask = task;
    started.complete();
    return _result.future;
  }

  void complete(MissionTaskExecution result) {
    _result.complete(result);
  }

  void fail(Object error) {
    _result.completeError(error);
  }
}

class _ImmediateMissionTaskExecutor implements MissionTaskExecutor {
  const _ImmediateMissionTaskExecutor({
    required this.startedAt,
    required this.finishedAt,
  });

  final DateTime startedAt;
  final DateTime finishedAt;

  @override
  Future<MissionTaskExecution> execute({
    required Mission mission,
    required MissionTask task,
  }) async {
    return MissionTaskExecution(
      execution: MissionExecution(
        id: 'execution-${mission.id}-${task.id}',
        missionId: mission.id,
        status: ExecutionStatus.completed,
        progress: 1,
        startedAt: startedAt,
        finishedAt: finishedAt,
        currentTaskId: task.id,
      ),
      outputText: 'Output for ${task.id}',
    );
  }
}

MissionTaskExecution _executionResult({
  required ExecutionStatus status,
  required DateTime startedAt,
  required DateTime finishedAt,
  String missionId = 'mission',
  String taskId = 'task',
  String? outputText = 'Completed output',
  String? failureMessage,
}) {
  return MissionTaskExecution(
    execution: MissionExecution(
      id: 'task-execution',
      missionId: missionId,
      status: status,
      progress: status == ExecutionStatus.completed ? 1 : 0,
      startedAt: startedAt,
      finishedAt: finishedAt,
      currentTaskId: taskId,
    ),
    outputText: outputText,
    failureMessage: failureMessage,
  );
}

Mission _mission({
  TaskStatus status = TaskStatus.pending,
  String taskTitle = 'Task',
  String missionId = 'mission',
  String taskId = 'task',
}) {
  final createdAt = DateTime(2026, 2, 3, 9);

  return Mission(
    id: missionId,
    title: 'Mission',
    goal: 'Complete the mission',
    category: MissionCategory.productivity,
    status: MissionStatus.active,
    createdAt: createdAt,
    updatedAt: createdAt,
    currentTaskIndex: 0,
    progressPercent: 0,
    tasks: <MissionTask>[
      MissionTask(
        id: taskId,
        missionId: missionId,
        title: taskTitle,
        description: 'Complete the task',
        order: 0,
        status: status,
        taskType: 'test',
        createdAt: createdAt,
      ),
    ],
  );
}
