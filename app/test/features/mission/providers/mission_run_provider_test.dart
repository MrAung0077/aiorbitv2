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
import 'package:aiorbit/features/mission/services/mission_task_execution_repository.dart';
import 'package:aiorbit/features/mission/services/mission_task_executor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Run Mission executes tasks in order with chaining and progress updates',
    () async {
      final repository = MemoryMissionRepository();
      final executor = _GatedMissionTaskExecutor();
      final container = _container(repository: repository, executor: executor);
      addTearDown(container.dispose);
      final mission = _mission();

      await repository.saveMission(mission);

      final runFuture = container
          .read(missionExecutionProvider.notifier)
          .runMission(missionId: mission.id);

      await executor.waitForCalls(1);
      _expectMissionExecution(
        container,
        status: ExecutionStatus.running,
        progress: 0,
        currentTaskId: 'task-1',
      );

      executor.complete(0, outputText: 'Accepted result 1');
      await executor.waitForCalls(2);

      _expectMissionExecution(
        container,
        status: ExecutionStatus.running,
        progress: 1 / 3,
        currentTaskId: 'task-2',
      );
      expect(executor.calls[1].mission.tasks[0].status, TaskStatus.completed);
      expect(executor.calls[1].mission.tasks[0].output, 'Accepted result 1');

      executor.complete(1, outputText: 'Accepted result 2');
      await executor.waitForCalls(3);

      _expectMissionExecution(
        container,
        status: ExecutionStatus.running,
        progress: 2 / 3,
        currentTaskId: 'task-3',
      );
      expect(executor.calls[2].mission.tasks[0].output, 'Accepted result 1');
      expect(executor.calls[2].mission.tasks[1].output, 'Accepted result 2');

      executor.complete(2, outputText: 'Accepted result 3');
      final completedMission = await runFuture;

      expect(executor.calls.map((call) => call.task.id), <String>[
        'task-1',
        'task-2',
        'task-3',
      ]);
      expect(
        completedMission.tasks.map((task) => task.status),
        everyElement(TaskStatus.completed),
      );
      expect(completedMission.tasks.map((task) => task.output), <String>[
        'Accepted result 1',
        'Accepted result 2',
        'Accepted result 3',
      ]);
      _expectMissionExecution(
        container,
        status: ExecutionStatus.completed,
        progress: 1,
        currentTaskId: null,
      );
    },
  );

  test('Run Mission stops immediately when a task fails', () async {
    final repository = MemoryMissionRepository();
    final executor = _PlannedMissionTaskExecutor(
      failedTaskIds: const <String>{'task-2'},
    );
    final container = _container(repository: repository, executor: executor);
    addTearDown(container.dispose);
    final mission = _mission();

    await repository.saveMission(mission);

    final stoppedMission = await container
        .read(missionExecutionProvider.notifier)
        .runMission(missionId: mission.id);

    expect(executor.taskIds, <String>['task-1', 'task-2']);
    expect(stoppedMission.tasks[0].status, TaskStatus.completed);
    expect(stoppedMission.tasks[0].output, 'Accepted result for task-1');
    expect(stoppedMission.tasks[1].status, TaskStatus.pending);
    expect(stoppedMission.tasks[1].output, isNull);
    expect(stoppedMission.tasks[2].status, TaskStatus.pending);
    expect(stoppedMission.tasks[2].output, isNull);
    expect(
      container
          .read(missionTaskExecutionProvider.notifier)
          .executionFor(missionId: mission.id, taskId: 'task-3'),
      isNull,
    );
    _expectMissionExecution(
      container,
      status: ExecutionStatus.failed,
      progress: 1 / 3,
      currentTaskId: 'task-2',
    );
  });

  test('Run Mission resumes without rerunning completed tasks', () async {
    final repository = MemoryMissionRepository();
    final executor = _PlannedMissionTaskExecutor();
    final container = _container(repository: repository, executor: executor);
    addTearDown(container.dispose);
    final mission = _mission(
      firstTaskStatus: TaskStatus.completed,
      firstTaskOutput: 'Previously accepted result',
    );

    await repository.saveMission(mission);

    final completedMission = await container
        .read(missionExecutionProvider.notifier)
        .runMission(missionId: mission.id);

    expect(executor.taskIds, <String>['task-2', 'task-3']);
    expect(
      executor.receivedMissions.first.tasks[0].output,
      'Previously accepted result',
    );
    expect(completedMission.tasks[0].output, 'Previously accepted result');
    expect(
      completedMission.tasks.map((task) => task.status),
      everyElement(TaskStatus.completed),
    );
    _expectMissionExecution(
      container,
      status: ExecutionStatus.completed,
      progress: 1,
      currentTaskId: null,
    );
  });

  test(
    'cancelling a Mission preserves accepted work and stops later tasks',
    () async {
      final repository = MemoryMissionRepository();
      final executor = _GatedMissionTaskExecutor();
      final container = _container(repository: repository, executor: executor);
      addTearDown(container.dispose);
      final mission = _mission();
      await repository.saveMission(mission);

      final notifier = container.read(missionExecutionProvider.notifier);
      final runFuture = notifier.runMission(missionId: mission.id);
      await executor.waitForCalls(1);
      executor.complete(0, outputText: 'Accepted first output');
      await executor.waitForCalls(2);

      final cancelled = await notifier.cancelActiveMission();
      expect(cancelled?.status, MissionStatus.cancelled);
      executor.complete(1, outputText: 'Late output must be ignored');
      final stopped = await runFuture;

      expect(stopped.status, MissionStatus.cancelled);
      expect(stopped.tasks[0].status, TaskStatus.completed);
      expect(stopped.tasks[0].output, 'Accepted first output');
      expect(stopped.tasks[1].status, TaskStatus.pending);
      expect(stopped.tasks[1].output, isNull);
      expect(stopped.tasks[2].status, TaskStatus.pending);
      expect(executor.calls, hasLength(2));
      _expectMissionExecution(
        container,
        status: ExecutionStatus.cancelled,
        progress: 1 / 3,
        currentTaskId: null,
      );
    },
  );

  test('duplicate mission and task runs are rejected while running', () async {
    final repository = MemoryMissionRepository();
    final executor = _GatedMissionTaskExecutor();
    final container = _container(repository: repository, executor: executor);
    addTearDown(container.dispose);
    final mission = _mission(taskCount: 1);

    await repository.saveMission(mission);

    final missionNotifier = container.read(missionExecutionProvider.notifier);
    final runFuture = missionNotifier.runMission(missionId: mission.id);
    await executor.waitForCalls(1);

    await expectLater(
      missionNotifier.runMission(missionId: mission.id),
      throwsStateError,
    );
    await expectLater(
      container
          .read(missionTaskExecutionProvider.notifier)
          .executeTask(missionId: mission.id, taskId: 'task-1'),
      throwsStateError,
    );
    expect(executor.calls, hasLength(1));

    executor.complete(0, outputText: 'Accepted result 1');
    await runFuture;

    expect(executor.calls, hasLength(1));
    expect(
      (await repository.getMission(mission.id))?.tasks.single.status,
      TaskStatus.completed,
    );
  });
}

