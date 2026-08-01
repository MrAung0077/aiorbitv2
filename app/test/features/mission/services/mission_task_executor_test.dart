import 'package:aiorbit/features/mission/models/execution_status.dart';
import 'package:aiorbit/features/mission/models/mission.dart';
import 'package:aiorbit/features/mission/models/mission_category.dart';
import 'package:aiorbit/features/mission/models/mission_execution.dart';
import 'package:aiorbit/features/mission/models/mission_status.dart';
import 'package:aiorbit/features/mission/models/mission_task.dart';
import 'package:aiorbit/features/mission/models/mission_task_execution.dart';
import 'package:aiorbit/features/mission/models/task_status.dart';
import 'package:aiorbit/features/mission/services/mission_task_executor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final startedAt = DateTime(2026, 2, 1, 9);
  final finishedAt = DateTime(2026, 2, 1, 9, 5);

  test(
    'task execution starts and completes with deterministic output',
    () async {
      final mission = _mission();
      final task = mission.tasks.single;
      final executor = _DeterministicMissionTaskExecutor(
        startedAt: startedAt,
        finishedAt: finishedAt,
        outputText: 'Deterministic task output',
        structuredResultReference: 'memory://mission/task/result',
      );

      final result = await executor.execute(mission: mission, task: task);

      expect(result.status, ExecutionStatus.completed);
      expect(result.missionId, mission.id);
      expect(result.taskId, task.id);
      expect(result.startedAt, startedAt);
      expect(result.finishedAt, finishedAt);
      expect(result.outputText, 'Deterministic task output');
      expect(result.structuredResultReference, 'memory://mission/task/result');
      expect(result.failureMessage, isNull);
      expect(result.execution.progress, 1);
    },
  );

  test('failed task execution captures failure information', () async {
    final mission = _mission();
    final task = mission.tasks.single;
    final executor = _DeterministicMissionTaskExecutor(
      startedAt: startedAt,
      finishedAt: finishedAt,
      failureMessage: 'Deterministic execution failure',
    );

    final result = await executor.execute(mission: mission, task: task);

    expect(result.status, ExecutionStatus.failed);
    expect(result.missionId, mission.id);
    expect(result.taskId, task.id);
    expect(result.startedAt, startedAt);
    expect(result.finishedAt, finishedAt);
    expect(result.outputText, isNull);
    expect(result.structuredResultReference, isNull);
    expect(result.failureMessage, 'Deterministic execution failure');
    expect(result.execution.progress, 0);
  });

  test(
    'task execution does not change mission progress or task status',
    () async {
      final mission = _mission();
      final task = mission.tasks.single;
      final executor = _DeterministicMissionTaskExecutor(
        startedAt: startedAt,
        finishedAt: finishedAt,
        outputText: 'Deterministic task output',
      );

      expect(mission.taskProgress.percentage, 0);
      expect(task.status, TaskStatus.pending);

      await executor.execute(mission: mission, task: task);

      expect(mission.taskProgress.percentage, 0);
      expect(mission.taskProgress.isComplete, isFalse);
      expect(task.status, TaskStatus.pending);
      expect(task.output, isNull);
    },
  );
}

class _DeterministicMissionTaskExecutor implements MissionTaskExecutor {
  const _DeterministicMissionTaskExecutor({
    required this.startedAt,
    required this.finishedAt,
    this.outputText,
    this.structuredResultReference,
    this.failureMessage,
  });

  final DateTime startedAt;
  final DateTime finishedAt;
  final String? outputText;
  final String? structuredResultReference;
  final String? failureMessage;

  @override
  Future<MissionTaskExecution> execute({
    required Mission mission,
    required MissionTask task,
  }) async {
    if (task.missionId != mission.id) {
      throw ArgumentError.value(
        task.missionId,
        'task.missionId',
        'Task does not belong to the mission.',
      );
    }

    final failed = failureMessage != null;

    return MissionTaskExecution(
      execution: MissionExecution(
        id: 'execution-${mission.id}-${task.id}',
        missionId: mission.id,
        status: failed ? ExecutionStatus.failed : ExecutionStatus.completed,
        progress: failed ? 0 : 1,
        startedAt: startedAt,
        finishedAt: finishedAt,
        currentTaskId: task.id,
      ),
      outputText: failed ? null : outputText,
      structuredResultReference: failed ? null : structuredResultReference,
      failureMessage: failureMessage,
    );
  }
}

Mission _mission() {
  final createdAt = DateTime(2026, 2, 1, 8);

  return Mission(
    id: 'mission',
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
        id: 'task',
        missionId: 'mission',
        title: 'Task',
        description: 'Complete the task',
        order: 0,
        status: TaskStatus.pending,
        taskType: 'test',
        createdAt: createdAt,
      ),
    ],
  );
}