ProviderContainer _container({
  required MemoryMissionRepository repository,
  required MissionTaskExecutor executor,
}) {
  return ProviderContainer(
    overrides: <Override>[
      missionRepositoryProvider.overrideWithValue(repository),
      missionTaskExecutionRepositoryProvider.overrideWithValue(
        _MemoryMissionTaskExecutionRepository(),
      ),
      missionTaskExecutorProvider.overrideWithValue(executor),
      missionTaskExecutionClockProvider.overrideWithValue(
        () => DateTime(2026, 5, 1, 10),
      ),
    ],
  );
}

void _expectMissionExecution(
  ProviderContainer container, {
  required ExecutionStatus status,
  required double progress,
  required String? currentTaskId,
}) {
  final execution = container.read(missionExecutionProvider);

  expect(execution?.status, status);
  expect(execution?.progress, closeTo(progress, 0.0001));
  expect(execution?.currentTaskId, currentTaskId);
}

Mission _mission({
  int taskCount = 3,
  TaskStatus firstTaskStatus = TaskStatus.pending,
  String? firstTaskOutput,
}) {
  final createdAt = DateTime(2026, 5, 1, 9);

  return Mission(
    id: 'mission',
    title: 'Sequential mission',
    goal: 'Complete each task in order',
    category: MissionCategory.productivity,
    status: MissionStatus.active,
    createdAt: createdAt,
    updatedAt: createdAt,
    currentTaskIndex: 0,
    progressPercent: 0,
    tasks: List<MissionTask>.generate(taskCount, (index) {
      final taskNumber = index + 1;
      final status = index == 0 ? firstTaskStatus : TaskStatus.pending;

      return MissionTask(
        id: 'task-$taskNumber',
        missionId: 'mission',
        title: 'Task $taskNumber',
        description: 'Complete task $taskNumber',
        order: index,
        status: status,
        taskType: 'test',
        output: index == 0 ? firstTaskOutput : null,
        createdAt: createdAt.add(Duration(minutes: index)),
        completedAt: status == TaskStatus.completed ? createdAt : null,
      );
    }),
  );
}

class _GatedMissionTaskExecutor implements MissionTaskExecutor {
  final List<_GatedExecutionCall> calls = <_GatedExecutionCall>[];

  @override
  Future<MissionTaskExecution> execute({
    required Mission mission,
    required MissionTask task,
  }) {
    final call = _GatedExecutionCall(mission: mission, task: task);
    calls.add(call);
    return call.completer.future;
  }

  Future<void> waitForCalls(int count) async {
    while (calls.length < count) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  void complete(int index, {required String outputText}) {
    final call = calls[index];
    call.completer.complete(
      _executionResult(task: call.task, outputText: outputText),
    );
  }
}

class _GatedExecutionCall {
  _GatedExecutionCall({required this.mission, required this.task});

  final Mission mission;
  final MissionTask task;
  final Completer<MissionTaskExecution> completer =
      Completer<MissionTaskExecution>();
}

class _PlannedMissionTaskExecutor implements MissionTaskExecutor {
  _PlannedMissionTaskExecutor({this.failedTaskIds = const <String>{}});

  final Set<String> failedTaskIds;
  final List<String> taskIds = <String>[];
  final List<Mission> receivedMissions = <Mission>[];

  @override
  Future<MissionTaskExecution> execute({
    required Mission mission,
    required MissionTask task,
  }) async {
    taskIds.add(task.id);
    receivedMissions.add(mission);

    if (failedTaskIds.contains(task.id)) {
      return _executionResult(
        task: task,
        status: ExecutionStatus.failed,
        failureMessage: 'Deterministic failure',
      );
    }

    return _executionResult(
      task: task,
      outputText: 'Accepted result for ${task.id}',
    );
  }
}

MissionTaskExecution _executionResult({
  required MissionTask task,
  ExecutionStatus status = ExecutionStatus.completed,
  String? outputText,
  String? failureMessage,
}) {
  final startedAt = DateTime(2026, 5, 1, 10);

  return MissionTaskExecution(
    execution: MissionExecution(
      id: 'execution-${task.id}',
      missionId: task.missionId,
      status: status,
      progress: status == ExecutionStatus.completed ? 1 : 0,
      startedAt: startedAt,
      finishedAt: startedAt.add(const Duration(minutes: 1)),
      currentTaskId: task.id,
    ),
    outputText: outputText,
    failureMessage: failureMessage,
  );
}

class _MemoryMissionTaskExecutionRepository
    implements MissionTaskExecutionRepository {
  final Map<String, MissionTaskExecution> _executions =
      <String, MissionTaskExecution>{};

  String _key(String missionId, String taskId) => '$missionId::$taskId';

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
    return _executions.values
        .where((execution) => execution.missionId == missionId)
        .toList(growable: false);
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
    _executions.removeWhere((_, execution) => execution.missionId == missionId);
  }
}
